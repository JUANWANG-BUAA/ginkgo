//! iclass read-only HTTP flow (API.md §7.2).
//!
//! Request sequencing, auth-page classification and parse hand-off only; the
//! domain rules live in codecs::checkin. The app session stays in memory and
//! never crosses the bridge.
use crate::{
    auth::{cas, redirect, session::Session},
    codecs::checkin::{self, CheckInCourse, IClassSession},
    foundation::{
        http::{HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError, ErrorCode,
};

pub const ENTRY_URL: &str = "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter";
pub const APP_LOGIN_URL: &str = "https://iclass.buaa.edu.cn:8347/app/user/login.action";
pub const COURSE_SCHEDULE_URL: &str =
    "https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action";

/// Follow the SSO entry manually (at most eight hops) and return only the
/// loginName query value. The value is never logged.
pub async fn resolve_login_name<T: HttpTransport>(
    session: &Session<T>,
) -> Result<String, AppError> {
    let mut url = ENTRY_URL.to_string();
    for hop in 0..8 {
        if let Some(login_name) = checkin::login_name_from_url(&url) {
            return Ok(login_name);
        }
        let response = session.send_with_fallback(HttpRequest::get(&url)).await?;
        if let Some(login_name) = checkin::login_name_from_url(&response.final_url) {
            return Ok(login_name);
        }
        if response.status == 401 {
            return Err(AppError::session_expired());
        }
        if is_gateway_login(&response) {
            return Err(AppError::with_detail(
                ErrorCode::AccessPolicyDenied,
                "webvpn_login_required",
            ));
        }
        if (300..400).contains(&response.status) {
            let Some(location) = response.header("location") else {
                return Err(AppError::changed());
            };
            let next = redirect::resolve_get(location, &response.final_url)?;
            if hop == 7 {
                return Err(AppError::new(ErrorCode::RedirectLimit));
            }
            url = next;
            continue;
        }
        if response.status != 200 {
            return Err(AppError::unavailable());
        }
        if cas::is_login_redirect(&response.final_url, &response.body) {
            return Err(AppError::session_expired());
        }
        // A 200 page without loginName means iclass is not handing out the
        // documented jump parameter any more.
        return Err(AppError::changed());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

pub async fn app_login<T: HttpTransport>(
    session: &Session<T>,
    login_name: &str,
) -> Result<IClassSession, AppError> {
    let request = HttpRequest::get(app_login_url(login_name)?)
        .header("Accept", "application/json, text/plain, */*");
    let response = session.send_with_fallback(request).await?;
    classify_json(&response)?;
    let value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    checkin::parse_app_login(&value)
}

pub async fn course_schedule<T: HttpTransport>(
    session: &Session<T>,
    iclass: &IClassSession,
    date: &str,
) -> Result<Vec<CheckInCourse>, AppError> {
    if date.len() != 8 || !date.chars().all(|ch| ch.is_ascii_digit()) {
        return Err(AppError::invalid());
    }
    let mut url = url::Url::parse(COURSE_SCHEDULE_URL).map_err(|_| AppError::invalid())?;
    url.query_pairs_mut()
        .append_pair("id", &iclass.user_id)
        .append_pair("dateStr", date);
    let request = HttpRequest::get(url.to_string())
        .header("sessionId", &iclass.session_id)
        .header("Accept", "application/json, text/plain, */*");
    let response = session.send_with_fallback(request).await?;
    classify_json(&response)?;
    let value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    checkin::parse_course_schedule(&value)
}

fn app_login_url(login_name: &str) -> Result<String, AppError> {
    if login_name.trim().is_empty() {
        return Err(AppError::invalid());
    }
    let mut url = url::Url::parse(APP_LOGIN_URL).map_err(|_| AppError::invalid())?;
    url.query_pairs_mut()
        .append_pair("password", "")
        .append_pair("phone", login_name)
        .append_pair("userLevel", "1")
        .append_pair("verificationType", "2")
        .append_pair("verificationUrl", "");
    Ok(url.to_string())
}

/// Shared HTTP classification for the two JSON endpoints. Structure problems
/// stay ChangedResponse; a school login page means the school session expired.
fn classify_json(response: &HttpResponse) -> Result<(), AppError> {
    if response.status == 401 || cas::is_login_redirect(&response.final_url, &response.body) {
        return Err(AppError::session_expired());
    }
    if is_gateway_login(response) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::unavailable());
    }
    if response.body.trim_start().starts_with('<') {
        return Err(AppError::changed());
    }
    Ok(())
}

fn is_gateway_login(response: &HttpResponse) -> bool {
    url::Url::parse(&response.final_url).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|host| host.eq_ignore_ascii_case(webvpn::GATEWAY_HOST))
            && url.path().trim_end_matches('/').ends_with("/login")
    })
}

/// CheckInClient.performSignIn / API.md §7.2. Timestamp is a safe read;
/// the final POST deliberately uses send, without fallback, redirect or retry.
pub async fn sign_in<T: HttpTransport>(
    session: &Session<T>,
    iclass: &IClassSession,
    course_id: &str,
) -> crate::codecs::mutation::MutationOutcome {
    use crate::codecs::mutation::MutationOutcome as Outcome;
    const TIMESTAMP: &str = "https://iclass.buaa.edu.cn:8347/app/common/get_timestamp.action";
    let timestamp = async {
        let response = session
            .send_with_fallback(HttpRequest::get(TIMESTAMP))
            .await?;
        classify_json(&response)?;
        let value: serde_json::Value =
            serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
        match &value["timestamp"] {
            serde_json::Value::String(s) if !s.trim().is_empty() => Ok(s.trim().to_owned()),
            serde_json::Value::Number(n) => Ok(n.to_string()),
            _ => Err(AppError::changed()),
        }
    }
    .await;
    let Ok(timestamp) = timestamp else {
        return Outcome::not_submitted("无法取得学校时间，未提交签到");
    };
    let Ok(mut url) =
        url::Url::parse("https://iclass.buaa.edu.cn:8347/app/course/stu_scan_sign.action")
    else {
        return Outcome::not_submitted("签到地址无效");
    };
    url.query_pairs_mut()
        .append_pair("courseSchedId", course_id)
        .append_pair("timestamp", &timestamp);
    let body = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("id", &iclass.user_id)
        .finish();
    let response = session
        .send(HttpRequest::post_form(url.to_string(), body).header("sessionId", &iclass.session_id))
        .await;
    let Ok(response) = response else {
        return Outcome::uncertain();
    };
    if response.status != 200 || classify_json(&response).is_err() {
        return Outcome::uncertain();
    }
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&response.body) else {
        return Outcome::uncertain();
    };
    checkin::parse_sign_in(&value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        foundation::http::{HttpMethod, TransportError},
        test_support::MockTransport,
    };
    use serde_json::json;

    fn day_body() -> String {
        json!({
            "STATUS": "0",
            "total": 1,
            "result": [{
                "id": "501",
                "courseName": "高等数学",
                "classBeginTime": "08:00",
                "classEndTime": "09:35",
                "signStatus": "0",
                "teacherName": "张老师",
                "classroomName": "主楼A101"
            }]
        })
        .to_string()
    }

    #[tokio::test]
    async fn follows_the_entry_redirects_and_returns_the_login_name() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(302, ENTRY_URL, "")
            .with_header("Location", "/?loginName=fixture-name")]);
        let session = Session::new(transport.clone());
        assert_eq!(
            resolve_login_name(&session).await.expect("login name"),
            "fixture-name"
        );
        // The loginName already appears in the resolved Location, so the
        // adapter stops before a redundant request (Apple does the same).
        let requests = transport.requests();
        assert_eq!(requests.len(), 1);
        assert_eq!(requests[0].method, HttpMethod::Get);
        assert_eq!(requests[0].url, ENTRY_URL);
    }

    #[tokio::test]
    async fn direct_transport_failure_switches_to_webvpn_and_keeps_going() {
        let entry_wrapped = webvpn::wrap(ENTRY_URL).expect("entry");
        let landed_upstream = "https://iclass.buaa.edu.cn:8346/?loginName=fixture-name#/MyCenter";
        let landed_wrapped = webvpn::wrap(landed_upstream).expect("landed");
        let step_upstream = "https://iclass.buaa.edu.cn:8346/?step=2";
        let step_wrapped = webvpn::wrap(step_upstream).expect("step");
        let step_relative = step_wrapped
            .strip_prefix("https://d.buaa.edu.cn")
            .expect("gateway prefix")
            .to_string();
        let transport = MockTransport::with_results(vec![
            Err(TransportError::Unavailable),
            Ok(HttpResponse::new(302, &entry_wrapped, "").with_header("Location", &step_relative)),
            Ok(HttpResponse::new(200, &landed_wrapped, "<html></html>")),
        ]);
        let session = Session::new(transport.clone());
        assert_eq!(
            resolve_login_name(&session)
                .await
                .expect("fallback login name"),
            "fixture-name"
        );
        let requests = transport.requests();
        assert_eq!(requests[0].url, ENTRY_URL);
        assert_eq!(requests[1].url, entry_wrapped);
        assert_eq!(requests[2].url, step_wrapped);
        assert_eq!(session.route(), crate::auth::session::RouteMode::WebVpn);
    }

    #[tokio::test]
    async fn gateway_login_page_is_reported_as_webvpn_login_required() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://d.buaa.edu.cn/login",
            "<html>gateway</html>",
        )]);
        let session = Session::new(transport);
        session.set_route(crate::auth::session::RouteMode::WebVpn);
        let error = resolve_login_name(&session).await.expect_err("gateway");
        assert_eq!(error.code, ErrorCode::AccessPolicyDenied);
        assert_eq!(error.detail.as_deref(), Some("webvpn_login_required"));
    }

    #[tokio::test]
    async fn cas_login_page_is_a_session_expiry() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login",
            r#"<input name="execution" value="fixture" />"#,
        )]);
        let session = Session::new(transport);
        assert_eq!(
            resolve_login_name(&session)
                .await
                .expect_err("login page")
                .code,
            ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn app_login_sends_documented_query_and_parses_the_session() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            APP_LOGIN_URL,
            json!({"STATUS": 0, "result": {"id": "1001", "sessionId": "fixture-session"}})
                .to_string(),
        )]);
        let session = Session::new(transport.clone());
        let iclass = app_login(&session, "name+fixture")
            .await
            .expect("app login");
        assert_eq!(iclass.user_id, "1001");
        assert_eq!(iclass.session_id, "fixture-session");
        let url = &transport.requests()[0].url;
        assert!(url.contains("phone=name%2Bfixture"), "url: {url}");
        assert!(url.contains("password="));
        assert!(url.contains("userLevel=1"));
        assert!(url.contains("verificationType=2"));
        assert!(url.contains("verificationUrl="));
    }

    #[tokio::test]
    async fn day_query_uses_the_session_header_and_parses_courses() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            COURSE_SCHEDULE_URL,
            day_body(),
        )]);
        let session = Session::new(transport.clone());
        let iclass = IClassSession {
            user_id: "1001".into(),
            session_id: "fixture-session".into(),
        };
        let courses = course_schedule(&session, &iclass, "20261020")
            .await
            .expect("courses");
        assert_eq!(courses.len(), 1);
        assert_eq!(courses[0].course_name, "高等数学");
        let request = &transport.requests()[0];
        assert_eq!(request.header_value("sessionId"), Some("fixture-session"));
        assert!(request.url.contains("id=1001"));
        assert!(request.url.contains("dateStr=20261020"));
    }

    #[tokio::test]
    async fn business_rejection_and_bad_date_are_distinct() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            COURSE_SCHEDULE_URL,
            json!({"STATUS": 9}).to_string(),
        )]);
        let session = Session::new(transport.clone());
        let iclass = IClassSession {
            user_id: "1001".into(),
            session_id: "fixture".into(),
        };
        assert_eq!(
            course_schedule(&session, &iclass, "20261020")
                .await
                .expect_err("rejected")
                .code,
            ErrorCode::BusinessRejected
        );
        assert_eq!(
            course_schedule(&session, &iclass, "2026-10-20")
                .await
                .expect_err("bad date")
                .code,
            ErrorCode::InvalidRequest
        );
        assert_eq!(transport.request_count(), 1);
    }

    #[tokio::test]
    async fn empty_day_status_two_is_a_valid_empty_list() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            COURSE_SCHEDULE_URL,
            json!({"STATUS": 2, "total": 0, "result": []}).to_string(),
        )]);
        let session = Session::new(transport);
        let iclass = IClassSession {
            user_id: "1001".into(),
            session_id: "fixture".into(),
        };
        assert!(course_schedule(&session, &iclass, "20261020")
            .await
            .expect("empty")
            .is_empty());
    }
}
