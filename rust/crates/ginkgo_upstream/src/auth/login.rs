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
        let response = session.send_auth(HttpRequest::get(&url)).await?;
        if response.status == 401 {
            return Err(status_error(&response));
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
        validate_login_action(&action_url)?;
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
/// next one. HTTP 401 does not alone prove a wrong password. Credential
/// submissions need user attention; navigation failures remain service errors.
/// Password-expiry pages are skipped exactly once.
pub(crate) async fn follow_redirects_and_check_error<T: HttpTransport>(
    session: &Session<T>,
    mut response: HttpResponse,
    mut current_url: String,
    mut credential_response: bool,
) -> Result<Option<LoginPage>, AppError> {
    let mut skipped_expiry = false;
    for hop in 0..=10 {
        redirect::reject_reported_error(&current_url)?;
        if response.status == 401 {
            return Err(if cas::is_access_policy_denied(&response.body) {
                AppError::new(ErrorCode::AccessPolicyDenied)
            } else if credential_response {
                if cas::extract_error_text(&response.body).is_some() {
                    login_page_error(&response.body)
                } else {
                    AppError::with_detail(
                        ErrorCode::PreLoginTip,
                        "认证提交未完成，学校未提供明确原因。请核对验证码或在学校登录页确认状态。",
                    )
                }
            } else {
                status_error(&response)
            });
        }
        if (300..400).contains(&response.status) {
            if hop == 10 {
                return Err(AppError::new(ErrorCode::RedirectLimit));
            }
            let location = response.header("location").ok_or_else(AppError::changed)?;
            let target = redirect::resolve_get(location, &current_url)?;
            // A ticket for a target service means the school already accepted
            // the login. Following that service leaves CAS, fails on a network
            // that cannot reach it, reroutes through the gateway and comes back
            // to CAS unauthenticated — which is where the captcha comes from.
            if !is_login_page_target(&target) {
                return Ok(None);
            }
            credential_response = false;
            response = session.send_auth(HttpRequest::get(&target)).await?;
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
            let action_url = match cas::extract_login_form_action(&response.body) {
                Some(action) if !action.is_empty() => {
                    webvpn::resolve_redirect(&action, &current_url).ok_or_else(AppError::changed)?
                }
                _ => current_url.clone(),
            };
            // This request carries a new execution token, even though it must
            // never carry the password. Keep the same CAS target validation.
            validate_login_action(&action_url)?;
            let body = cas::form_urlencode(&[
                ("execution".into(), execution),
                ("_eventId".into(), "ignoreAndContinue".into()),
            ]);
            credential_response = false;
            response = session
                .send(HttpRequest::post_form(action_url.clone(), body))
                .await?;
            current_url = action_url;
            continue;
        }
        if let Some(execution) = cas::extract_execution(&response.body) {
            // The school re-renders this page when it wants a captcha. Treating
            // it as a wrong password hides the only path the user has.
            if let Some(challenge) = cas::detect_captcha(&response.body) {
                let action_url = cas::extract_login_form_action(&response.body)
                    .and_then(|action| webvpn::resolve_redirect(&action, &current_url))
                    .unwrap_or_else(|| current_url.clone());
                return Ok(Some(LoginPage::Form {
                    execution,
                    captcha: Some(challenge),
                    action_url,
                    html: response.body,
                }));
            }
            return Err(login_page_error(&response.body));
        }
        // A tip with no answerable page is a dead end; report it after the
        // captcha branch so a wrong answer can be retried instead of ending
        // the sign-in.
        if let Some(message) = cas::extract_error_text(&response.body) {
            return Err(AppError::with_detail(ErrorCode::PreLoginTip, message));
        }
        return Ok(None);
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

/// A normal login form can reappear for several reasons. Its presence alone
/// does not establish that the school rejected the password.
fn login_page_error(html: &str) -> AppError {
    match cas::extract_error_text(html) {
        Some(message) if matches!(message.as_str(), "账号或密码错误" | "用户名或密码错误") => {
            AppError::new(ErrorCode::InvalidCredentials)
        }
        Some(message) => AppError::with_detail(ErrorCode::PreLoginTip, message),
        None => AppError::with_detail(
            ErrorCode::PreLoginTip,
            "认证未完成：学校重新显示登录页，未提供明确原因。请核对验证码或在学校登录页确认状态。",
        ),
    }
}

/// The password POST target must be the documented CAS endpoint over HTTPS on
/// the default port without embedded credentials. A drifted or hostile form
/// action fails here, before the credential body leaves the device.
pub(crate) fn validate_login_action(action: &str) -> Result<(), AppError> {
    let parsed = url::Url::parse(action).map_err(|_| AppError::changed())?;
    let host_ok = parsed
        .host_str()
        .is_some_and(|host| host.eq_ignore_ascii_case("sso.buaa.edu.cn"));
    if parsed.scheme() != "https"
        || !host_ok
        || parsed.port().is_some_and(|port| port != 443)
        || !parsed.username().is_empty()
        || parsed.password().is_some()
    {
        return Err(AppError::changed());
    }
    Ok(())
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
