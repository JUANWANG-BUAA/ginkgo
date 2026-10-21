use super::{cache::SnapshotCache, SessionService};
use crate::{
    adapters::library_stats_http, auth::CredentialVault, features::library_stats::CampusStats,
    foundation::http::HttpTransport, AppError,
};
pub(crate) type LibraryStatsCache = SnapshotCache<String, Vec<CampusStats>>;
pub struct LibraryStatsOutcome {
    pub campuses: Vec<CampusStats>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_library_stats(&self, force: bool) -> Result<LibraryStatsOutcome, AppError> {
        let key = "public".to_owned();
        if !force {
            if let Some(entry) = self
                .library_stats
                .lock()
                .expect("library stats")
                .fresh(&key)
            {
                return Ok(LibraryStatsOutcome {
                    campuses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    failure: None,
                });
            }
        }
        // The diagnostics page and public page can request the same cold key.
        // Keep fresh reads ahead of the gate and recheck after waiting.
        let _gate = self.library_stats_request_gate.lock().await;
        if !force {
            if let Some(entry) = self
                .library_stats
                .lock()
                .expect("library stats")
                .fresh(&key)
            {
                return Ok(LibraryStatsOutcome {
                    campuses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    failure: None,
                });
            }
        }
        let result = library_stats_http::load(&self.session, self.preference().into()).await;
        let mut cache = self.library_stats.lock().expect("library stats");
        match result {
            Ok(campuses) => {
                let fetched_at = cache.insert(key, campuses.clone());
                Ok(LibraryStatsOutcome {
                    campuses,
                    fetched_at,
                    from_cache: false,
                    failure: None,
                })
            }
            Err(error) => match cache.any(&key) {
                Some(entry) => Ok(LibraryStatsOutcome {
                    campuses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        auth::{session::Session, vault::MemoryVault},
        foundation::http::{HttpRequest, HttpResponse, TransportError},
    };
    use std::{
        future::Future,
        sync::{
            atomic::{AtomicUsize, Ordering},
            Arc,
        },
        task::Poll,
    };
    use tokio::sync::Semaphore;

    #[derive(Clone)]
    struct HeldPublicRead {
        count: Arc<AtomicUsize>,
        permits: Arc<Semaphore>,
    }
    impl HttpTransport for HeldPublicRead {
        async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
            assert_eq!(request.url, library_stats_http::URL);
            assert!(request.header_value("Cookie").is_none());
            self.count.fetch_add(1, Ordering::SeqCst);
            self.permits.acquire().await.expect("permit").forget();
            let fixture: serde_json::Value = serde_json::from_str(include_str!(
                "../../../../../fixtures/library/stats-normal-v1.json"
            ))
            .expect("synthetic fixture");
            Ok(HttpResponse::new(
                200,
                library_stats_http::URL,
                fixture["input"]["html"].as_str().expect("html"),
            ))
        }
    }
    #[tokio::test]
    async fn concurrent_public_stats_misses_share_the_first_published_snapshot() {
        let transport = HeldPublicRead {
            count: Arc::new(AtomicUsize::new(0)),
            permits: Arc::new(Semaphore::new(0)),
        };
        let service = SessionService::new(Session::new(transport.clone()), MemoryVault::default());
        let mut first = Box::pin(service.load_library_stats(false));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(first.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        let mut second = Box::pin(service.load_library_stats(false));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(second.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        assert_eq!(
            transport.count.load(Ordering::SeqCst),
            1,
            "a queued cache miss must not send a duplicate request"
        );
        transport.permits.add_permits(1);
        let first = first.await.expect("first public snapshot");
        let second = second.await.expect("queued cache hit");
        assert!(!first.from_cache);
        assert!(second.from_cache);
        assert_eq!(first.campuses, second.campuses);
        assert_eq!(first.fetched_at, second.fetched_at);
        assert_eq!(transport.count.load(Ordering::SeqCst), 1);
        // A forced read may wait on the network; a fresh snapshot must not wait.
        let mut forced = Box::pin(service.load_library_stats(true));
        assert!(
            std::future::poll_fn(|cx| Poll::Ready(forced.as_mut().poll(cx)))
                .await
                .is_pending()
        );
        let mut cached = Box::pin(service.load_library_stats(false));
        assert!(matches!(
            std::future::poll_fn(|cx| Poll::Ready(cached.as_mut().poll(cx))).await,
            Poll::Ready(Ok(LibraryStatsOutcome {
                from_cache: true,
                ..
            }))
        ));
        drop(forced);
        // Cancellation releases the request gate, allowing explicit retry.
        transport.permits.add_permits(1);
        assert!(
            !service
                .load_library_stats(true)
                .await
                .expect("retry after cancellation")
                .from_cache
        );
        assert_eq!(transport.count.load(Ordering::SeqCst), 3);
    }
}
