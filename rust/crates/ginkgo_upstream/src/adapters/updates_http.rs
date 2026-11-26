//! Anonymous GitHub request: no school cookies and no session route mutation.
use crate::{
    auth::session::{RouteMode, Session},
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
pub const URL: &str = "https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases?per_page=100";
const MIRROR_URL: &str =
    "https://gh-proxy.com/https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases?per_page=100";

async fn fetch_release_json<T: HttpTransport + Sync>(
    session: &Session<T>,
    url: &str,
) -> Result<String, AppError> {
    let response = session
        .send_anonymous(
            HttpRequest::get(url)
                .header("Accept", "application/vnd.github+json")
                .header("User-Agent", "Ginkgo-Android-Update")
                .header("X-GitHub-Api-Version", "2022-11-28"),
            RouteMode::Direct,
        )
        .await?;
    if response.status == 403 || response.status == 429 {
        return Err(AppError::with_detail(
            ErrorCode::ServiceUnavailable,
            "rate_limited",
        ));
    }
    if response.status != 200 || response.final_url != url {
        return Err(AppError::unavailable());
    }
    Ok(response.body)
}

pub async fn load<T: HttpTransport + Sync>(session: &Session<T>) -> Result<String, AppError> {
    match fetch_release_json(session, URL).await {
        Ok(body) => Ok(body),
        Err(err) if err.detail.as_deref() == Some("rate_limited") => Err(err),
        Err(_) => fetch_release_json(session, MIRROR_URL).await,
    }
}
