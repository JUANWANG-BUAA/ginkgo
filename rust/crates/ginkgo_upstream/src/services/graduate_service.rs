use super::session_service::SchoolClient;
use crate::{
    adapters::graduate_http, auth::CredentialVault, codecs::graduate::AcademicData,
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
    part: Option<GraduatePart>,
    session: &crate::auth::session::Session<T>,
    account: &str,
) -> Result<AcademicData, AppError> {
    match part {
        Some(GraduatePart::Status) => graduate_http::load_status(session, account).await,
        Some(GraduatePart::Report) => graduate_http::load_report(session, account).await,
        None => graduate_http::load_execution_report(session).await,
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
        self.load_graduate_query(Some(part), force).await
    }

    async fn load_graduate_execution(&self, force: bool) -> Result<GraduateOutcome, AppError> {
        self.load_graduate_query(None, force).await
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn load_graduate_query(
        &self,
        part: Option<GraduatePart>,
        force: bool,
    ) -> Result<GraduateOutcome, AppError> {
        let key = part.map(part_key).unwrap_or("execution").to_owned();
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
        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.graduate,
            key,
            true,
            async {
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
                result
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(GraduateOutcome {
            data: snapshot.data,
            failure: snapshot.failure,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{auth::session::Session, auth::vault::MemoryVault, test_support::MockTransport};
    use std::{future::Future, task::Poll};

    #[tokio::test]
    async fn strict_execution_cache_is_independent_and_preserves_refresh_failure() {
        use crate::foundation::http::HttpResponse;
        let url =
            "https://gsmis.buaa.edu.cn/gsapp/sys/wdpyfazxbgappbuaa/zxbg/loadXspyfazxbgInfo.do";
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, url, "activated"),
            HttpResponse::new(
                200,
                url,
                r#"{"code":1,"fa":{"ZDXF":32},"yhpyfaxf":8,"zxbg":[]}"#,
            ),
            HttpResponse::new(200, url, "activated"),
            HttpResponse::new(404, url, "missing"),
        ]);
        let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
        service.set_authenticated(
            "sy2501001".into(),
            crate::auth::UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        service.snapshots.graduate.lock().insert(
            "report".into(),
            AcademicData {
                sections: vec![],
                notice: Some("旧课程池".into()),
            },
        );
        let first = service.load_graduate_execution(false).await.unwrap();
        assert!(first.failure.is_none());
        assert_eq!(
            first.data.sections[0].progress.as_ref().unwrap().required,
            Some(32.0)
        );
        assert_eq!(transport.request_count(), 2);
        assert!(service
            .load_graduate_execution(false)
            .await
            .unwrap()
            .failure
            .is_none());
        assert_eq!(
            transport.request_count(),
            2,
            "fresh strict snapshot is reused"
        );
        let failed = service.load_graduate_execution(true).await.unwrap();
        assert_eq!(failed.failure.unwrap().code, ErrorCode::ChangedResponse);
        assert_eq!(
            failed.data.sections[0].progress.as_ref().unwrap().earned,
            Some(8.0)
        );
        assert_eq!(
            transport.request_count(),
            4,
            "failure must not fetch a course pool"
        );
        assert_eq!(
            service
                .snapshots
                .graduate
                .lock()
                .fresh(&"report".to_owned())
                .unwrap()
                .value
                .notice
                .as_deref(),
            Some("旧课程池")
        );
    }

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

    /// The await-time account recheck: a graduate read parked mid-flight must
    /// reject its result after the identity flips instead of resolving into
    /// the snapshot the new account would then read.
    #[tokio::test]
    async fn an_account_change_during_the_graduate_read_rejects_its_result() {
        let (transport, gate) = crate::services::tests::GatedTransport::gated();
        let service = SchoolClient::new(Session::new(transport), MemoryVault::default());
        service.set_authenticated(
            "sy2501001".into(),
            crate::auth::UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        let mut pending = Box::pin(service.load_graduate_part(GraduatePart::Status, false));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(pending.as_mut().poll(cx)))
                .await
                .is_pending(),
            "the gated transport must hold the read open"
        );
        service.set_authenticated(
            "sy2501002".into(),
            crate::auth::UserProfile {
                school_id: "sy2501002".into(),
                name: "other".into(),
            },
        );
        gate.send_replace(true);
        let error = pending
            .await
            .expect_err("a late read must not cross accounts");
        assert_eq!(error.code, ErrorCode::SessionExpired);
        assert!(
            service
                .snapshots
                .graduate
                .lock()
                .fresh(&"status".to_owned())
                .is_none(),
            "a rejected read must not populate the graduate snapshot"
        );
    }
}
