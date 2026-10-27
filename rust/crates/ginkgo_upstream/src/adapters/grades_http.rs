//! buaascore activation and grade query (API.md §4).
use crate::{
    auth::{cas, session::Session},
    codecs::grades::{self, GradeCourse},
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};

pub const GRADE_URL: &str = "https://app.buaa.edu.cn/buaascore/wap/default/index";

pub async fn load_grades<T: HttpTransport>(
    session: &Session<T>,
    term_code: &str,
) -> Result<Vec<GradeCourse>, AppError> {
    let (year, semester) = grades::term_parts(term_code)?;
    let activation = session
        .send_following_redirects(HttpRequest::get(GRADE_URL).header(
            "Accept",
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ))
        .await?;
    if is_login_response(&activation) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&activation.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }

    let body = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("xq", &semester)
        .append_pair("year", &year)
        .finish();
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(GRADE_URL, body)
                .header("Accept", "application/json, text/javascript, */*; q=0.01")
                .header("X-Requested-With", "XMLHttpRequest")
                .header("Referer", GRADE_URL),
        )
        .await?;
    if is_login_response(&response) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    if response.body.trim_start().starts_with('<') {
        return Err(AppError::changed());
    }
    let value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    grades::parse_courses(value)
}

fn is_login_response(response: &crate::foundation::http::HttpResponse) -> bool {
    matches!(response.status, 401 | 403)
        || response.final_url.contains("sso.buaa.edu.cn")
        || response.body.contains("统一身份认证")
        || cas::is_login_redirect(&response.final_url, &response.body)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        foundation::http::{HttpMethod, HttpResponse},
        test_support::MockTransport,
    };
    use serde_json::Value;

    fn fixture(name: &str) -> Value {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../fixtures/grades")
            .join(name);
        let fixture: Value =
            serde_json::from_str(&std::fs::read_to_string(path).expect("fixture")).expect("json");
        fixture["input"]["body"].clone()
    }

    #[tokio::test]
    async fn activates_then_posts_documented_term_form() {
        let body = serde_json::to_string(&fixture("normal-v1.json")).expect("json");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, GRADE_URL, "<html>ok</html>"),
            HttpResponse::new(200, GRADE_URL, body),
        ]);
        let session = Session::new(transport);
        let courses = load_grades(&session, "2026-2027-1").await.expect("grades");
        assert_eq!(courses.len(), 2);

        let requests = session.transport().requests();
        assert_eq!(requests[0].method, HttpMethod::Get);
        assert_eq!(requests[1].method, HttpMethod::Post);
        assert_eq!(requests[1].body.as_deref(), Some("xq=1&year=2026-2027"));
        assert_eq!(requests[1].header_value("Referer"), Some(GRADE_URL));
    }

    #[tokio::test]
    async fn graduate_term_code_is_normalized() {
        let body = serde_json::to_string(&fixture("empty-v1.json")).expect("json");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, GRADE_URL, "<html>ok</html>"),
            HttpResponse::new(200, GRADE_URL, body),
        ]);
        let session = Session::new(transport);
        let _ = load_grades(&session, "20252").await.expect("grades");
        let requests = session.transport().requests();
        assert_eq!(requests[1].body.as_deref(), Some("xq=2&year=2025-2026"));
    }

    #[tokio::test]
    async fn login_page_during_activation_is_session_expired() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login",
            r#"<input name="execution" value="x" />"#,
        )]);
        assert_eq!(
            load_grades(&Session::new(transport), "2026-2027-1")
                .await
                .expect_err("login")
                .code,
            ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn business_error_stays_service_unavailable() {
        let body = serde_json::to_string(&fixture("business-error-v1.json")).expect("json");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, GRADE_URL, "<html>ok</html>"),
            HttpResponse::new(200, GRADE_URL, body),
        ]);
        assert_eq!(
            load_grades(&Session::new(transport), "2026-2027-1")
                .await
                .expect_err("business")
                .code,
            ErrorCode::ServiceUnavailable
        );
    }
}
