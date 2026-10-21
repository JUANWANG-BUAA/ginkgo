use super::session_service::SessionService;
use crate::{
    adapters::graduate_http, auth::CredentialVault, features::graduate::AcademicData,
    foundation::http::HttpTransport, AppError, ErrorCode,
};
pub struct GraduateOutcome {
    pub data: AcademicData,
    pub failure: Option<AppError>,
}
#[derive(Debug, Clone, Copy)]
pub enum GraduatePart {
    Status,
    Report,
}
impl GraduatePart {
    fn key(self) -> &'static str {
        match self {
            Self::Status => "status",
            Self::Report => "report",
        }
    }
    async fn load<T: HttpTransport>(
        self,
        session: &crate::auth::session::Session<T>,
        account: &str,
    ) -> Result<AcademicData, AppError> {
        match self {
            Self::Status => graduate_http::load_status(session, account).await,
            Self::Report => graduate_http::load_report(session, account).await,
        }
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_graduate(&self, force: bool) -> Result<GraduateOutcome, AppError> {
        let mut status = self.load_graduate_part(GraduatePart::Status, force).await?;
        let report = self.load_graduate_part(GraduatePart::Report, force).await?;
        status.data.sections.extend(report.data.sections);
        status.data.notice = report.data.notice;
        status.failure = status.failure.or(report.failure);
        Ok(status)
    }

    pub async fn load_graduate_part(
        &self,
        part: GraduatePart,
        force: bool,
    ) -> Result<GraduateOutcome, AppError> {
        let key = part.key().to_owned();
        // A fresh snapshot needs no GSMIS activation. Do not let an unrelated
        // slow report block an already cached status (or the reverse).
        self.current_account()?;
        if !force {
            let cache = self.graduate.lock();
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
            let cache = self.graduate.lock();
            if let Some(entry) = cache.fresh(&key) {
                return Ok(GraduateOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = part.load(&self.session, &account).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => part.load(&self.session, &account).await,
                Err(e) => Err(e),
            };
        }
        match result {
            Ok(data) => {
                self.graduate.lock().insert(key, data.clone());
                Ok(GraduateOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.graduate.lock();
                match cache.any(&key) {
                    Some(entry) => Ok(GraduateOutcome {
                        data: entry.value.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{auth::session::Session, auth::vault::MemoryVault, test_support::MockTransport};
    use std::{future::Future, task::Poll};

    #[tokio::test]
    async fn fresh_snapshot_does_not_wait_for_another_graduate_request() {
        let service = SessionService::new(
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
        service.graduate.lock().insert(
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
        let service = SessionService::new(
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
        service.graduate.lock().insert(
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
