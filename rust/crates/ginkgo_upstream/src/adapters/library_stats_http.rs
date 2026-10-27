//! Cookie-isolated public library HTML read (LibraryPublicStats.swift).
use crate::{
    auth::session::{RouteMode, Session},
    codecs::library_stats::{self, CampusStats},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport, TransportError},
    AppError,
};
pub const URL: &str =
    "https://lib.buaa.edu.cn/engine2/buaa/more/1082575?websiteId=113745&pageId=208561&wfwfid=16662";
// Borrow the transport, not the signed-in session's cookie jars.
struct PublicTransport<'a, T>(&'a T);
impl<T: HttpTransport + Sync> HttpTransport for PublicTransport<'_, T> {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.0.send(request).await
    }
}
pub fn parse_response(response: &HttpResponse) -> Result<Vec<CampusStats>, AppError> {
    if response.status != 200
        || url::Url::parse(&response.final_url)
            .ok()
            .is_none_or(|url| url.host_str() != Some("lib.buaa.edu.cn") || url.scheme() != "https")
    {
        return Err(AppError::unavailable());
    }
    library_stats::parse(&response.body)
}
pub async fn load<T: HttpTransport + Sync>(
    shared: &Session<T>,
    preference: RouteMode,
) -> Result<Vec<CampusStats>, AppError> {
    let isolated = Session::new(PublicTransport(shared.transport()));
    // The authenticated session may already have fallen back to WebVPN.
    // Start this public session from the user preference, not that transient state.
    isolated.set_route(preference);
    let response = isolated
        .send_following_redirects(
            HttpRequest::get(URL)
                .header("Accept", "text/html,application/xhtml+xml")
                .header("Referer", "https://lib.buaa.edu.cn/")
                .header("User-Agent", "Ginkgo/1.0"),
        )
        .await?;
    parse_response(&response)
}
