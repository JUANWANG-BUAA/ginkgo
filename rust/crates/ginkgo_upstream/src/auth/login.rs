//! Login-page fetch and manual redirect chain (API.md §1.2–§1.6).
use super::{cas, redirect, session::Session, LoginPage, LOGIN_URL};
use crate::{
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};

/// Fetch the CAS login page without automatic redirects.
pub async fn fetch_login_page<T: HttpTransport>(
    session: &Session<T>,
) -> Result<LoginPage, AppError> {
    fetch_login_page_with_execution(session, None).await
}

pub(super) async fn fetch_login_page_with_execution<T: HttpTransport>(
    session: &Session<T>,
    supplied_execution: Option<&str>,
) -> Result<LoginPage, AppError> {
    let response = session.send_auth(HttpRequest::get(LOGIN_URL)).await?;
    if (300..400).contains(&response.status) {
        return Ok(LoginPage::ExistingSession);
    }
    if response.status != 200 {
        return Err(status_error(&response));
    }
    if let Some(tip) = cas::extract_tip_text(&response.body) {
        return Err(AppError::with_detail(ErrorCode::PreLoginTip, tip));
    }
    let execution = supplied_execution
        .filter(|value| !value.trim().is_empty())
        .map(str::to_owned)
        .or_else(|| cas::extract_execution(&response.body))
        .unwrap_or_default();
    let captcha = cas::detect_captcha(&response.body);
    Ok(LoginPage::Form {
        execution,
        captcha,
        action_url: LOGIN_URL.to_owned(),
        html: response.body,
    })
}

/// Consume the submitted CAS chain before UC activation. Match UBAA's order:
/// redirects, one expiry acknowledgement, then final login-error detection.
pub(crate) async fn follow_redirects_and_check_error<T: HttpTransport>(
    session: &Session<T>,
    mut response: HttpResponse,
    mut current_url: String,
) -> Result<(), AppError> {
    let mut skipped_expiry = false;
    for hop in 0..=10 {
        if (300..400).contains(&response.status) {
            if let Some(location) = response.header("location") {
                if hop == 10 {
                    return Err(AppError::new(ErrorCode::RedirectLimit));
                }
                let target = redirect::resolve_navigation_get(location, &current_url)?;
                response = session.send_auth(HttpRequest::get(&target)).await?;
                current_url = target;
                continue;
            }
        }
        if cas::is_password_expiry_page(&response.body) {
            if skipped_expiry {
                return Err(AppError::session_expired());
            }
            skipped_expiry = true;
            let execution = cas::extract_execution(&response.body).ok_or_else(AppError::changed)?;
            // Match UBAA's stripQuery(currentResponse.call.request.url), not
            // a form action or a query inherited from an earlier login page.
            let mut target = url::Url::parse(&current_url).map_err(|_| AppError::changed())?;
            target.set_query(None);
            target.set_fragment(None);
            let action_url = target.to_string();
            // This request carries a new execution token, even though it must
            // never carry the password. Keep the same CAS target validation.
            validate_login_action(&action_url)?;
            let body = cas::form_urlencode(&[
                ("execution".into(), execution),
                ("_eventId".into(), "ignoreAndContinue".into()),
            ]);
            response = session
                .send(
                    HttpRequest::post_form(action_url.clone(), body)
                        .header("Accept", "application/json")
                        .header(
                            "Content-Type",
                            "application/x-www-form-urlencoded; charset=UTF-8",
                        ),
                )
                .await?;
            current_url = action_url;
            continue;
        }
        redirect::reject_reported_error(&current_url)?;
        if response.status == 401 || cas::extract_error_text(&response.body).is_some() {
            return Err(login_page_error(&response.body));
        }
        if response.body.contains("input name=\"execution\"") {
            return Err(login_page_error(&response.body));
        }
        return Ok(());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

/// A normal login form can reappear for several reasons. Its presence alone
/// does not establish that the school rejected the password.
fn login_page_error(html: &str) -> AppError {
    match cas::extract_error_text(html) {
        Some(message) if cas::is_access_policy_denied(&message) => {
            AppError::with_detail(ErrorCode::AccessPolicyDenied, message)
        }
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

/// Password-expiry execution tokens may only return to CAS over HTTPS on the
/// default port without embedded credentials. Passwords use fixed LOGIN_URL.
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
