//! Synthetic grade snapshot compiled from the shared fixture.
use crate::{
    features::grades::{self, GradeCourse, GradeSummary},
    AppError,
};
use serde_json::Value;

pub struct DemoGrades {
    pub term_id: String,
    pub courses: Vec<GradeCourse>,
    pub summary: GradeSummary,
}

pub fn load() -> Result<DemoGrades, AppError> {
    let text = include_str!("../../../../../fixtures/grades/normal-v1.json");
    let fixture: Value = serde_json::from_str(text).map_err(|_| AppError::changed())?;
    let body = fixture
        .get("input")
        .and_then(|input| input.get("body"))
        .cloned()
        .ok_or_else(AppError::changed)?;
    let courses = grades::parse_courses(body)?;
    let summary = grades::summarize(&courses);
    Ok(DemoGrades {
        term_id: "2026-2027-1".into(),
        courses,
        summary,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_grades_match_fixture_and_summary() {
        let grades = load().expect("demo grades");
        assert_eq!(grades.term_id, "2026-2027-1");
        assert_eq!(grades.courses.len(), 2);
        assert!((grades.summary.credit_total - 7.0).abs() < 0.001);
        assert!(grades.summary.weighted_average.is_some());
    }
}
