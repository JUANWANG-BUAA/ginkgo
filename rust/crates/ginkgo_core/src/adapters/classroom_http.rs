//! Classroom HTTP request construction and response classification.
//!
//! The transport is injected so request sequencing, auth-page detection, and
//! parser failures can be tested before the real cookie session is migrated.
use crate::{
    auth::{self, session::Session, CredentialSource, LoginResult},
    features::classroom::{self, Room},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use chrono::NaiveDate;
use std::collections::BTreeMap;

pub const ACTIVATION_URL: &str = "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fapp.buaa.edu.cn%2Fa_buaa%2Fapi%2Fcas%2Findex%3Fredirect%3Dhttps%253A%252F%252Fapp.buaa.edu.cn%252Fsite%252FclassRoomQuery%252Findex%26from%3Dwap%26login_from%3D&noAutoRedirect=1";
const CLASSROOM_BASE: &str = "https://app.buaa.edu.cn/buaafreeclass/wap/default/search1";
const CLASSROOM_REFERER: &str = "https://app.buaa.edu.cn/site/classRoomQuery/index";

/// Run the two documented classroom requests with the caller-owned session.
/// This only performs reads: SSO activation plus the classroom query.
pub async fn query_classrooms<T: HttpTransport>(
    session: &Session<T>,
    campus: i32,
    date: &str,
) -> Result<BTreeMap<String, Vec<Room>>, AppError> {
    if !(1..=3).contains(&campus) || NaiveDate::parse_from_str(date, "%Y-%m-%d").is_err() {
        return Err(AppError::invalid());
    }

    session
        .send_with_fallback(HttpRequest::get(ACTIVATION_URL))
        .await?;

    let request = HttpRequest::get(format!(
        "{CLASSROOM_BASE}?xqid={campus}&floorid=&date={date}"
    ))
    .header("Accept", "application/json, text/javascript, */*; q=0.01")
    .header("X-Requested-With", "XMLHttpRequest")
    .header("Referer", CLASSROOM_REFERER);
    let response = session.send_with_fallback(request).await?;

    if is_login_response(&response) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::unavailable());
    }
    let value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    classroom::parse_upstream_response(value)
}

/// Retry a classroom read exactly once after a confirmed expired session.
/// Sign-in uses the platform credential port; a captcha during silent recovery
/// surfaces as a typed error instead of retrying blindly.
pub async fn query_classrooms_with_recovery<T: HttpTransport, C: CredentialSource>(
    session: &Session<T>,
    store: &C,
    account: &str,
    campus: i32,
    date: &str,
) -> Result<BTreeMap<String, Vec<Room>>, AppError> {
    match query_classrooms(session, campus, date).await {
        Err(error) if error.code == ErrorCode::SessionExpired => {
            match auth::login_with_store(session, store, account).await? {
                LoginResult::SignedIn(_) => {}
                LoginResult::CaptchaRequired(_) => {
                    return Err(AppError::new(ErrorCode::CaptchaRequired))
                }
            }
            query_classrooms(session, campus, date).await
        }
        other => other,
    }
}

fn is_login_response(response: &HttpResponse) -> bool {
    if matches!(response.status, 401 | 403) || response.final_url.contains("sso.buaa.edu.cn/login")
    {
        return true;
    }
    let body = response.body.to_lowercase();
    body.contains("<title>cas login</title>")
        || body.contains("统一身份认证")
        || body.contains("name=\"execution\"")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{auth::Credentials, foundation::http::HttpMethod, test_support::MockTransport};
    use serde::Deserialize;
    use serde_json::Value;
    use std::{fs, path::Path};

    #[derive(Deserialize)]
    struct Fixture {
        input: Value,
    }

    fn fixture(name: &str) -> Fixture {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../fixtures/classroom")
            .join(name);
        serde_json::from_str(&fs::read_to_string(path).expect("read fixture"))
            .expect("valid fixture")
    }

    fn response(body: String) -> HttpResponse {
        HttpResponse::new(200, CLASSROOM_BASE, body)
    }

    #[tokio::test]
    async fn sends_activation_then_documented_query_and_parses_rooms() {
        let body =
            serde_json::to_string(&fixture("upstream-normal-v1.json").input).expect("json fixture");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ACTIVATION_URL, ""),
            response(body),
        ]);
        let session = Session::new(transport);

        let rooms = query_classrooms(&session, 2, "2026-10-20")
            .await
            .expect("valid response");
        assert_eq!(rooms["主楼"][0].id, "A101");
        let requests = session.transport().requests();
        assert_eq!(requests[0].url, ACTIVATION_URL);
        let query = &requests[1];
        assert_eq!(
            query.url,
            "https://app.buaa.edu.cn/buaafreeclass/wap/default/search1?xqid=2&floorid=&date=2026-10-20"
        );
        assert_eq!(query.headers["X-Requested-With"], "XMLHttpRequest");
        assert_eq!(query.headers["Referer"], CLASSROOM_REFERER);
    }

    #[tokio::test]
    async fn valid_empty_list_is_not_a_structure_error() {
        let body =
            serde_json::to_string(&fixture("upstream-empty-v1.json").input).expect("json fixture");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ACTIVATION_URL, ""),
            response(body),
        ]);
        let session = Session::new(transport);
        let rooms = query_classrooms(&session, 3, "2026-10-20")
            .await
            .expect("empty response");
        assert!(rooms.is_empty());
    }

    #[tokio::test]
    async fn login_page_requires_a_new_session() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ACTIVATION_URL, ""),
            HttpResponse::new(
                200,
                "https://sso.buaa.edu.cn/login",
                "<title>CAS Login</title>",
            ),
        ]);
        let session = Session::new(transport);
        assert_eq!(
            query_classrooms(&session, 1, "2026-10-20")
                .await
                .expect_err("login page")
                .code,
            crate::ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn upstream_business_error_and_transport_failure_are_distinct() {
        let body =
            serde_json::to_string(&fixture("upstream-error-v1.json").input).expect("json fixture");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ACTIVATION_URL, ""),
            response(body),
        ]);
        let session = Session::new(transport);
        assert_eq!(
            query_classrooms(&session, 1, "2026-10-20")
                .await
                .expect_err("business error")
                .code,
            crate::ErrorCode::ServiceUnavailable
        );

        let unavailable = Session::new(MockTransport::default());
        assert_eq!(
            query_classrooms(&unavailable, 1, "2026-10-20")
                .await
                .expect_err("transport failure")
                .code,
            crate::ErrorCode::ServiceUnavailable
        );
    }

    #[tokio::test]
    async fn invalid_scope_is_rejected_before_network() {
        let transport = MockTransport::default();
        let session = Session::new(transport);
        assert_eq!(
            query_classrooms(&session, 0, "2026-10-20")
                .await
                .expect_err("campus")
                .code,
            crate::ErrorCode::InvalidRequest
        );
        assert_eq!(
            query_classrooms(&session, 1, "2026-02-30")
                .await
                .expect_err("date")
                .code,
            crate::ErrorCode::InvalidRequest
        );
        assert!(session.transport().requests().is_empty());
    }

    struct Vault;

    impl CredentialSource for Vault {
        fn load(&self, account: &str) -> Result<Option<Credentials>, AppError> {
            if account != "fixture-account" {
                return Ok(None);
            }
            Ok(Some(Credentials {
                username: "sy2501001".into(),
                password: "pa+ss/word".into(),
                captcha_text: None,
            }))
        }
    }

    #[tokio::test]
    async fn expired_session_recovers_with_one_login_and_one_retry() {
        let body =
            serde_json::to_string(&fixture("upstream-normal-v1.json").input).expect("json fixture");
        let login_page = r#"<form action="/login" method="post">
          <input type="hidden" name="execution" value="abc+def/ghi=" />
          <input type="text" name="username" /><input type="password" name="password" />
        </form>"#;
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ACTIVATION_URL, ""),
            HttpResponse::new(
                200,
                CLASSROOM_BASE,
                r#"<html><input name="execution" value="expired" /></html>"#,
            ),
            HttpResponse::new(200, "https://sso.buaa.edu.cn/login", login_page),
            HttpResponse::new(302, "https://sso.buaa.edu.cn/login", "")
                .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1"),
            HttpResponse::new(
                200,
                "https://sso.buaa.edu.cn/login?ticket=ST-1",
                "<html>ok</html>",
            ),
            HttpResponse::new(200, auth::UC_ACTIVATION_URL, ""),
            HttpResponse::new(
                200,
                auth::UC_STATUS_URL,
                r#"{"code":0,"data":{"schoolid":"sy2501001","name":"fixture"}}"#,
            ),
            HttpResponse::new(200, ACTIVATION_URL, ""),
            response(body),
        ]);
        let session = Session::new(transport);

        let rooms =
            query_classrooms_with_recovery(&session, &Vault, "fixture-account", 2, "2026-10-20")
                .await
                .expect("recovered response");
        assert_eq!(rooms["主楼"][0].id, "A101");

        let requests = session.transport().requests();
        let post = requests
            .iter()
            .find(|request| request.method == HttpMethod::Post)
            .expect("login post");
        let body = post.body.as_deref().expect("form body");
        assert!(body.contains("execution=abc%2Bdef%2Fghi%3D"));
        assert!(body.contains("password=pa%2Bss%2Fword"));
        assert_eq!(
            requests
                .iter()
                .filter(|request| request.url == ACTIVATION_URL)
                .count(),
            2
        );
    }

    #[tokio::test]
    async fn missing_stored_credentials_stop_recovery() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ACTIVATION_URL, ""),
            HttpResponse::new(200, CLASSROOM_BASE, r#"<html>统一身份认证</html>"#),
        ]);
        let session = Session::new(transport);
        assert_eq!(
            query_classrooms_with_recovery(&session, &Vault, "unknown-account", 1, "2026-10-20")
                .await
                .expect_err("no credentials")
                .code,
            ErrorCode::SessionExpired
        );
    }
}
