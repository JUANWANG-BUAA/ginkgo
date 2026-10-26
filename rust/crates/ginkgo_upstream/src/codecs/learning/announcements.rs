use super::*;
use ginkgo_domain::ports::*;
pub fn list(v: &Value) -> Result<Vec<CourseAnnouncement>, AppError> {
    rows(v)?
        .iter()
        .map(|r| {
            Ok(CourseAnnouncement {
                id: required(r, "id")?,
                title: required(r, "bt")?,
                published_at: if optional(r, "fbzt")?.as_deref() == Some("1") {
                    optional(r, "zhxgsj")?
                } else {
                    None
                },
            })
        })
        .collect()
}
pub fn detail(v: &Value, id: &str) -> Result<CourseAnnouncementDetail, AppError> {
    if !v.is_object() {
        return Err(AppError::changed());
    }
    if let Some(found) = optional(v, "id")? {
        if found != id {
            return Err(AppError::changed());
        }
    }
    let attachments = match v.get("fjlist") {
        None | Some(Value::Null) => vec![],
        Some(v) => rows(v)?
            .iter()
            .map(|r| {
                Ok(LearningAttachment {
                    id: required(r, "wjid")?,
                    name: required(r, "wjmc")?,
                })
            })
            .collect::<Result<_, AppError>>()?,
    };
    let content = optional(v, "nr")?.map(|s| {
        regex::Regex::new("<[^>]*>")
            .expect("constant")
            .replace_all(&s, " ")
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .trim()
            .to_owned()
    });
    Ok(CourseAnnouncementDetail {
        id: id.into(),
        title: required(v, "bt")?,
        content,
        attachments,
    })
}
