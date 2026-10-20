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

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_library_venues(
        &self,
        force_refresh: bool,
    ) -> Result<LibraryVenuesOutcome, AppError> {
        self.current_account()?;
        let day = school_time::beijing_day(&now_shanghai())?.local_date;
        if !force_refresh {
            let cached = self.library_venues.lock().expect("library venues");
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

        let mut token = self.library_token().await?;
        let mut result = library_http::venues(&self.session, &token, &day).await;
        if needs_relogin(&result) {
            self.reset_library_token();
            token = self.library_token().await?;
            result = library_http::venues(&self.session, &token, &day).await;
        }

        match result {
            Ok(venues) => {
                let timestamp = self
                    .library_venues
                    .lock()
                    .expect("library venues")
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
                let cached = self.library_venues.lock().expect("library venues");
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
            self.reset_library_token();
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
            self.reset_library_token();
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
            self.reset_library_token();
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
            let cached = self.library_bookings.lock().expect("library bookings");
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

        let mut token = self.library_token().await?;
        let mut result = library_http::bookings(&self.session, &token).await;
        if needs_relogin(&result) {
            self.reset_library_token();
            token = self.library_token().await?;
            result = library_http::bookings(&self.session, &token).await;
        }

        match result {
            Ok(bookings) => {
                let timestamp = self
                    .library_bookings
                    .lock()
                    .expect("library bookings")
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
                let cached = self.library_bookings.lock().expect("library bookings");
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

    async fn library_token(&self) -> Result<String, AppError> {
        let cached = { self.library_token.lock().expect("library token").clone() };
        if let Some(token) = cached {
            return Ok(token);
        }
        let token = self.login_library().await?;
        *self.library_token.lock().expect("library token") = Some(token.clone());
        Ok(token)
    }

    fn reset_library_token(&self) {
        *self.library_token.lock().expect("library token") = None;
    }

    async fn login_library(&self) -> Result<String, AppError> {
        let first = match library_http::login(&self.session).await {
            Ok(token) => return Ok(token),
            Err(error) => error,
        };
        if first.detail.as_deref() != Some("webvpn_login_required") {
            return Err(first);
        }
        self.ensure_webvpn_session().await?;
        library_http::login(&self.session).await
    }
}
