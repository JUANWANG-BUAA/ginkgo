//! Coarse use cases. Decode untrusted input here; domain never sees Flutter state.
mod bykc_service;
mod cache;
pub use bykc_service::BykcOutcome;
mod checkin_service;
mod classroom_service;
pub mod contracts;
pub mod demo_checkin;
pub mod demo_grades;
pub mod demo_homework;
pub mod demo_library;
pub mod demo_repository;
pub mod demo_schedule;
pub mod demo_today;
mod homework_service;
pub use homework_service::{HomeworkDetailOutcome, HomeworkOutcome};
mod library_service;
mod schedule_service;
pub mod session_service;
use crate::{
    features::{classroom, schedule},
    foundation::school_time,
    AppError,
};
pub use checkin_service::CheckInOutcome;
pub use classroom_service::{ClassroomOutcome, ClassroomQueryInput};
pub use contracts::execute_contract;
pub use library_service::{LibraryBookingsOutcome, LibraryVenuesOutcome};
pub use schedule_service::{
    GradeData, GradeOutcome, ScheduleData, ScheduleOutcome, ScheduleQueryInput, TodayOutcome,
};
use serde::Deserialize;
pub use session_service::{RoutePreference, SessionOutcome, SessionService, SessionStatus};

/// Synthetic demo source is compiled from the shared fixture, never copied to Dart.
#[derive(Deserialize)]
struct ClassroomFixture {
    input: classroom::FilterRequest,
}

pub fn demo_classrooms(
    search: String,
    section: i32,
    minimum_free_sections: i32,
    minimum_consecutive_sections: i32,
    building: Option<String>,
    sort: classroom::Sort,
) -> Result<classroom::FilterResult, AppError> {
    let mut fixture: ClassroomFixture = serde_json::from_str(include_str!(
        "../../../../../fixtures/classroom/filter-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    fixture.input.search = search;
    fixture.input.section = section;
    fixture.input.minimum_free_sections = minimum_free_sections;
    fixture.input.minimum_consecutive_sections = minimum_consecutive_sections;
    fixture.input.building = building;
    fixture.input.sort = sort;
    classroom::filter(fixture.input)
}

pub fn demo_rules() -> Result<(school_time::SchoolDay, schedule::Snapshot), AppError> {
    #[derive(Deserialize)]
    struct TimeFixture {
        input: school_time::DayRequest,
    }
    #[derive(Deserialize)]
    struct ScheduleFixture {
        input: schedule::MergeRequest,
    }
    let time: TimeFixture = serde_json::from_str(include_str!(
        "../../../../../fixtures/time/beijing-day-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let schedule: ScheduleFixture = serde_json::from_str(include_str!(
        "../../../../../fixtures/schedule/week-snapshot-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let snapshot = schedule::retain_weeks(schedule.input)?;
    let selected = snapshot.select_week(5).ok_or_else(AppError::changed)?;
    Ok((school_time::beijing_day(&time.input.instant)?, selected))
}

#[cfg(test)]
mod tests;

mod graduate_service;
pub use graduate_service::GraduateOutcome;

pub mod tasks_service;

mod notices_service;
pub use notices_service::NoticesOutcome;
