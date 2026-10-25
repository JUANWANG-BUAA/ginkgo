use super::{cache::SnapshotCache, session_service::SchoolClient, DataOutcome};
use crate::{
    adapters::bykc_http,
    auth::CredentialVault,
    foundation::{http::HttpTransport, mutex::Mutex},
    AppError, ErrorCode,
};
use ginkgo_domain::ports::*;
use std::future::Future;

pub use ginkgo_domain::ports::BykcChosenOutcome;
pub use ginkgo_domain::ports::BykcOutcome;
pub use ginkgo_domain::ports::BykcStatisticsOutcome;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    /// BYKC reads share one session recovery and request-exclusion policy. The
    /// supplied adapter still owns its own endpoint and envelope success code.
    async fn read_bykc_snapshot<D: Clone, F, Fut>(
        &self,
        key: &str,
        snapshots: &Mutex<SnapshotCache<String, D>>,
        force: bool,
        read: F,
    ) -> Result<DataOutcome<D>, AppError>
    where
        F: Fn() -> Fut,
        Fut: Future<Output = Result<D, AppError>>,
    {
        let account = self.current_account()?;
        let key = key.to_owned();
        let cached = || {
            snapshots.lock().fresh(&key).map(|entry| DataOutcome {
                data: entry.value.clone(),
                failure: None,
            })
        };
        if !force {
            if let Some(outcome) = cached() {
                return Ok(outcome);
            }
        }
        let _access = self.bykc_access.lock().await;
        // A preceding request may have populated the snapshot while we waited.
        self.current_account()?;
        if !force {
            if let Some(outcome) = cached() {
                return Ok(outcome);
            }
        }
        let ticket = snapshots.lock().begin(&key);
        let mut result = read().await;
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => read().await,
                Err(error) => Err(error),
            };
        }
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        snapshots.lock().resolve_current(key, ticket, result)
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> BykcSource for SchoolClient<T, V> {
    async fn load_bykc(&self, force: bool) -> Result<BykcOutcome, AppError> {
        self.read_bykc_snapshot("catalog", &self.snapshots.bykc, force, || {
            bykc_http::load(&self.session)
        })
        .await
    }

    async fn load_bykc_chosen(&self, force: bool) -> Result<BykcChosenOutcome, AppError> {
        self.read_bykc_snapshot("chosen", &self.snapshots.bykc_chosen, force, || {
            bykc_http::load_chosen(&self.session)
        })
        .await
    }

    async fn load_bykc_statistics(&self, force: bool) -> Result<BykcStatisticsOutcome, AppError> {
        self.read_bykc_snapshot("statistics", &self.snapshots.bykc_statistics, force, || {
            bykc_http::load_statistics(&self.session)
        })
        .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        auth::{session::Session, vault::MemoryVault, UserProfile},
        test_support::MockTransport,
    };
    use std::{
        sync::atomic::{AtomicUsize, Ordering},
        task::Poll,
    };

    #[tokio::test]
    async fn waiting_read_rechecks_cache_and_force_bypasses_it() {
        let service = SchoolClient::new(
            Session::new(MockTransport::default()),
            MemoryVault::default(),
        );
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        let cache = Mutex::new(SnapshotCache::<String, Vec<i32>>::default());
        let reads = AtomicUsize::new(0);
        let read = || async {
            reads.fetch_add(1, Ordering::SeqCst);
            Ok(vec![9])
        };
        let gate = service.bykc_access.lock().await;
        let mut pending = Box::pin(service.read_bykc_snapshot("scope", &cache, false, read));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(pending.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        cache.lock().insert("scope".into(), vec![7]);
        drop(gate);
        assert_eq!(pending.await.expect("use preceding snapshot").data, vec![7]);
        assert_eq!(reads.load(Ordering::SeqCst), 0);
        assert_eq!(
            service
                .read_bykc_snapshot("scope", &cache, true, read)
                .await
                .expect("forced refresh")
                .data,
            vec![9]
        );
        assert_eq!(reads.load(Ordering::SeqCst), 1);
        assert_eq!(service.session.transport().request_count(), 0);
    }

    #[tokio::test]
    async fn an_account_change_during_the_network_read_rejects_its_result() {
        let service = SchoolClient::new(
            Session::new(MockTransport::default()),
            MemoryVault::default(),
        );
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        let cache = Mutex::new(SnapshotCache::<String, Vec<i32>>::default());
        let gate = tokio::sync::Mutex::new(());
        let hold = gate.lock().await;
        let read = || async {
            let _held = gate.lock().await;
            Ok(vec![9])
        };
        let mut pending = Box::pin(service.read_bykc_snapshot("scope", &cache, false, read));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(pending.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        service.set_authenticated(
            "sy2501002".into(),
            UserProfile {
                school_id: "sy2501002".into(),
                name: "other".into(),
            },
        );
        drop(hold);
        let error = pending
            .await
            .expect_err("a late read must not cross accounts");
        assert_eq!(error.code, ErrorCode::SessionExpired);
        assert!(
            cache.lock().fresh(&"scope".to_owned()).is_none(),
            "a rejected read must not populate the snapshot"
        );
    }
}
