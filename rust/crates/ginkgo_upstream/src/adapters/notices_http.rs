use crate::{
    auth::session::Session,
    features::notices::{self, Notice},
    foundation::http::{HttpRequest, HttpTransport},
    AppError,
};
pub async fn load<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Notice>, AppError> {
    let response = session
        .send_following_redirects(
            HttpRequest::get(crate::endpoints::NOTICE_PAGE.as_str())
                .header("Accept", "text/html,application/xhtml+xml"),
        )
        .await?;
    if response.status != 200
        || url::Url::parse(&response.final_url)
            .ok()
            .is_none_or(|url| url.host_str() != crate::endpoints::NOTICE_PAGE.host_str())
    {
        return Err(AppError::unavailable());
    }
    notices::parse(&response.body)
}
