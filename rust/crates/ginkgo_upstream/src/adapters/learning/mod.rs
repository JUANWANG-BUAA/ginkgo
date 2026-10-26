//! School protocol registry; each feature owns its endpoint and encoding.
use crate::{
    adapters::homework_http::{self, SpocAuth, SPOC_BASE},
    auth::session::Session,
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use serde_json::Value;
pub mod announcements;
pub mod assessments;
pub mod resources;
pub async fn auth<T: HttpTransport>(s: &Session<T>) -> Result<SpocAuth, AppError> {
    homework_http::authenticate(s).await
}
pub fn query(fields: &[(&str, &str)]) -> String {
    url::form_urlencoded::Serializer::new(String::new())
        .extend_pairs(fields.iter().copied())
        .finish()
}
pub async fn request<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    r: HttpRequest,
) -> Result<Value, AppError> {
    let r = s
        .send(
            r.header("Token", &format!("Inco-{}", a.token))
                .header("RoleCode", &a.role),
        )
        .await?;
    let v = decode(r)?;
    crate::codecs::homework::content(&v).cloned()
}
fn decode(r: HttpResponse) -> Result<Value, AppError> {
    if matches!(r.status, 401 | 403) || r.body.trim_start().starts_with('<') {
        return Err(AppError::session_expired());
    }
    if r.status / 100 != 2 {
        return Err(AppError::unavailable());
    }
    serde_json::from_str(&r.body).map_err(|_| AppError::changed())
}
pub async fn courses<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
) -> Result<Vec<ginkgo_domain::ports::LearningCourse>, AppError> {
    let mut out = Vec::new();
    let mut ids = std::collections::BTreeSet::new();
    for page in 1..=50 {
        let v = request(
            s,
            a,
            HttpRequest::get(format!(
                "{SPOC_BASE}/kc/queryXskcListPage?pageNum={page}&pageSize=100"
            )),
        )
        .await?;
        let actual_page = crate::codecs::learning::required(&v, "pageNum")?
            .parse::<u32>()
            .map_err(|_| AppError::changed())?;
        if actual_page != page {
            return Err(AppError::changed());
        }
        let rows = crate::codecs::learning::courses(&v)?;
        for row in rows {
            if !ids.insert(row.id.clone()) {
                return Err(AppError::changed());
            }
            out.push(row);
        }
        if !v["hasNextPage"].as_bool().ok_or_else(AppError::changed)? {
            return Ok(out);
        }
    }
    Err(AppError::changed())
}
pub async fn ensure_course<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    id: &str,
) -> Result<(), AppError> {
    if courses(s, a).await?.iter().any(|c| c.id == id) {
        Ok(())
    } else {
        Err(AppError::new(ErrorCode::AccessPolicyDenied))
    }
}
pub async fn columns<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
) -> Result<Vec<ginkgo_domain::ports::LearningColumn>, AppError> {
    let v = request(
        s,
        a,
        HttpRequest::get(format!(
            "{SPOC_BASE}/kczxdhl/queryKcdhlList?{}",
            query(&[("kcid", course), ("sflx", "2")])
        )),
    )
    .await?;
    crate::codecs::learning::columns(&v)
}
pub(super) async fn select_column<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    course: &str,
    kind: ginkgo_domain::ports::LearningColumnKind,
    selected: Option<&str>,
) -> Result<String, AppError> {
    if selected.is_some_and(|id| id.is_empty() || id.len() > 256) {
        return Err(AppError::invalid());
    }
    let found: Vec<_> = columns(s, a, course)
        .await?
        .into_iter()
        .filter(|c| c.kind == kind && selected.is_none_or(|id| c.id == id))
        .collect();
    if found.len() != 1 {
        return Err(if selected.is_some() {
            AppError::new(ErrorCode::AccessPolicyDenied)
        } else {
            AppError::changed()
        });
    }
    Ok(found[0].id.clone())
}
pub async fn binary<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    url: String,
) -> Result<Vec<u8>, AppError> {
    binary_request(s, a, HttpRequest::get(url)).await
}
pub(super) async fn binary_request<T: HttpTransport>(
    s: &Session<T>,
    a: &SpocAuth,
    r: HttpRequest,
) -> Result<Vec<u8>, AppError> {
    let mut r = r
        .header("Token", &format!("Inco-{}", a.token))
        .header("RoleCode", &a.role);
    r.binary_response = true;
    r.response_limit = Some(20 * 1024 * 1024);
    let v = s.send(r).await?;
    if matches!(v.status, 401 | 403) {
        return Err(AppError::session_expired());
    }
    // A verified file may itself be JSON/HTML. Require an attachment response
    // for ambiguous MIME types, rather than globally rejecting those files.
    let attachment = v
        .header("content-disposition")
        .is_some_and(|v| v.to_ascii_lowercase().starts_with("attachment;"));
    if v.status != 200
        || (!attachment
            && v.header("content-type")
                .is_some_and(|v| v.contains("text/html") || v.contains("application/json")))
    {
        return Err(AppError::unavailable());
    }
    let bytes = v.bytes.ok_or_else(AppError::changed)?;
    if bytes.len() > 20 * 1024 * 1024 {
        return Err(AppError::invalid());
    }
    // Inspect only a bounded prefix. MIME and Content-Disposition alone cannot
    // establish success: school login/error replies sometimes masquerade as blobs.
    let prefix = String::from_utf8_lossy(&bytes[..bytes.len().min(8192)]).to_lowercase();
    if (prefix.contains("<form")
        && (prefix.contains("caslogin")
            || prefix.contains("name=\"execution\"")
            || prefix.contains("type=\"password\"")))
        || prefix.contains("<title>统一身份认证")
        || prefix.contains("<title>登录")
    {
        return Err(AppError::session_expired());
    }
    if bytes.len() <= 8192 {
        if let Ok(value) = serde_json::from_slice::<Value>(&bytes) {
            if value.is_object()
                && value.get("code").is_some()
                && (value.get("content").is_some() || value.get("msg").is_some())
            {
                // A recognized school error envelope is not a file, even with
                // an attachment header. Ordinary JSON documents remain valid.
                crate::codecs::homework::content(&value)?;
            }
        }
    }
    Ok(bytes)
}

#[cfg(test)]
mod tests;
