//! library application commands depend only on business ports.
use super::*;

impl<U: LibrarySource> Workspace<U> {
    pub async fn load_library_history(
        &self,
        page: i32,
        force_refresh: bool,
    ) -> Result<LibraryHistoryOutcome, AppError> {
        self.upstream
            .load_library_history(page, force_refresh)
            .await
    }
    pub async fn load_library_venues(
        &self,
        force_refresh: bool,
    ) -> Result<LibraryVenuesOutcome, AppError> {
        self.upstream.load_library_venues(force_refresh).await
    }
    pub async fn load_library_areas(&self, library_id: &str) -> Result<Vec<LibraryArea>, AppError> {
        self.upstream.load_library_areas(library_id).await
    }
    pub async fn load_library_slots(&self, area_id: &str) -> Result<Vec<LibrarySlot>, AppError> {
        self.upstream.load_library_slots(area_id).await
    }
    pub async fn load_library_seats(
        &self,
        area_id: &str,
        slot_id: &str,
        day: &str,
        start: &str,
        end: &str,
    ) -> Result<Vec<LibrarySeat>, AppError> {
        self.upstream
            .load_library_seats(area_id, slot_id, day, start, end)
            .await
    }
    pub async fn load_library_bookings(
        &self,
        force_refresh: bool,
    ) -> Result<LibraryBookingsOutcome, AppError> {
        self.upstream.load_library_bookings(force_refresh).await
    }
}

impl<U: LibraryMutationSource> Workspace<U> {
    pub async fn reserve_library_seat(
        &self,
        area_id: &str,
        seat_id: &str,
        slot: LibrarySlot,
    ) -> MutationOutcome {
        self.upstream
            .reserve_library_seat(area_id, seat_id, slot)
            .await
    }
    pub async fn perform_library_action(&self, booking_id: &str, action: &str) -> MutationOutcome {
        self.upstream
            .perform_library_action(booking_id, action)
            .await
    }
}
