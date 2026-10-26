use super::*;
use ginkgo_domain::ports::*;
pub async fn page<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
    folder: Option<&str>,
    page: u32,
) -> Result<CourseResourcePage, AppError> {
    let path: Vec<String> = folder.into_iter().map(str::to_owned).collect();
    page_at(s, a, course, &path, page).await
}
/// A caller provides a root-to-leaf chain, not authority. Every edge is freshly
/// proven from the authorized parent's bounded pages using this same auth.
pub async fn page_at<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
    path: &[String],
    page: u32,
) -> Result<CourseResourcePage, AppError> {
    if !(1..=100).contains(&page) || path.len() > 8 {
        return Err(AppError::invalid());
    }
    let mut ancestors = std::collections::BTreeSet::new();
    for id in path {
        if id.is_empty() || id == "0" || id.len() > 256 || !ancestors.insert(id.clone()) {
            return Err(AppError::invalid());
        }
    }
    let mut parent: Option<&str> = None;
    let mut pages = 0;
    let mut nodes = 0;
    for child in path {
        let mut seen = std::collections::BTreeSet::new();
        let mut found = false;
        for n in 1..=5 {
            pages += 1;
            if pages >= 40 {
                return Err(AppError::new(ErrorCode::AccessPolicyDenied));
            }
            let listing = raw_page(s, a, course, parent, n).await?;
            nodes += listing.items.len();
            if nodes > 800 {
                return Err(AppError::new(ErrorCode::AccessPolicyDenied));
            }
            for row in &listing.items {
                if !seen.insert(row.id.clone()) {
                    return Err(AppError::changed());
                }
                if row.id == *child {
                    found = row.folder;
                }
            }
            if !listing.has_next {
                break;
            }
            if n == 5 {
                return Err(AppError::new(ErrorCode::AccessPolicyDenied));
            }
        }
        if !found {
            return Err(AppError::new(ErrorCode::AccessPolicyDenied));
        }
        parent = Some(child);
    }
    let result = raw_page(s, a, course, parent, page).await?;
    if nodes + result.items.len() > 800 {
        return Err(AppError::new(ErrorCode::AccessPolicyDenied));
    }
    Ok(result)
}

async fn raw_page<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
    folder: Option<&str>,
    page: u32,
) -> Result<CourseResourcePage, AppError> {
    let q = query(&[
        ("kcid", course),
        ("pageNum", &page.to_string()),
        ("pageSize", "20"),
        ("pid", folder.unwrap_or("0")),
        ("mcTab", ""),
        ("lmlxdm", ""),
        ("wjlx", ""),
    ]);
    let endpoint = if folder.is_some() {
        "/grwj1/queryKcwjListgr"
    } else {
        "/kcwj/queryListPageXs"
    };
    let v = request(
        s,
        a,
        HttpRequest::post_form(format!("{SPOC_BASE}{endpoint}?{q}"), String::new()),
    )
    .await?;
    crate::codecs::learning::resources::page(&v, page)
}
pub async fn download<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    id: &str,
) -> Result<Vec<u8>, AppError> {
    let v = request(
        s,
        a,
        HttpRequest::get(format!(
            "{SPOC_BASE}/grwj1/getWjids?{}",
            query(&[("ids", id)])
        )),
    )
    .await?;
    if crate::codecs::learning::required(&v, "flag")? != "1" {
        return Err(AppError::new(ErrorCode::AccessPolicyDenied));
    }
    binary_request(
        s,
        a,
        HttpRequest::post_form(
            format!("{SPOC_BASE}/grwj1/downLoadFile?{}", query(&[("id", id)])),
            "{}",
        )
        .header("Content-Type", "application/json"),
    )
    .await
}
