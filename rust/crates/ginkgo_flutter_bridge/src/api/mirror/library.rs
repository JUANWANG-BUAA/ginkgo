//! Synthetic use cases projected through the same public DTOs.
use super::*;

pub(super) fn load_demo_library() -> LibraryDemoResponse {
    match application::demo_library::load() {
        Ok(library) => LibraryDemoResponse {
            venues: library.venues.into_iter().map(library_venue).collect(),
            areas: library.areas.into_iter().map(library_area).collect(),
            slots: library.slots.into_iter().map(library_slot).collect(),
            seats: library.seats.into_iter().map(library_seat).collect(),
            bookings: library.bookings.into_iter().map(library_booking).collect(),
        },
        Err(_) => LibraryDemoResponse {
            venues: vec![],
            areas: vec![],
            slots: vec![],
            seats: vec![],
            bookings: vec![],
        },
    }
}
