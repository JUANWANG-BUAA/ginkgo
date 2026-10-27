//! Official shuttle timetable HTTP (API §6C). Public page, isolated cookies.
use crate::{
    auth::session::{RouteMode, Session},
    codecs::shuttle,
    codecs::shuttle::ShuttleTimetable,
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
    if response.status != 200
        || parsed.scheme() != "https"
        || parsed.host_str() != Some("www.buaa.edu.cn")
    {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{foundation::http::HttpMethod, foundation::webvpn, ErrorCode};
    use std::{collections::VecDeque, sync::Mutex};

    // Synthetic only: a readable four-column timetable, not an upstream sample.
    const PAGE: &str = r#"<table>
      <tr><td colspan="2">合成去程</td><td colspan="2">合成返程</td></tr>
      <tr><td colspan="4">合成工作日</td></tr>
      <tr><td>1</td><td>7:30</td><td>1</td><td>7:35</td></tr>
    </table>"#;

    struct ScriptedTransport {
        responses: Mutex<VecDeque<Result<HttpResponse, TransportError>>>,
        requests: Mutex<Vec<HttpRequest>>,
    }

    impl ScriptedTransport {
        fn new(responses: Vec<Result<HttpResponse, TransportError>>) -> Self {
            Self {
                responses: Mutex::new(responses.into()),
                requests: Mutex::new(Vec::new()),
            }
        }

        fn requests(&self) -> Vec<HttpRequest> {
            self.requests.lock().unwrap().clone()
        }
    }

    impl HttpTransport for ScriptedTransport {
        async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
            self.requests.lock().unwrap().push(request);
            self.responses
                .lock()
                .unwrap()
                .pop_front()
                .expect("unexpected request beyond the scripted route attempts")
        }
    }

    #[tokio::test]
    async fn public_get_is_anonymous_and_cannot_pollute_either_shared_cookie_jar_or_route() {
        let gateway_url = webvpn::wrap(SOURCE_URL).unwrap();
        for preference in [RouteMode::Direct, RouteMode::Automatic, RouteMode::WebVpn] {
            let routed_url = if preference == RouteMode::WebVpn {
                &gateway_url
            } else {
                SOURCE_URL
            };
            let shared = Session::new(ScriptedTransport::new(vec![
                Ok(HttpResponse::new(200, SOURCE_URL, "seed direct")
                    .with_set_cookie("signed_direct=synthetic; Path=/; Secure")),
                Ok(HttpResponse::new(200, &gateway_url, "seed gateway")
                    .with_set_cookie("signed_gateway=synthetic; Path=/; Secure")),
                Ok(HttpResponse::new(200, routed_url, PAGE)
                    .with_set_cookie("signed_direct=public; Path=/; Secure")
                    .with_set_cookie("signed_gateway=public; Path=/; Secure")
                    .with_set_cookie("public_only=synthetic; Path=/; Secure")),
                Ok(HttpResponse::new(200, routed_url, PAGE)),
                Ok(HttpResponse::new(200, SOURCE_URL, "probe direct")),
                Ok(HttpResponse::new(200, &gateway_url, "probe gateway")),
            ]));
            shared
                .send_direct(HttpRequest::get(SOURCE_URL))
                .await
                .unwrap();
            shared.set_route(RouteMode::WebVpn);
            shared.send(HttpRequest::get(SOURCE_URL)).await.unwrap();
            assert!(shared.direct_cookie_present());
            assert!(shared.webvpn_cookie_present());
            // The shared route intentionally differs from Direct/Automatic.
            // Public reads use the preference, without changing shared state.
            for _ in 0..2 {
                let timetable = load(&shared, preference).await.unwrap();
                assert_eq!(timetable.source, SOURCE_URL);
                assert_eq!(timetable.tables[0].sections[0].right[0].time, "7:35");
                assert_eq!(shared.route(), RouteMode::WebVpn);
            }
            shared
                .send_direct(HttpRequest::get(SOURCE_URL))
                .await
                .unwrap();
            shared.send(HttpRequest::get(SOURCE_URL)).await.unwrap();
            let requests = shared.transport().requests();
            assert_eq!(requests.len(), 6);
            for request in &requests[2..4] {
                assert_eq!(request.method, HttpMethod::Get);
                assert_eq!(request.url, routed_url);
                assert_eq!(request.body, None);
                assert_eq!(request.header_value("cookie"), None);
                assert_eq!(
                    request.header_value("Accept"),
                    Some("text/html,application/xhtml+xml")
                );
            }
            assert_eq!(
                requests[4].header_value("cookie"),
                Some("signed_direct=synthetic")
            );
            assert_eq!(
                requests[5].header_value("cookie"),
                Some("signed_gateway=synthetic")
            );
            assert!(shared.transport().responses.lock().unwrap().is_empty());
        }
    }

    #[tokio::test]
    async fn non_200_responses_fail_without_parsing_a_readable_body() {
        for status in [204, 302, 401, 403, 483, 500, 503] {
            let shared = Session::new(ScriptedTransport::new(vec![Ok(HttpResponse::new(
                status, SOURCE_URL, PAGE,
            ))]));
            let error = load(&shared, RouteMode::Direct).await.unwrap_err();
            assert_eq!(error.code, ErrorCode::ServiceUnavailable);
            assert_eq!(error.detail, Some(format!("shuttle_http_{status}")));
            assert_eq!(shared.transport().requests().len(), 1);
            assert_eq!(shared.route(), RouteMode::Automatic);
        }
    }

    #[tokio::test]
    async fn non_official_or_insecure_final_urls_fail_even_with_a_readable_body() {
        for final_url in [
            "https://example.invalid/",
            "https://www.buaa.edu.cn.example.invalid/",
            "https://sso.buaa.edu.cn/login",
            "http://www.buaa.edu.cn/info/1065/1762.htm",
        ] {
            let shared = Session::new(ScriptedTransport::new(vec![Ok(HttpResponse::new(
                200, final_url, PAGE,
            ))]));
            let error = load(&shared, RouteMode::Direct).await.unwrap_err();
            assert_eq!(error.code, ErrorCode::ServiceUnavailable);
            assert_eq!(shared.transport().requests().len(), 1);
        }
        assert_eq!(
            parse_response(&HttpResponse::new(200, "not a URL", PAGE))
                .unwrap_err()
                .code,
            ErrorCode::ChangedResponse
        );
    }

    #[tokio::test]
    async fn malformed_or_unreadable_html_is_a_changed_response_not_an_empty_timetable() {
        for body in [
            "",
            "<html><body>synthetic unavailable page</body></html>",
            "<table><tr><td>incomplete",
            "<table><tr><td colspan=2>left</td><td colspan=2>right</td></tr></table>",
        ] {
            let shared = Session::new(ScriptedTransport::new(vec![Ok(HttpResponse::new(
                200, SOURCE_URL, body,
            ))]));
            assert_eq!(
                load(&shared, RouteMode::Direct).await.unwrap_err().code,
                ErrorCode::ChangedResponse
            );
            assert_eq!(shared.transport().requests().len(), 1);
            assert!(!shared.direct_cookie_present());
            assert!(!shared.webvpn_cookie_present());
        }
    }

    #[tokio::test]
    async fn public_same_host_redirect_uses_only_its_own_temporary_cookie() {
        let destination = "https://www.buaa.edu.cn/synthetic-timetable.htm";
        let shared = Session::new(ScriptedTransport::new(vec![
            Ok(HttpResponse::new(302, SOURCE_URL, "")
                .with_header("Location", "/synthetic-timetable.htm")
                .with_set_cookie("public_redirect=synthetic; Path=/; Secure")),
            Ok(HttpResponse::new(200, destination, PAGE)),
            Ok(HttpResponse::new(200, SOURCE_URL, "probe")),
        ]));
        let timetable = load(&shared, RouteMode::Direct).await.unwrap();
        assert_eq!(timetable.tables.len(), 1);
        assert!(!shared.direct_cookie_present());
        assert!(!shared.webvpn_cookie_present());
        shared
            .send_direct(HttpRequest::get(SOURCE_URL))
            .await
            .unwrap();
        let requests = shared.transport().requests();
        assert_eq!(requests.len(), 3);
        assert_eq!(requests[0].header_value("cookie"), None);
        assert_eq!(requests[1].method, HttpMethod::Get);
        assert_eq!(requests[1].url, destination);
        assert_eq!(requests[1].body, None);
        assert_eq!(
            requests[1].header_value("cookie"),
            Some("public_redirect=synthetic")
        );
        assert_eq!(requests[2].header_value("cookie"), None);
    }

    #[tokio::test]
    async fn failed_public_response_cannot_create_a_shared_session_cookie() {
        let shared = Session::new(ScriptedTransport::new(vec![
            Ok(HttpResponse::new(503, SOURCE_URL, "synthetic failure")
                .with_set_cookie("public_only=synthetic; Path=/; Secure")),
            Ok(HttpResponse::new(200, SOURCE_URL, "probe")),
        ]));
        assert_eq!(
            load(&shared, RouteMode::Direct).await.unwrap_err().code,
            ErrorCode::ServiceUnavailable
        );
        assert!(!shared.direct_cookie_present());
        assert!(!shared.webvpn_cookie_present());
        shared
            .send_direct(HttpRequest::get(SOURCE_URL))
            .await
            .unwrap();
        let requests = shared.transport().requests();
        assert_eq!(requests.len(), 2);
        assert_eq!(requests[1].header_value("cookie"), None);
    }

    #[tokio::test]
    async fn transport_failure_keeps_the_existing_safe_get_fallback_bounded() {
        let gateway_url = webvpn::wrap(SOURCE_URL).unwrap();
        for preference in [RouteMode::Direct, RouteMode::WebVpn, RouteMode::Automatic] {
            let shared = Session::new(ScriptedTransport::new(vec![
                Err(TransportError::Unavailable),
                Err(TransportError::Unavailable),
                // Further replay would spuriously turn failure into success.
                Ok(HttpResponse::new(200, SOURCE_URL, PAGE)),
            ]));
            let error = load(&shared, preference).await.unwrap_err();
            assert_eq!(error.code, ErrorCode::ServiceUnavailable);
            let requests = shared.transport().requests();
            let expected_attempts = if preference == RouteMode::Automatic {
                2
            } else {
                1
            };
            assert_eq!(requests.len(), expected_attempts, "route {preference:?}");
            assert_eq!(
                requests[0].url,
                if preference == RouteMode::WebVpn {
                    &gateway_url
                } else {
                    SOURCE_URL
                }
            );
            if preference == RouteMode::Automatic {
                assert_eq!(requests[1].url, gateway_url);
            }
            for request in &requests {
                assert_eq!(request.method, HttpMethod::Get);
                assert_eq!(request.body, None);
                assert_eq!(request.header_value("cookie"), None);
            }
            assert_eq!(shared.route(), RouteMode::Automatic);
            assert!(!shared.direct_cookie_present());
            assert!(!shared.webvpn_cookie_present());
        }
    }
}
