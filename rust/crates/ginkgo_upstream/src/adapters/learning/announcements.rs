use super::*;
use ginkgo_domain::ports::*;
pub async fn list<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
) -> Result<Vec<CourseAnnouncement>, AppError> {
    list_in(s, a, course, None).await
}
pub async fn list_in<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
    selected: Option<&str>,
) -> Result<Vec<CourseAnnouncement>, AppError> {
    let node = select_column(s, a, course, LearningColumnKind::Announcement, selected).await?;
    let v = request(
        s,
        a,
        HttpRequest::post_form(
            format!("{SPOC_BASE}/kcgg/queryKcggList"),
            serde_json::json!({"kcid":course,"sfxs":1,"sslmid":node}).to_string(),
        )
        .header("Content-Type", "application/json"),
    )
    .await?;
    crate::codecs::learning::announcements::list(&v)
}
pub async fn detail<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    id: &str,
) -> Result<CourseAnnouncementDetail, AppError> {
    let v = request(
        s,
        a,
        HttpRequest::post_form(
            format!("{SPOC_BASE}/kcgg/queryDgKcgg"),
            serde_json::json!({"id":id}).to_string(),
        )
        .header("Content-Type", "application/json"),
    )
    .await?;
    // Never call updYdb: reading must not automatically mark notices read.
    crate::codecs::learning::announcements::detail(&v, id)
}
pub async fn download<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    file: &str,
) -> Result<Vec<u8>, AppError> {
    binary(
        s,
        a,
        format!(
            "https://spoc.buaa.edu.cn/inco-filesystem/fileManagerSystem/downLoadFile?{}",
            query(&[("scjlid", file)])
        ),
    )
    .await
}
