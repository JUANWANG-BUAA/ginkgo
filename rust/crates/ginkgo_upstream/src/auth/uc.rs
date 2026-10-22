//! UC activation and session verification (API.md §1.7–§1.8).
use super::{cas, redirect, session::Session, UserProfile, UC_ACTIVATION_URL, UC_STATUS_URL};
use crate::{
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
use serde::Deserialize;

pub async fn activate_uc<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {
    let mut url = UC_ACTIVATION_URL.to_string();
    for hop in 0..=10 {
        let response = session.send_with_fallback(HttpRequest::get(&url)).await?;
        if (300..400).contains(&response.status) {
            if hop == 10 {
                return Err(AppError::new(ErrorCode::RedirectLimit));
            }
            let location = response.header("location").ok_or_else(AppError::changed)?;
            url = redirect::resolve_get(location, &url)?;
            continue;
        }
        if response.status == 483 || cas::is_access_policy_denied(&response.body) {
            return Err(AppError::new(ErrorCode::AccessPolicyDenied));
        }
        if response.status != 200 {
            return Err(AppError::new(ErrorCode::ServiceUnavailable));
        }
        return Ok(());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

/// UC status is the only proof that the login chain produced a usable
/// session. 5xx responses are transient and must not clear local state.
pub async fn validate_session<T: HttpTransport>(
    session: &Session<T>,
) -> Result<UserProfile, AppError> {
    let request = HttpRequest::get(UC_STATUS_URL)
        .header("Accept", "application/json, text/javascript, */*; q=0.01")
        .header("X-Requested-With", "XMLHttpRequest");
    let response = session.send_with_fallback(request).await?;
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
    let status: UcStatus = serde_json::from_str(body).map_err(|_| AppError::changed())?;
    match status {
        UcStatus {
            code: 0,
            data: Some(user),
        } if !user.school_id.is_empty() && !user.name.is_empty() => Ok(UserProfile {
            school_id: user.school_id,
            name: user.name,
        }),
        _ => Err(AppError::session_expired()),
    }
}

#[derive(Deserialize)]
struct UcStatus {
    code: i64,
    data: Option<UcUser>,
}

#[derive(Deserialize)]
struct UcUser {
    #[serde(rename = "schoolid")]
    school_id: String,
    name: String,
}
