use crate::{
    auth::session::Session,
    features::notices::{self, Notice},
    foundation::http::{HttpRequest, HttpTransport},
    AppError,
};
pub async fn load<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Notice>, AppError> {
    let response = session
        .send_following_redirects(
            HttpRequest::get("https://news.buaa.edu.cn/tzgg.htm")
                .header("Accept", "text/html,application/xhtml+xml"),
        )
        .await?;
    if response.status != 200
        || url::Url::parse(&response.final_url)
            .ok()
            .and_then(|u| u.host_str().map(str::to_owned))
            .as_deref()
            != Some("news.buaa.edu.cn")
    {
        return Err(AppError::unavailable());
    }
    notices::parse(&response.body)
}
