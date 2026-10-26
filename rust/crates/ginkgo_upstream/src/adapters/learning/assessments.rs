use super::*;
use ginkgo_domain::ports::*;
pub async fn list<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
) -> Result<Vec<CourseAssessment>, AppError> {
    list_in(s, a, course, None).await
}
pub async fn list_in<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
    selected: Option<&str>,
) -> Result<Vec<CourseAssessment>, AppError> {
    let node = select_column(s, a, course, LearningColumnKind::Assessment, selected).await?;
    let v = request(
        s,
        a,
        HttpRequest::post_form(
            format!("{SPOC_BASE}/csgl/queryCsglXsList"),
            query(&[("kcid", course), ("flag", "xs"), ("id", &node)]),
        ),
    )
    .await?;
    crate::codecs::learning::assessments::list(&v, course)
}
