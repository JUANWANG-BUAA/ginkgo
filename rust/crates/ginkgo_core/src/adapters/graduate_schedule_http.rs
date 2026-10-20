//! GSMIS graduate schedule requests (API.md §3).
use crate::{
    auth::{cas, session::Session},
    features::schedule::{self, CourseMeeting, Term, Week},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use serde_json::Value;
use std::collections::BTreeMap;

pub const ENTRY_URL: &str = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/*default/index.do";
pub const TERMS_URL: &str =
    "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do";
pub const SCHEDULE_URL: &str = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/bykb/loadXskbData.do";
const AJAX_ACCEPT: &str = "application/json, text/javascript, */*; q=0.01";

pub struct GraduateSchedule {
    pub weeks: Vec<Week>,
    pub courses_by_week: BTreeMap<i32, Vec<CourseMeeting>>,
}

/// GSMIS activates its own SSO session by visiting the SPA entry. The BYXT
/// current-user probe may already have done this; repeating it is harmless.
pub async fn activate<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {
    let response = session
        .send_following_redirects(HttpRequest::get(ENTRY_URL))
        .await?;
    if is_login_response(&response) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::unavailable());
    }
    Ok(())
}

pub async fn load_terms<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Term>, AppError> {
    activate(session).await?;
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(TERMS_URL, String::new())
                .header("Accept", AJAX_ACCEPT)
                .header("X-Requested-With", "XMLHttpRequest")
                .header("Referer", ENTRY_URL),
        )
        .await?;
    let body = require_body(&response)?;
    schedule::parse_graduate_terms(body)
}

pub async fn load_schedule<T: HttpTransport>(
    session: &Session<T>,
    term_id: &str,
) -> Result<GraduateSchedule, AppError> {
    if term_id.trim().is_empty() {
        return Err(AppError::invalid());
    }
    let body = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("ZC", "")
        .append_pair("XNXQDM", term_id)
        .append_pair("XH", "")
        .append_pair("XQDM", "")
        .finish();
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(SCHEDULE_URL, body)
                .header("Accept", AJAX_ACCEPT)
                .header("X-Requested-With", "XMLHttpRequest")
                .header("Referer", ENTRY_URL),
        )
        .await?;
    let value = require_body(&response)?;
    let weeks = schedule::parse_graduate_weeks(value.clone(), term_id)
        .map_err(|error| AppError::with_detail(error.code, "graduate_weeks"))?;
    let mut courses_by_week = BTreeMap::new();
    for week in &weeks {
        courses_by_week.insert(
            week.number,
            schedule::parse_graduate_courses(value.clone(), term_id, week.number)
                .map_err(|error| AppError::with_detail(error.code, "graduate_courses"))?,
        );
    }
    Ok(GraduateSchedule {
        weeks,
        courses_by_week,
    })
}

fn require_body(response: &HttpResponse) -> Result<Value, AppError> {
    if is_login_response(response) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::with_detail(
            ErrorCode::ServiceUnavailable,
            format!("gsmis status={}", response.status),
        ));
    }
    if response.body.trim_start().starts_with('<') {
        return Err(AppError::with_detail(
            ErrorCode::ChangedResponse,
            format!(
                "gsmis html status={} url={}",
                response.status,
                safe_url(&response.final_url)
            ),
        ));
    }
    serde_json::from_str(&response.body).map_err(|_| {
        AppError::with_detail(
            ErrorCode::ChangedResponse,
            format!(
                "gsmis json status={} len={}",
                response.status,
                response.body.len()
            ),
        )
    })
}

fn safe_url(raw: &str) -> String {
    url::Url::parse(raw)
        .map(|mut url| {
            url.set_query(None);
            url.set_fragment(None);
            url.to_string()
        })
        .unwrap_or_default()
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
    use crate::{foundation::http::HttpMethod, test_support::MockTransport};
    use serde_json::Value;

    fn fixture(name: &str) -> Value {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../fixtures/schedule")
            .join(name);
        let fixture: Value =
            serde_json::from_str(&std::fs::read_to_string(path).expect("fixture")).expect("json");
        fixture["input"]["body"].clone()
    }

    #[tokio::test]
    async fn activates_terms_and_schedule_with_documented_forms() {
        let terms = fixture("graduate-terms-v1.json").to_string();
        let schedule = fixture("graduate-schedule-v1.json").to_string();
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, ENTRY_URL, "<html>app</html>"),
            HttpResponse::new(200, TERMS_URL, terms),
            HttpResponse::new(200, SCHEDULE_URL, schedule),
        ]);
        let session = Session::new(transport);
        let terms = load_terms(&session).await.expect("terms");
        assert_eq!(terms[0].id, "20261");
        let schedule = load_schedule(&session, "20261").await.expect("schedule");
        assert_eq!(schedule.weeks.len(), 30);
        assert_eq!(schedule.courses_by_week[&7].len(), 2);

        let requests = session.transport().requests();
        assert_eq!(requests[0].url, ENTRY_URL);
        assert_eq!(requests[1].method, HttpMethod::Post);
        assert_eq!(requests[1].body.as_deref(), Some(""));
        assert_eq!(
            requests[2].body.as_deref(),
            Some("ZC=&XNXQDM=20261&XH=&XQDM=")
        );
        assert_eq!(requests[2].header_value("Referer"), Some(ENTRY_URL));
    }

    #[tokio::test]
    async fn login_page_during_activation_is_a_session_error() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login",
            "<html><title>CAS Login</title></html>",
        )]);
        assert_eq!(
            load_terms(&Session::new(transport))
                .await
                .expect_err("login")
                .code,
            ErrorCode::SessionExpired
        );
    }
}
