//! Public GitHub request with its own direct session: no school cookies or VPN.
use crate::{
    auth::session::{RouteMode, Session},
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
pub const URL: &str = "https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases?per_page=100";
pub async fn load<T: HttpTransport + Sync>(session: &Session<T>) -> Result<String, AppError> {
    session.set_route(RouteMode::Direct);
    let response = session
        .send_following_redirects(
            HttpRequest::get(URL)
                .header("Accept", "application/vnd.github+json")
                .header("User-Agent", "Ginkgo-Android-Update")
                .header("X-GitHub-Api-Version", "2022-11-28"),
        )
        .await?;
    if response.status == 403 || response.status == 429 {
        return Err(AppError::with_detail(
            ErrorCode::ServiceUnavailable,
            "rate_limited",
        ));
    }
    if response.status != 200 || response.final_url != URL {
        return Err(AppError::unavailable());
    }
    Ok(response.body)
}
