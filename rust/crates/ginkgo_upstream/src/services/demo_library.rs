//! Synthetic booking.lib snapshot compiled from the shared fixtures.
use crate::{
    codecs::library::{self, LibraryArea, LibraryBooking, LibrarySeat, LibrarySlot, LibraryVenue},
    AppError,
};
use serde_json::Value;

pub struct DemoLibrary {
    pub venues: Vec<LibraryVenue>,
    pub areas: Vec<LibraryArea>,
    pub slots: Vec<LibrarySlot>,
    pub seats: Vec<LibrarySeat>,
    pub bookings: Vec<LibraryBooking>,
}

fn data(name: &str) -> Result<Value, AppError> {
    let fixture: Value = match name {
        "venues" => serde_json::from_str(include_str!(
            "../../../../../fixtures/library/venues-normal-v1.json"
        )),
        "areas" => serde_json::from_str(include_str!(
            "../../../../../fixtures/library/areas-normal-v1.json"
        )),
        "slots" => serde_json::from_str(include_str!(
            "../../../../../fixtures/library/slots-normal-v1.json"
        )),
        "seats" => serde_json::from_str(include_str!(
            "../../../../../fixtures/library/seats-normal-v1.json"
        )),
        _ => serde_json::from_str(include_str!(
            "../../../../../fixtures/library/bookings-normal-v1.json"
        )),
    }
    .map_err(|_| AppError::changed())?;
    fixture
        .get("input")
        .and_then(|input| input.get("data"))
        .cloned()
        .ok_or_else(AppError::changed)
}

pub fn load() -> Result<DemoLibrary, AppError> {
    Ok(DemoLibrary {
        venues: library::parse_venues(&data("venues")?)?,
        areas: library::parse_areas(&data("areas")?)?,
        slots: library::parse_slots(&data("slots")?)?,
        seats: library::parse_seats(&data("seats")?)?,
        bookings: library::parse_bookings(&data("bookings")?)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_library_matches_the_shared_fixtures() {
        let library = load().expect("demo library");
        assert_eq!(library.venues.len(), 2);
        assert_eq!(library.areas.len(), 2);
        assert_eq!(library.slots.len(), 2);
        assert_eq!(library.seats.len(), 2);
        assert_eq!(library.bookings.len(), 2);
    }
}
