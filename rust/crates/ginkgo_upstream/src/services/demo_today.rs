//! Synthetic today's schedule compiled from the shared fixture.
use crate::{
    codecs::today::{self, TodayCourse},
    AppError,
};
use serde_json::Value;

pub struct DemoToday {
    pub date: String,
    pub courses: Vec<TodayCourse>,
}

pub fn load() -> Result<DemoToday, AppError> {
    let fixture: Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/schedule/today-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let body = fixture
        .get("input")
        .and_then(|input| input.get("body"))
        .cloned()
        .ok_or_else(AppError::changed)?;
    Ok(DemoToday {
        date: "2026-10-20".into(),
        courses: today::parse_courses(body)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_today_matches_fixture() {
        let today = load().expect("today");
        assert_eq!(today.date, "2026-10-20");
        assert_eq!(today.courses.len(), 2);
        assert_eq!(today.courses[0].name, "算法设计与分析");
    }
}
