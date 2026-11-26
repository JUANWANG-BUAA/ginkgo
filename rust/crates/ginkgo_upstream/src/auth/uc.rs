//! UC activation and session verification (API.md §1.7–§1.8).
use super::{cas, redirect, session::Session, UserProfile, UC_ACTIVATION_URL, UC_STATUS_URL};
use crate::{
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use serde::Deserialize;

pub async fn activate_uc<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {
    let mut url = UC_ACTIVATION_URL.to_string();
    for hop in 0..=10 {
        let response = session.send_auth(HttpRequest::get(&url)).await?;
        if (300..400).contains(&response.status) {
            if hop == 10 {
                return Err(AppError::new(ErrorCode::RedirectLimit));
            }
            if let Some(location) = response.header("location") {
                url = redirect::resolve_navigation_get(location, &url)?;
                continue;
            }
        }
        // UBAA does not use the landing page's status or HTML as identity
        // evidence. The caller must still validate the separate UC status.
        return Ok(());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

/// UC status is the only proof that the login chain produced a usable
/// session. 5xx responses are transient and must not clear local state.
pub async fn validate_session<T: HttpTransport>(
    session: &Session<T>,
) -> Result<UserProfile, AppError> {
    validate_response(session.send_auth(status_request()).await?)
}

pub(super) fn status_request() -> HttpRequest {
    HttpRequest::get(UC_STATUS_URL)
        .header(
            "Accept",
            "application/json, text/javascript, */*; q=0.01, application/json",
        )
        .header("X-Requested-With", "XMLHttpRequest")
}

pub(super) fn validate_response(response: HttpResponse) -> Result<UserProfile, AppError> {
    if response.status == 483
        || ((400..500).contains(&response.status) && cas::is_access_policy_denied(&response.body))
    {
        return Err(AppError::new(ErrorCode::AccessPolicyDenied));
    }
    if response.status != 200 {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    parse_uc_status(&response.body)
}

/// Parse the UC status body. Structure changes are errors, never an implicit
/// logout, so callers can keep local snapshots on upstream drift.
pub fn parse_uc_status(body: &str) -> Result<UserProfile, AppError> {
    if is_webvpn_xhr_login_required(body) {
        return Err(AppError::session_expired());
    }
    let status: UcStatus = serde_json::from_str(body).map_err(|_| AppError::changed())?;
    match status {
        UcStatus {
            code: 0,
            data: Some(user),
        } if !user.school_id.is_empty() && !user.name.is_empty() => Ok(UserProfile {
            school_id: user.school_id,
            name: user.name,
        }),
        UcStatus {
            code: 10600,
            data: None,
        } => Err(AppError::session_expired()),
        _ => Err(AppError::changed()),
    }
}

#[derive(Deserialize)]
struct WebVpnXhrLogin {
    success: bool,
    url: String,
}

/// WebVPN (`d.buaa.edu.cn`) answers unauthenticated XHR requests with HTTP 200
/// and `{"success": false, "url": "/login", ...}` instead of a 302 redirect.
/// Classify that exact gateway envelope as `SessionExpired` so automatic-route
/// probing surfaces `webvpn_route_login_required` rather than `ChangedResponse`.
fn is_webvpn_xhr_login_required(body: &str) -> bool {
    serde_json::from_str::<WebVpnXhrLogin>(body).is_ok_and(|envelope| {
        !envelope.success
            && (envelope.url.trim().trim_end_matches('/') == "/login"
                || url::Url::parse(envelope.url.trim()).is_ok_and(|url| {
                    url.host_str().is_some_and(|host| {
                        host.eq_ignore_ascii_case(crate::foundation::webvpn::GATEWAY_HOST)
                    }) && url.path().trim_end_matches('/').ends_with("/login")
                }))
    })
}

#[derive(Deserialize)]
struct UcStatus {
    code: i64,
    #[serde(deserialize_with = "Option::deserialize")]
    data: Option<UcUser>,
}

#[derive(Deserialize)]
struct UcUser {
    #[serde(rename = "schoolid")]
    school_id: String,
    name: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn webvpn_xhr_login_envelope_is_session_expired_not_schema_drift() {
        for body in [
            r#"{"message":"您的会话已经过期，请重新登录","success":false,"url":"/login"}"#,
            r#"{"success":false,"url":"https://d.buaa.edu.cn/login"}"#,
        ] {
            assert_eq!(
                parse_uc_status(body).expect_err("gateway login").code,
                ErrorCode::SessionExpired
            );
        }
        for body in [
            r#"{"success":true,"url":"/login"}"#,
            r#"{"success":false,"url":"/other"}"#,
            r#"{"success":false,"url":"https://evil.example/login"}"#,
            r#"{"code":1,"data":null}"#,
            "<html><title>统一身份认证</title></html>",
        ] {
            assert_eq!(
                parse_uc_status(body).expect_err("schema drift").code,
                ErrorCode::ChangedResponse
            );
        }
    }
}
