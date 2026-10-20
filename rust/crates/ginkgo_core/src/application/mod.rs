//! Coarse use cases. Decode untrusted input here; domain never sees Flutter state.
pub mod contracts;
pub mod demo_grades;
pub mod demo_homework;
pub mod demo_repository;
pub mod demo_schedule;
pub mod demo_today;
use crate::{
    features::{classroom, schedule},
    foundation::school_time,
    AppError,
};
pub use contracts::execute_contract;
use serde::Deserialize;

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
