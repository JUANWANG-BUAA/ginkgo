//! Synthetic schedule bundle compiled from shared fixtures.
use crate::{
    codecs::schedule::{self, CourseMeeting, Exam, Term, Week},
    AppError,
};
use serde_json::Value;

pub struct DemoSchedule {
    pub terms: Vec<Term>,
    pub weeks: Vec<Week>,
    pub week_number: i32,
    pub courses: Vec<CourseMeeting>,
    pub exams: Vec<Exam>,
}

pub fn load() -> Result<DemoSchedule, AppError> {
    let terms = schedule::parse_terms(body(include_str!(
        "../../../../../fixtures/schedule/terms-normal-v1.json"
    ))?)?;
    let weeks = schedule::parse_weeks(body(include_str!(
        "../../../../../fixtures/schedule/weeks-normal-v1.json"
    ))?)?;
    let courses = schedule::parse_undergraduate_courses(body(include_str!(
        "../../../../../fixtures/schedule/courses-normal-v1.json"
    ))?)?;
    let exams = schedule::parse_exams(body(include_str!(
        "../../../../../fixtures/schedule/exams-normal-v1.json"
    ))?)?;
    let week_number = weeks
        .iter()
        .find(|week| week.current)
        .map(|week| week.number)
        .unwrap_or(1);
    Ok(DemoSchedule {
        terms,
        weeks,
        week_number,
        courses,
        exams,
    })
}

fn body(text: &str) -> Result<Value, AppError> {
    let fixture: Value = serde_json::from_str(text).map_err(|_| AppError::changed())?;
    fixture
        .get("input")
        .and_then(|input| input.get("body"))
        .cloned()
        .ok_or_else(AppError::changed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_bundle_matches_shared_fixtures() {
        let bundle = load().expect("demo schedule");
        assert_eq!(bundle.terms.len(), 2);
        assert_eq!(bundle.week_number, 2);
        assert_eq!(bundle.weeks.len(), 2);
        assert_eq!(bundle.courses.len(), 2);
        assert_eq!(bundle.courses[0].name, "算法设计与分析");
        assert_eq!(bundle.exams.len(), 2);
    }
}
