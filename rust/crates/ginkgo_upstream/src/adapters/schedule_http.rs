//! BYXT undergraduate schedule requests (API.md §2).
use crate::{
    auth::cas,
    auth::session::Session,
    features::schedule::{self, CourseMeeting, Exam, Term, Week},
    features::today::{self, TodayCourse},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};

pub const PORTAL_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/currentUser.do";
pub const TERMS_URL: &str =
    "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/schoolCalendars.do";
pub const WEEKS_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/getTermWeeks.do";
pub const COURSES_URL: &str =
    "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/getMyScheduleDetail.do";
pub const EXAMS_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/exams.do";
pub const TODAY_URL: &str =
    "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/teachingSchedule/detail.do";
const HOME_REFERER: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/index.html";
const EXAM_REFERER: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/home/index.html";
const AJAX_ACCEPT: &str = "application/json, text/javascript, */*; q=0.01";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Portal {
    Undergraduate,
    Graduate,
    /// BYXT returned HTML without the graduate path marker. The Apple client
    /// treats this as unconfirmed and tries GSMIS; do not report a bogus empty
    /// timetable.
    Unconfirmed,
}

/// Probe the shared session once and classify the portal (API.md §2.1).
pub async fn detect_portal<T: HttpTransport>(session: &Session<T>) -> Result<Portal, AppError> {
    let response = session
        .send_following_redirects(HttpRequest::get(PORTAL_URL))
        .await?;
    if is_login_response(&response) {
        return Err(AppError::session_expired());
    }
    if response.final_url.contains("/jwapp/sys/byrhmhsy/") {
        return Ok(Portal::Graduate);
    }
    let body = response.body.trim_start();
    if (200..300).contains(&response.status) && (body.starts_with('{') || body.starts_with('[')) {
        return Ok(Portal::Undergraduate);
    }
    if (200..300).contains(&response.status) {
        return Ok(Portal::Unconfirmed);
    }
    Err(AppError::new(ErrorCode::ServiceUnavailable))
}

pub async fn load_terms<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Term>, AppError> {
    let response = session
        .send_following_redirects(ajax_get(TERMS_URL, HOME_REFERER))
        .await?;
    let body = require_body(&response)?;
    schedule::parse_terms(body)
}

pub async fn load_weeks<T: HttpTransport>(
    session: &Session<T>,
    term_id: &str,
) -> Result<Vec<Week>, AppError> {
    if term_id.trim().is_empty() {
        return Err(AppError::invalid());
    }
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("termCode", term_id)
        .finish();
    let response = session
        .send_following_redirects(ajax_get(&format!("{WEEKS_URL}?{query}"), HOME_REFERER))
        .await?;
    let body = require_body(&response)?;
    schedule::parse_weeks(body)
}

pub async fn load_week_courses<T: HttpTransport>(
    session: &Session<T>,
    term_id: &str,
    week: i32,
) -> Result<Vec<CourseMeeting>, AppError> {
    if term_id.trim().is_empty() || !(1..=30).contains(&week) {
        return Err(AppError::invalid());
    }
    let body = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("termCode", term_id)
        .append_pair("type", "week")
        .append_pair("week", &week.to_string())
        .finish();
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(COURSES_URL, body)
                .header("Accept", AJAX_ACCEPT)
                .header("X-Requested-With", "XMLHttpRequest")
                .header("Referer", HOME_REFERER),
        )
        .await?;
    let body = require_body(&response)?;
    schedule::parse_undergraduate_courses(body)
}

pub async fn load_exams<T: HttpTransport>(
    session: &Session<T>,
    term_id: &str,
) -> Result<Vec<Exam>, AppError> {
    if term_id.trim().is_empty() {
        return Err(AppError::invalid());
    }
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("termCode", term_id)
        .finish();
    let response = session
        .send_following_redirects(ajax_get(&format!("{EXAMS_URL}?{query}"), EXAM_REFERER))
        .await?;
    if response.status == 403 {
        return Err(AppError::new(ErrorCode::UnsupportedPortal));
    }
    let body = require_body(&response)?;
    schedule::parse_exams(body)
}

pub async fn load_today<T: HttpTransport>(
    session: &Session<T>,
    date: &str,
) -> Result<Vec<TodayCourse>, AppError> {
    chrono::NaiveDate::parse_from_str(date, "%Y-%m-%d").map_err(|_| AppError::invalid())?;
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("rq", date)
        .append_pair("lxdm", "student")
        .finish();
    let response = session
        .send_following_redirects(ajax_get(&format!("{TODAY_URL}?{query}"), HOME_REFERER))
        .await?;
    let body = require_body(&response)?;
    today::parse_courses(body)
}

fn ajax_get(url: &str, referer: &str) -> HttpRequest {
    HttpRequest::get(url)
        .header("Accept", AJAX_ACCEPT)
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Referer", referer)
}

fn require_body(response: &HttpResponse) -> Result<serde_json::Value, AppError> {
    if is_login_response(response) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    if response.body.trim_start().starts_with('<') {
        return Err(AppError::changed());
    }
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}

fn is_login_response(response: &HttpResponse) -> bool {
    matches!(response.status, 401 | 403)
        || response.final_url.contains("sso.buaa.edu.cn")
        || response.body.contains("统一身份认证")
        || cas::is_login_redirect(&response.final_url, &response.body)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::foundation::http::HttpMethod;
    use crate::test_support::MockTransport;
    use serde_json::{json, Value};

    fn fixture(name: &str) -> Value {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../fixtures/schedule")
            .join(name);
        let fixture: Value =
            serde_json::from_str(&std::fs::read_to_string(path).expect("fixture")).expect("json");
        fixture["input"]["body"].clone()
    }

    #[tokio::test]
    async fn portal_probe_distinguishes_undergraduate_and_graduate() {
        let undergrad = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            PORTAL_URL,
            r#"{"code":"0"}"#,
        )]);
        assert_eq!(
            detect_portal(&Session::new(undergrad)).await.expect("ug"),
            Portal::Undergraduate
        );

        let graduate = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://byxt.buaa.edu.cn/jwapp/sys/byrhmhsy/index.html",
            "<html></html>",
        )]);
        assert_eq!(
            detect_portal(&Session::new(graduate)).await.expect("grad"),
            Portal::Graduate
        );
    }

    #[tokio::test]
    async fn portal_probe_reports_login_page() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login",
            r#"<input name="execution" value="x" />"#,
        )]);
        assert_eq!(
            detect_portal(&Session::new(transport))
                .await
                .expect_err("login")
                .code,
            ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn terms_use_documented_headers_and_parse() {
        let body = serde_json::to_string(&fixture("terms-normal-v1.json")).expect("json");
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(200, TERMS_URL, body)]);
        let session = Session::new(transport);
        let terms = load_terms(&session).await.expect("terms");
        assert_eq!(terms.len(), 2);
        assert!(terms[0].selected);

        let requests = session.transport().requests();
        assert_eq!(requests[0].url, TERMS_URL);
        assert_eq!(
            requests[0].header_value("X-Requested-With"),
            Some("XMLHttpRequest")
        );
        assert_eq!(requests[0].header_value("Referer"), Some(HOME_REFERER));
    }

    #[tokio::test]
    async fn week_courses_post_documented_form() {
        let body = serde_json::to_string(&fixture("courses-normal-v1.json")).expect("json");
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(200, COURSES_URL, body)]);
        let session = Session::new(transport);
        let courses = load_week_courses(&session, "2026-2027-1", 3)
            .await
            .expect("courses");
        assert_eq!(courses.len(), 2);
        assert_eq!(courses[0].name, "算法设计与分析");

        let requests = session.transport().requests();
        let request = &requests[0];
        assert_eq!(request.method, HttpMethod::Post);
        assert_eq!(
            request.body.as_deref(),
            Some("termCode=2026-2027-1&type=week&week=3")
        );
        assert_eq!(request.header_value("Referer"), Some(HOME_REFERER));
    }

    #[tokio::test]
    async fn exams_forbidden_is_typed_unsupported_portal() {
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(403, EXAMS_URL, "forbidden")]);
        assert_eq!(
            load_exams(&Session::new(transport), "2026-2027-1")
                .await
                .expect_err("exam")
                .code,
            ErrorCode::UnsupportedPortal
        );
    }

    #[tokio::test]
    async fn today_uses_documented_query_and_parses() {
        let body = serde_json::to_string(&fixture("today-normal-v1.json")).expect("json");
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(200, TODAY_URL, body)]);
        let session = Session::new(transport);
        let courses = load_today(&session, "2026-10-20").await.expect("today");
        assert_eq!(courses.len(), 2);
        assert_eq!(courses[0].name, "算法设计与分析");

        let requests = session.transport().requests();
        assert_eq!(
            requests[0].url,
            "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/teachingSchedule/detail.do?rq=2026-10-20&lxdm=student"
        );
        assert_eq!(requests[0].header_value("Referer"), Some(HOME_REFERER));
    }

    #[tokio::test]
    async fn html_login_page_instead_of_json_is_session_expired() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            TERMS_URL,
            r#"<html><title>统一身份认证</title></html>"#,
        )]);
        assert_eq!(
            load_terms(&Session::new(transport))
                .await
                .expect_err("login")
                .code,
            ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn portal_probe_follows_sso_service_redirect() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, PORTAL_URL, "").with_header(
                "Location",
                "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbyxt.buaa.edu.cn",
            ),
            HttpResponse::new(
                302,
                "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbyxt.buaa.edu.cn",
                "",
            )
            .with_header(
                "Location",
                "https://byxt.buaa.edu.cn/jwapp/sys/byrhmhsy/index.html",
            ),
            HttpResponse::new(
                200,
                "https://byxt.buaa.edu.cn/jwapp/sys/byrhmhsy/index.html",
                "<html></html>",
            )
            .with_set_cookie("JSESSIONID=grad; Path=/"),
        ]);
        let session = Session::new(transport.clone());
        assert_eq!(
            detect_portal(&session).await.expect("portal"),
            Portal::Graduate
        );
        assert_eq!(transport.request_count(), 3);
    }

    #[test]
    fn fixtures_are_synthetic() {
        let fixture: Value = serde_json::from_str(
            &std::fs::read_to_string(
                std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../../../fixtures/schedule/terms-normal-v1.json"),
            )
            .expect("fixture"),
        )
        .expect("json");
        assert_eq!(fixture["source"], json!("synthetic"));
    }
}
