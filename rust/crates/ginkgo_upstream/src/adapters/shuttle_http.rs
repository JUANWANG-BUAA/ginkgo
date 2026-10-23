//! Official shuttle timetable HTTP (API §6C). Public page, isolated cookies.
use crate::{
    auth::session::{RouteMode, Session},
    codecs::shuttle,
    features::shuttle::ShuttleTimetable,
    foundation::http::{HttpRequest, HttpResponse, HttpTransport, TransportError},
    AppError,
};
pub use shuttle::SOURCE_URL;

/// Borrow the transport, not the signed-in session's cookie jars: the published
/// timetable needs no identity and must not carry one.
struct PublicTransport<'a, T>(&'a T);
impl<T: HttpTransport + Sync> HttpTransport for PublicTransport<'_, T> {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.0.send(request).await
    }
}

pub fn parse_response(response: &HttpResponse) -> Result<ShuttleTimetable, AppError> {
    let parsed = url::Url::parse(&response.final_url).map_err(|_| AppError::changed())?;
    if response.status != 200 || parsed.scheme() != "https" || parsed.host_str() != Some("www.buaa.edu.cn") {
        return Err(AppError::with_detail(
            crate::ErrorCode::ServiceUnavailable,
            format!("shuttle_http_{}", response.status),
        ));
    }
    shuttle::parse(&response.body)
}

pub async fn load<T: HttpTransport + Sync>(
    shared: &Session<T>,
    preference: RouteMode,
) -> Result<ShuttleTimetable, AppError> {
    let isolated = Session::new(PublicTransport(shared.transport()));
    isolated.set_route(preference);
    let response = isolated
        .send_following_redirects(
            HttpRequest::get(SOURCE_URL)
                .header("Accept", "text/html,application/xhtml+xml")
                .header("User-Agent", "Ginkgo/1.0"),
        )
        .await?;
    parse_response(&response)
}
