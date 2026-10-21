//! booking.lib read-only use cases (API.md §5.2, §5.6).
//!
//! The business token lives in memory. A library login-expired answer rebuilds
//! that token once; a missing WebVPN gateway login triggers the shared gateway
//! sign-in. Venue and current-booking lists keep the previous snapshot when a
//! refresh fails.
use super::{
    cache::now_shanghai,
    session_service::{is_library_login_error, SessionService},
};
use crate::{
    adapters::library_http,
    auth::CredentialVault,
    features::library::{LibraryArea, LibraryBooking, LibrarySeat, LibrarySlot, LibraryVenue},
    foundation::{http::HttpTransport, school_time},
    AppError,
};

const VENUES_KEY: &str = "venues";
const BOOKINGS_KEY: &str = "bookings";

fn needs_relogin<T>(result: &Result<T, AppError>) -> bool {
    result.as_ref().err().is_some_and(is_library_login_error)
}

#[derive(Debug, Clone)]
pub struct LibraryVenuesOutcome {
    pub venues: Vec<LibraryVenue>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

#[derive(Debug, Clone)]
pub struct LibraryBookingsOutcome {
    pub bookings: Vec<LibraryBooking>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

#[derive(Debug, Clone)]
pub struct LibraryHistoryOutcome {
    pub data: crate::features::library::LibraryHistoryPage,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_library_history(
        &self,
        page: i32,
        force_refresh: bool,
    ) -> Result<LibraryHistoryOutcome, AppError> {
        let account = self.current_account()?;
        if page < 1 {
            return Err(AppError::invalid());
        }
        if !force_refresh {
            let cache = self.library_history.lock();
            if let Some(entry) = cache.fresh(&page) {
                return Ok(LibraryHistoryOutcome {
                    data: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }
        let result = async {
            let token = self.library_token().await?;
            let result = library_http::history(&self.session, &token, page, 40).await;
            if needs_relogin(&result) {
                self.invalidate_library_token(&token);
                let token = self.library_token().await?;
                library_http::history(&self.session, &token, page, 40).await
            } else {
                result
            }
        }
        .await;
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        let mut cache = self.library_history.lock();
        match result {
            Ok(data) => {
                let fetched_at = cache.insert(page, data.clone());
                Ok(LibraryHistoryOutcome {
                    data,
                    fetched_at,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => match cache.any(&page) {
                Some(entry) => Ok(LibraryHistoryOutcome {
                    data: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: true,
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }

    pub async fn load_library_venues(
        &self,
        force_refresh: bool,
    ) -> Result<LibraryVenuesOutcome, AppError> {
        self.current_account()?;
        let day = school_time::beijing_day(&now_shanghai())?.local_date;
        if !force_refresh {
            let cached = self.library_venues.lock();
            if let Some(entry) = cached.fresh(&VENUES_KEY.to_owned()) {
                return Ok(LibraryVenuesOutcome {
                    venues: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let result = async {
            let mut token = self.library_token().await?;
            let mut result = library_http::venues(&self.session, &token, &day).await;
            if needs_relogin(&result) {
                self.invalidate_library_token(&token);
                token = self.library_token().await?;
                result = library_http::venues(&self.session, &token, &day).await;
            }
            result
        }
        .await;

        match result {
            Ok(venues) => {
                let timestamp = self
                    .library_venues
                    .lock()
                    .insert(VENUES_KEY.to_owned(), venues.clone());
                Ok(LibraryVenuesOutcome {
                    venues,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.library_venues.lock();
                match cached.any(&VENUES_KEY.to_owned()) {
                    Some(entry) => Ok(LibraryVenuesOutcome {
                        venues: entry.value.clone(),
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }

    pub async fn load_library_areas(&self, library_id: &str) -> Result<Vec<LibraryArea>, AppError> {
        self.current_account()?;
        if library_id.trim().is_empty() {
            return Err(AppError::invalid());
        }
        let day = school_time::beijing_day(&now_shanghai())?.local_date;
        let mut token = self.library_token().await?;
        let mut result = library_http::areas(&self.session, &token, library_id, &day).await;
        if needs_relogin(&result) {
            self.invalidate_library_token(&token);
            token = self.library_token().await?;
            result = library_http::areas(&self.session, &token, library_id, &day).await;
        }
        result
    }

    pub async fn load_library_slots(&self, area_id: &str) -> Result<Vec<LibrarySlot>, AppError> {
        self.current_account()?;
        if area_id.trim().is_empty() {
            return Err(AppError::invalid());
        }
        let mut token = self.library_token().await?;
        let mut result = library_http::slots(&self.session, &token, area_id).await;
        if needs_relogin(&result) {
            self.invalidate_library_token(&token);
            token = self.library_token().await?;
            result = library_http::slots(&self.session, &token, area_id).await;
        }
        result
    }

    pub async fn load_library_seats(
        &self,
        area_id: &str,
        slot_id: &str,
        day: &str,
        start: &str,
        end: &str,
    ) -> Result<Vec<LibrarySeat>, AppError> {
        self.current_account()?;
        let slot = LibrarySlot {
            id: slot_id.trim().to_owned(),
            day: day.trim().to_owned(),
            start: start.trim().to_owned(),
            end: end.trim().to_owned(),
        };
        if area_id.trim().is_empty()
            || slot.id.is_empty()
            || slot.start.is_empty()
            || slot.end.is_empty()
            || chrono::NaiveDate::parse_from_str(&slot.day, "%Y-%m-%d").is_err()
        {
            return Err(AppError::invalid());
        }
        let mut token = self.library_token().await?;
        let mut result = library_http::seats(&self.session, &token, area_id, &slot).await;
        if needs_relogin(&result) {
            self.invalidate_library_token(&token);
            token = self.library_token().await?;
            result = library_http::seats(&self.session, &token, area_id, &slot).await;
        }
        result
    }

    pub async fn load_library_bookings(
        &self,
        force_refresh: bool,
    ) -> Result<LibraryBookingsOutcome, AppError> {
        self.current_account()?;
        if !force_refresh {
            let cached = self.library_bookings.lock();
            if let Some(entry) = cached.fresh(&BOOKINGS_KEY.to_owned()) {
                return Ok(LibraryBookingsOutcome {
                    bookings: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let result = async {
            let mut token = self.library_token().await?;
            let mut result = library_http::bookings(&self.session, &token).await;
            if needs_relogin(&result) {
                self.invalidate_library_token(&token);
                token = self.library_token().await?;
                result = library_http::bookings(&self.session, &token).await;
            }
            result
        }
        .await;

        match result {
            Ok(bookings) => {
                let timestamp = self
                    .library_bookings
                    .lock()
                    .insert(BOOKINGS_KEY.to_owned(), bookings.clone());
                Ok(LibraryBookingsOutcome {
                    bookings,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.library_bookings.lock();
                match cached.any(&BOOKINGS_KEY.to_owned()) {
                    Some(entry) => Ok(LibraryBookingsOutcome {
                        bookings: entry.value.clone(),
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }

    pub(crate) async fn library_token(&self) -> Result<String, AppError> {
        let cached = { self.identity.lock().library_token.clone() };
        if let Some(token) = cached {
            return Ok(token);
        }
        // Match UBAA loginMutex: only one CAS exchange may build the token.
        let _login = self.library_login_gate.lock().await;
        if let Some(token) = self.identity.lock().library_token.clone() {
            return Ok(token);
        }
        let account = self.current_account()?;
        let token = self.login_library().await?;
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        self.identity.lock().library_token = Some(token.clone());
        Ok(token)
    }

    fn invalidate_library_token(&self, rejected: &str) {
        let mut identity = self.identity.lock();
        let token = &mut identity.library_token;
        // A late failure only invalidates the credential actually used by that
        // request. A peer may already have completed a successful recovery.
        if token.as_deref() == Some(rejected) {
            *token = None;
        }
    }

    async fn login_library(&self) -> Result<String, AppError> {
        let first = match library_http::login(&self.session).await {
            Ok(token) => return Ok(token),
            Err(error) => error,
        };
        let routed_cas_expired = is_library_login_error(&first)
            && self.session.route() == crate::auth::session::RouteMode::WebVpn;
        if first.detail.as_deref() != Some("webvpn_login_required") && !routed_cas_expired {
            return Err(first);
        }
        self.ensure_webvpn_session().await?;
        library_http::login(&self.session).await
    }
}

#[cfg(test)]
mod token_recovery_tests {
    use super::*;
    use crate::{auth::session::Session, auth::vault::MemoryVault, test_support::MockTransport};

    #[tokio::test]
    async fn late_expiry_must_not_erase_a_token_already_replaced_by_another_read() {
        let transport = MockTransport::default();
        let service = SessionService::new(Session::new(transport.clone()), MemoryVault::default());
        // Two reads used old-token. The first has already recovered; the late
        // response from the second is only evidence against old-token.
        service.identity.lock().library_token = Some("synthetic-new-token".into());
        service.invalidate_library_token("synthetic-old-token");
        let token = service.library_token().await.expect("reuse peer recovery");
        assert_eq!(token, "synthetic-new-token");
        assert_eq!(transport.request_count(), 0);
        service.invalidate_library_token("synthetic-new-token");
        assert!(service.identity.lock().library_token.is_none());
        // An earlier token cannot invalidate the absence of a token either.
        service.invalidate_library_token("synthetic-old-token");
        assert!(service.identity.lock().library_token.is_none());
    }
}
