//! Anonymous public library HTML read (LibraryPublicStats.swift).
use crate::{
    auth::session::{RouteMode, Session},
    codecs::library_stats::{self, CampusStats},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError,
};
pub const URL: &str =
    "https://lib.buaa.edu.cn/engine2/buaa/more/1082575?websiteId=113745&pageId=208561&wfwfid=16662";
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
    let response = shared
        .send_anonymous(
            HttpRequest::get(URL)
                .header("Accept", "text/html,application/xhtml+xml")
                .header("Referer", "https://lib.buaa.edu.cn/")
                .header("User-Agent", "Ginkgo/1.0"),
            preference,
        )
        .await?;
    parse_response(&response)
}
