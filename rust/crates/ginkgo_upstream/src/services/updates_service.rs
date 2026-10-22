use crate::{
    adapters::updates_http,
    auth::session::Session,
    features::updates::{self, UpdateSummary},
    foundation::http::HttpTransport,
    AppError,
};
/// Caller provides a dedicated transport, never the account session.
pub async fn check<T: HttpTransport + Sync>(
    transport: T,
    current: &str,
) -> Result<UpdateSummary, AppError> {
    let session = Session::new(transport);
    updates::parse(&updates_http::load(&session).await?, current)
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::foundation::http::{HttpRequest, HttpResponse, TransportError};
    struct Public;
    impl HttpTransport for Public {
        async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
            assert_eq!(request.url, updates_http::URL);
            assert!(request.header_value("Cookie").is_none());
            assert!(request.header_value("Authorization").is_none());
            Ok(HttpResponse::new(
                200,
                updates_http::URL,
                serde_json::from_str::<serde_json::Value>(include_str!(
                    "../../../../../fixtures/updates/releases-v1.json"
                ))
                .unwrap()["input"]["releases"]
                    .to_string(),
            ))
        }
    }
    #[tokio::test]
    async fn public_update_is_cookie_free_and_parsed() {
        assert!(check(Public, "0.1.0-alpha.1").await.unwrap().available);
    }
}
