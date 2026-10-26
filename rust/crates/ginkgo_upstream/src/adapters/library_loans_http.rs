//! API §6.2. Uses the account cookie session, not the anonymous catalogue jar.
use crate::{
    auth::session::Session,
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use ginkgo_domain::features::library_loans::LibraryLoanPage;
const HOST: &str = "space.lib.buaa.edu.cn";
const BASE: &str = "https://space.lib.buaa.edu.cn/meta-local/opac";
const LIMIT: usize = 512 * 1024;

pub fn portal_url() -> String {
    "https://space.lib.buaa.edu.cn/mspace/reader/lendList".into()
}
fn trusted(url: &url::Url) -> bool {
    url.scheme() == "https"
        && url.username().is_empty()
        && url.password().is_none()
        && url.port_or_known_default() == Some(443)
        && matches!(url.host_str(), Some(HOST | "sso.buaa.edu.cn"))
}
/// Only follow the documented OPAC/CAS hosts. Never send credentials or copy
/// cookies manually; reaching a login form requires explicit login in the App.
async fn get<T: HttpTransport + Sync>(
    session: &Session<T>,
    initial: String,
) -> Result<HttpResponse, AppError> {
    let mut next = initial;
    let mut stages = Vec::new();
    for _ in 0..10 {
        let url = url::Url::parse(&next).map_err(|_| AppError::changed())?;
        if !trusted(&url) {
            return Err(AppError::changed());
        }
        stages.push(match (url.host_str(), url.path()) {
            (Some("sso.buaa.edu.cn"), _) => "sso",
            (Some(HOST), "/meta-local/opac/cas/rosetta") => "entry",
            (Some(HOST), "/space/casBoard") => "board",
            (Some(HOST), "/meta-local/opac/users/loans") => "loans",
            _ => "other",
        });
        let mut request =
            HttpRequest::get(next).header("Accept", "application/json, text/plain, */*");
        request.response_limit = Some(LIMIT);
        let r = session.send_with_fallback(request).await?;
        let final_url = url::Url::parse(&r.final_url).map_err(|_| AppError::changed())?;
        if !trusted(&final_url) {
            return Err(AppError::session_expired());
        }
        if matches!(r.status, 301 | 302 | 303 | 307 | 308) {
            next = final_url
                .join(r.header("location").ok_or_else(AppError::changed)?)
                .map_err(|_| AppError::changed())?
                .into();
            continue;
        }
        if r.status == 401 || final_url.host_str() == Some("sso.buaa.edu.cn") {
            return Err(AppError::session_expired());
        }
        if r.status == 403 {
            return Err(AppError::new(ErrorCode::AccessPolicyDenied));
        }
        if matches!(r.status, 404 | 410) {
            return Err(AppError::changed());
        }
        if r.status != 200 {
            return Err(AppError::unavailable());
        }
        if r.body.len() > LIMIT {
            return Err(AppError::changed());
        }
        return Ok(r);
    }
    Err(AppError::with_detail(
        ErrorCode::RedirectLimit,
        format!("loans_redirect_chain_{}", stages.join("_")),
    ))
}
pub async fn establish<T: HttpTransport + Sync>(session: &Session<T>) -> Result<(), AppError> {
    let r = get(session, format!("{BASE}/cas/rosetta")).await?;
    let u = url::Url::parse(&r.final_url).map_err(|_| AppError::changed())?;
    if !matches!(u.path(), "/space/casBoard" | "/meta-local/opac/cas/rosetta") {
        return Err(AppError::session_expired());
    }
    Ok(())
}
pub async fn load<T: HttpTransport + Sync>(
    session: &Session<T>,
    page: u32,
) -> Result<LibraryLoanPage, AppError> {
    let r = get(
        session,
        format!("{BASE}/users/loans?page={page}&pageSize=100"),
    )
    .await?;
    let u = url::Url::parse(&r.final_url).map_err(|_| AppError::changed())?;
    if u.path() != "/meta-local/opac/users/loans" {
        return Err(AppError::session_expired());
    }
    let value = serde_json::from_str(&r.body).map_err(|_| AppError::changed())?;
    crate::codecs::library_loans::page(&value, page)
}
