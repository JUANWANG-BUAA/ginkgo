//! Stable library business capability and values.
use crate::{
    features::{
        library::{LibraryArea, LibraryBooking, LibrarySeat, LibrarySlot, LibraryVenue},
        mutation::MutationOutcome,
    },
    AppError,
};
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

pub type LibraryHistoryOutcome = super::ReadSnapshot<crate::features::library::LibraryHistoryPage>;

pub trait LibrarySource: Send + Sync {
    fn load_library_history(
        &self,
        page: i32,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<LibraryHistoryOutcome, AppError>> + Send;
    fn load_library_venues(
        &self,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<LibraryVenuesOutcome, AppError>> + Send;
    fn load_library_areas(
        &self,
        library_id: &str,
    ) -> impl std::future::Future<Output = Result<Vec<LibraryArea>, AppError>> + Send;
    fn load_library_slots(
        &self,
        area_id: &str,
    ) -> impl std::future::Future<Output = Result<Vec<LibrarySlot>, AppError>> + Send;
    fn load_library_seats(
        &self,
        area_id: &str,
        slot_id: &str,
        day: &str,
        start: &str,
        end: &str,
    ) -> impl std::future::Future<Output = Result<Vec<LibrarySeat>, AppError>> + Send;
    fn load_library_bookings(
        &self,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<LibraryBookingsOutcome, AppError>> + Send;
}

pub trait LibraryMutationSource: Send + Sync {
    fn reserve_library_seat(
        &self,
        area_id: &str,
        seat_id: &str,
        slot: LibrarySlot,
    ) -> impl std::future::Future<Output = MutationOutcome> + Send;
    fn perform_library_action(
        &self,
        booking_id: &str,
        action: &str,
    ) -> impl std::future::Future<Output = MutationOutcome> + Send;
}
