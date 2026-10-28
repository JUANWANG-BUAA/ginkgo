use crate::{
    auth::session::Session,
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use serde_json::Value;

pub const ENTRY_URL: &str = "https://pass.cc-pay.cn/login?backUrl=https%3A%2F%2Fpass.cc-pay.cn%2Fdashboard%3Flinkfrom%3Dpass&channel=BUAASSO";
pub const USER_URL: &str = "https://pass.cc-pay.cn/api/user";
pub const CARDS_URL: &str = "https://pass.cc-pay.cn/api/campus_cards";
pub const BALANCE_URL: &str = "https://pass.cc-pay.cn/api/campus_card/balance";
const LIMIT: usize = 64 * 1024;

fn trusted(url: &url::Url) -> bool {
    url.scheme() == "https"
        && url.username().is_empty()
        && url.password().is_none()
        && url.port_or_known_default() == Some(443)
        && matches!(url.host_str(), Some("pass.cc-pay.cn" | "sso.buaa.edu.cn"))
}

async fn get<T: HttpTransport + Sync>(
    session: &Session<T>,
    url: &str,
) -> Result<HttpResponse, AppError> {
    let initial = url::Url::parse(url).map_err(|_| AppError::changed())?;
    if !trusted(&initial) {
        return Err(AppError::changed());
    }
    let mut request = HttpRequest::get(url).header("Accept", "application/json");
    request.response_limit = Some(LIMIT);
    let response = session.send_following_redirects(request).await?;
    let final_url = url::Url::parse(&response.final_url).map_err(|_| AppError::changed())?;
    if !trusted(&final_url) || final_url.host_str() == Some("sso.buaa.edu.cn") {
        return Err(AppError::session_expired());
    }
    if response.status == 401 {
        return Err(AppError::session_expired());
    }
    if response.status == 403 {
        return Err(AppError::new(ErrorCode::AccessPolicyDenied));
    }
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    if response.body.len() > LIMIT {
        return Err(AppError::changed());
    }
    Ok(response)
}

async fn json<T: HttpTransport + Sync>(session: &Session<T>, url: &str) -> Result<Value, AppError> {
    let response = get(session, url).await?;
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}

pub async fn establish<T: HttpTransport + Sync>(session: &Session<T>) -> Result<(), AppError> {
    get(session, ENTRY_URL).await?;
    let value = json(session, USER_URL).await?;
    crate::codecs::campus_card::ensure_success(&value)
}

pub async fn card_number<T: HttpTransport + Sync>(
    session: &Session<T>,
) -> Result<String, AppError> {
    let value = json(session, CARDS_URL).await?;
    crate::codecs::campus_card::campus_card_number(&value)
}

pub async fn balance<T: HttpTransport + Sync>(
    session: &Session<T>,
    card_number: &str,
) -> Result<i64, AppError> {
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("stuNo", card_number)
        .finish();
    let value = json(session, &format!("{BALANCE_URL}?{query}")).await?;
    crate::codecs::campus_card::balance_minor(&value)
}
