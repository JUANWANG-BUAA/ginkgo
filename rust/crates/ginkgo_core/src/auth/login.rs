//! Login-page fetch and manual redirect chain (API.md §1.2–§1.6).
use super::{cas, redirect, session::Session, LoginPage, LOGIN_URL};
use crate::{
    foundation::{
        http::{HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError, ErrorCode,
};

/// Fetch the CAS login page without automatic redirects.
pub async fn fetch_login_page<T: HttpTransport>(
    session: &Session<T>,
) -> Result<LoginPage, AppError> {
    let mut url = LOGIN_URL.to_string();
    for hop in 0..=8 {
        let response = session.send_with_fallback(HttpRequest::get(&url)).await?;
        if response.status == 401 {
            return Err(AppError::new(ErrorCode::InvalidCredentials));
        }
        if response.status == 483 {
            return Err(AppError::new(ErrorCode::AccessPolicyDenied));
        }
        if (300..400).contains(&response.status) {
            if hop == 8 {
                return Err(AppError::new(ErrorCode::RedirectLimit));
            }
            let location = response.header("location").ok_or_else(AppError::changed)?;
            let target = redirect::resolve_get(location, &url)?;
            if is_login_page_target(&target) {
                url = target;
                continue;
            }
            return Ok(LoginPage::ExistingSession { location: target });
        }
        if response.status != 200 {
            return Err(status_error(&response));
        }
        if let Some(tip) = cas::extract_tip_text(&response.body) {
            return Err(AppError::with_detail(ErrorCode::PreLoginTip, tip));
        }
        let execution = cas::extract_execution(&response.body).ok_or_else(AppError::changed)?;
        let captcha = cas::detect_captcha(&response.body);
        let action_url = cas::extract_login_form_action(&response.body)
            .and_then(|action| webvpn::resolve_redirect(&action, &url))
            .unwrap_or_else(|| url.clone());
        return Ok(LoginPage::Form {
            execution,
            captcha,
            action_url,
            html: response.body,
        });
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

/// Follow up to ten redirects, classifying each hop before requesting the
/// next one. Password-expiry pages are skipped exactly once.
pub(crate) async fn follow_redirects_and_check_error<T: HttpTransport>(
    session: &Session<T>,
    mut response: HttpResponse,
    mut current_url: String,
) -> Result<(), AppError> {
    let mut skipped_expiry = false;
    for hop in 0..=10 {
        if let Some(message) = query_param(&current_url, "exception.message") {
            if !message.is_empty() {
                return Err(AppError::with_detail(ErrorCode::PreLoginTip, message));
            }
        }
        if response.status == 401 {
            return Err(AppError::new(ErrorCode::InvalidCredentials));
        }
        if (300..400).contains(&response.status) {
            if hop == 10 {
                return Err(AppError::new(ErrorCode::RedirectLimit));
            }
            let location = response.header("location").ok_or_else(AppError::changed)?;
            let target = redirect::resolve_get(location, &current_url)?;
            response = session
                .send_with_fallback(HttpRequest::get(&target))
                .await?;
            current_url = target;
            continue;
        }
        if response.status == 483 {
            return Err(AppError::new(ErrorCode::AccessPolicyDenied));
        }
        if (400..500).contains(&response.status) {
            if cas::is_access_policy_denied(&response.body) {
                return Err(AppError::new(ErrorCode::AccessPolicyDenied));
            }
            if let Some(message) = cas::extract_error_text(&response.body) {
                return Err(AppError::with_detail(ErrorCode::PreLoginTip, message));
            }
            return Err(AppError::new(ErrorCode::ServiceUnavailable));
        }
        if (500..600).contains(&response.status) {
            return Err(AppError::new(ErrorCode::ServiceUnavailable));
        }
        if response.status != 200 {
            return Err(AppError::new(ErrorCode::ServiceUnavailable));
        }
        if cas::is_password_expiry_page(&response.body) {
            if skipped_expiry {
                return Err(AppError::session_expired());
            }
            skipped_expiry = true;
            let execution = cas::extract_execution(&response.body).ok_or_else(AppError::changed)?;
            let body = cas::form_urlencode(&[
                ("execution".into(), execution),
                ("_eventId".into(), "ignoreAndContinue".into()),
            ]);
            response = session
                .send(HttpRequest::post_form(LOGIN_URL, body))
                .await?;
            current_url = LOGIN_URL.to_string();
            continue;
        }
        if let Some(message) = cas::extract_error_text(&response.body) {
            return Err(AppError::with_detail(ErrorCode::PreLoginTip, message));
        }
        if cas::extract_execution(&response.body).is_some() {
            return Err(AppError::new(ErrorCode::InvalidCredentials));
        }
        return Ok(());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

fn status_error(response: &HttpResponse) -> AppError {
    if response.status == 483 || cas::is_access_policy_denied(&response.body) {
        return AppError::new(ErrorCode::AccessPolicyDenied);
    }
    AppError::new(ErrorCode::ServiceUnavailable)
}

fn is_login_page_target(url: &str) -> bool {
    let Ok(url) = url::Url::parse(url) else {
        return false;
    };
    let host = url.host_str().unwrap_or_default().to_ascii_lowercase();
    let login_path = url.path().trim_end_matches('/').ends_with("/login");
    if host == webvpn::GATEWAY_HOST {
        return login_path;
    }
    host == "sso.buaa.edu.cn" && login_path
}

fn query_param(url: &str, name: &str) -> Option<String> {
    url::Url::parse(url)
        .ok()?
        .query_pairs()
        .find(|(key, _)| key == name)
        .map(|(_, value)| value.into_owned())
}
