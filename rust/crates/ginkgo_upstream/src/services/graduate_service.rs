use super::session_service::SchoolClient;
use crate::{
    adapters::graduate_http, auth::CredentialVault, features::graduate::AcademicData,
    foundation::http::HttpTransport, AppError, ErrorCode,
};
pub use ginkgo_domain::ports::GraduateOutcome;
pub use ginkgo_domain::ports::GraduatePart;
use ginkgo_domain::ports::*;

fn part_key(part: GraduatePart) -> &'static str {
    match part {
        GraduatePart::Status => "status",
        GraduatePart::Report => "report",
    }
}
async fn load_part<T: HttpTransport>(
    part: GraduatePart,
    session: &crate::auth::session::Session<T>,
    account: &str,
) -> Result<AcademicData, AppError> {
    match part {
        GraduatePart::Status => graduate_http::load_status(session, account).await,
        GraduatePart::Report => graduate_http::load_report(session, account).await,
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> GraduateSource for SchoolClient<T, V> {
    async fn load_graduate(&self, force: bool) -> Result<GraduateOutcome, AppError> {
        let mut status = self.load_graduate_part(GraduatePart::Status, force).await?;
        let report = self.load_graduate_part(GraduatePart::Report, force).await?;
        status.data.sections.extend(report.data.sections);
        status.data.notice = report.data.notice;
        status.failure = status.failure.or(report.failure);
        Ok(status)
    }

    async fn load_graduate_part(
        &self,
        part: GraduatePart,
        force: bool,
    ) -> Result<GraduateOutcome, AppError> {
        let key = part_key(part).to_owned();
        // A fresh snapshot needs no GSMIS activation. Do not let an unrelated
        // slow report block an already cached status (or the reverse).
        self.current_account()?;
        if !force {
            let cache = self.snapshots.graduate.lock();
            if let Some(entry) = cache.fresh(&key) {
                return Ok(GraduateOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        // GSMIS applications share cookies and recovery. Stage only network
        // chains, then recheck: an earlier request may have filled this cache.
        let _gate = self.graduate_request_gate.lock().await;
        let account = self.current_account()?;
        if !force {
            let cache = self.snapshots.graduate.lock();
            if let Some(entry) = cache.fresh(&key) {
                return Ok(GraduateOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.graduate.lock().begin(&key);
        let mut result = load_part(part, &self.session, &account).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => load_part(part, &self.session, &account).await,
                Err(e) => Err(e),
            };
        }
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        self.snapshots
            .graduate
            .lock()
            .resolve_current(key, ticket, result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{auth::session::Session, auth::vault::MemoryVault, test_support::MockTransport};
    use std::{future::Future, task::Poll};

    #[tokio::test]
    async fn fresh_snapshot_does_not_wait_for_another_graduate_request() {
        let service = SchoolClient::new(
            Session::new(MockTransport::default()),
            MemoryVault::default(),
        );
        service.set_authenticated(
            "sy2501001".into(),
            crate::auth::UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        service.snapshots.graduate.lock().insert(
            "status".into(),
            AcademicData {
                sections: vec![],
                notice: Some("synthetic snapshot".into()),
            },
        );
        let gate = service.graduate_request_gate.lock().await;
        let mut cached = Box::pin(service.load_graduate_part(GraduatePart::Status, false));
        let polled = std::future::poll_fn(|cx| Poll::Ready(cached.as_mut().poll(cx))).await;
        match polled {
            Poll::Ready(Ok(outcome)) => {
                assert_eq!(outcome.data.notice.as_deref(), Some("synthetic snapshot"))
            }
            _ => panic!("fresh cache must return while a network request holds the gate"),
        }
        let mut forced = Box::pin(service.load_graduate_part(GraduatePart::Status, true));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(forced.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        assert_eq!(service.session.transport().request_count(), 0);
        drop(gate);
        let outcome = forced.await.expect("failed refresh retains cache");
        assert!(outcome.failure.is_some());
        assert_eq!(outcome.data.notice.as_deref(), Some("synthetic snapshot"));
    }

    #[tokio::test]
    async fn waiting_cache_miss_rechecks_snapshot_after_the_gate() {
        let service = SchoolClient::new(
            Session::new(MockTransport::default()),
            MemoryVault::default(),
        );
        service.set_authenticated(
            "sy2501001".into(),
            crate::auth::UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        let gate = service.graduate_request_gate.lock().await;
        let mut waiting = Box::pin(service.load_graduate_part(GraduatePart::Status, false));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(waiting.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        service.snapshots.graduate.lock().insert(
            "status".into(),
            AcademicData {
                sections: vec![],
                notice: Some("published by earlier request".into()),
            },
        );
        drop(gate);
        let outcome = waiting.await.expect("use newly populated cache");
        assert!(outcome.failure.is_none());
        assert_eq!(
            outcome.data.notice.as_deref(),
            Some("published by earlier request")
        );
        assert_eq!(service.session.transport().request_count(), 0);
    }
}
