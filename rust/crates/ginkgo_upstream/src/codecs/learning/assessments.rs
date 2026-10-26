use super::*;
use ginkgo_domain::ports::*;
pub fn list(v: &Value, course: &str) -> Result<Vec<CourseAssessment>, AppError> {
    rows(&v["list"])?
        .iter()
        .map(|r| {
            Ok(CourseAssessment {
                id: required(r, "id")?,
                title: required(r, "csmc")?,
                starts_at: optional(r, "kssj")?,
                due_at: optional(r, "jzsj")?,
                score: None,
                source_url: course_url(course),
            })
        })
        .collect()
}
