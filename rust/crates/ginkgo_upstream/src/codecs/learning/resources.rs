use super::*;
use ginkgo_domain::ports::*;
pub fn page(v: &Value, requested: u32) -> Result<CourseResourcePage, AppError> {
    let page = optional(v, "pageNum")?
        .ok_or_else(AppError::changed)?
        .parse::<u32>()
        .map_err(|_| AppError::changed())?;
    if page != requested {
        return Err(AppError::changed());
    }
    let has_next = v["hasNextPage"].as_bool().ok_or_else(AppError::changed)?;
    let items = rows(&v["list"])?
        .iter()
        .map(|r| {
            let folder = required(r, "sfwjj")?;
            if folder != "0" && folder != "1" {
                return Err(AppError::changed());
            }
            Ok(CourseResource {
                id: required(r, "id")?,
                name: required(r, "wjmc")?,
                folder: folder == "1",
                downloadable: optional(r, "sfkxz")?.as_deref() == Some("1") && folder == "0",
                updated_at: optional(r, "czsj")?,
                extension: optional(r, "wjhzm")?,
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    let mut ids = std::collections::BTreeSet::new();
    if items.iter().any(|item| !ids.insert(&item.id)) {
        return Err(AppError::changed());
    }
    Ok(CourseResourcePage {
        page,
        has_next,
        items,
    })
}
