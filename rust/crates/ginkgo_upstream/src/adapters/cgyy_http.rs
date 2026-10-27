//! CGYY fixed direct routing, signed read-only endpoints (API §6B).
use crate::{
    auth::{cas, session::Session, Credentials},
    codecs::cgyy,
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use md5::{Digest, Md5};
use serde_json::Value;
use std::collections::BTreeMap;
const BASE: &str = "https://cgyy.buaa.edu.cn/venue-zhjs-server";
const PREFIX: &str = "c640ca392cd45fb3a55b00a63a86c618";
pub fn sign(path: &str, params: &BTreeMap<String, String>, timestamp: i64) -> String {
    let mut payload = format!("{PREFIX}/{}", path.trim_start_matches('/'));
    for (key, value) in params {
        if ![
            "gmtCreate",
            "gmtModified",
            "creator",
            "modifier",
            "id",
            "_index",
            "_rowKey",
        ]
        .contains(&key.as_str())
            && !value.is_empty()
        {
            payload.push_str(key);
            payload.push_str(value);
        }
    }
    payload.push_str(&format!("{timestamp} {PREFIX}"));
    format!("{:x}", Md5::digest(payload.as_bytes()))
}
fn request(
    path: &str,
    mut params: BTreeMap<String, String>,
    token: Option<&str>,
    sso: Option<&str>,
) -> HttpRequest {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;
    let post = path == "/api/login"
        || path.starts_with("/api/reservation/order/")
        || path.starts_with("/api/orders/new/cancel/")
        || path == "/api/captcha/check";
    if !post {
        params
            .entry("nocache".into())
            .or_insert_with(|| timestamp.to_string());
    }
    let signature = sign(path, &params, timestamp);
    let query = url::form_urlencoded::Serializer::new(String::new())
        .extend_pairs(&params)
        .finish();
    let mut request = if post {
        HttpRequest::post_form(format!("{BASE}{path}"), query)
    } else {
        HttpRequest::get(format!("{BASE}{path}?{query}"))
    };
    request = request
        .header("Accept", "application/json, text/plain, */*")
        .header(
            "Referer",
            "https://cgyy.buaa.edu.cn/venue-zhjs/mobileReservation",
        )
        .header("app-key", "8fceb735082b5a529312040b58ea780b")
        .header("timestamp", &timestamp.to_string())
        .header("sign", &signature);
    if let Some(token) = token {
        request = request.header("cgAuthorization", token);
    }
    if let Some(sso) = sso {
        request = request.header("Sso-Token", sso);
    }
    request
}
async fn decode<T: HttpTransport>(
    session: &Session<T>,
    request: HttpRequest,
) -> Result<Value, AppError> {
    let response = session.send_direct(request).await?;
    if response.status == 401 || cas::is_login_redirect(&response.final_url, &response.body) {
        return Err(AppError::session_expired());
    }
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    let value: Value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    cgyy::envelope(&value)?;
    Ok(value)
}
async fn follow<T: HttpTransport>(
    session: &Session<T>,
    mut response: HttpResponse,
) -> Result<HttpResponse, AppError> {
    for _ in 0..10 {
        if !(300..400).contains(&response.status) {
            return Ok(response);
        }
        let location = response.header("location").ok_or_else(AppError::changed)?;
        let next = url::Url::parse(&response.final_url)
            .and_then(|u| u.join(location))
            .map_err(|_| AppError::changed())?;
        // Authentication only follows HTTPS campus origins.
        if next.scheme() != "https"
            || !next
                .host_str()
                .is_some_and(|h| h == "buaa.edu.cn" || h.ends_with(".buaa.edu.cn"))
        {
            return Err(AppError::changed());
        }
        response = session.send_direct(HttpRequest::get(next.as_str())).await?;
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}
pub async fn login<T: HttpTransport>(
    session: &Session<T>,
    credentials: Option<&Credentials>,
) -> Result<String, AppError> {
    let response = session
        .send_direct(HttpRequest::get(format!("{BASE}/sso/manageLogin")))
        .await?;
    let response = follow(session, response).await?;
    if cas::extract_execution(&response.body).is_some() {
        if cas::detect_captcha(&response.body).is_some() {
            return Err(AppError::new(ErrorCode::CaptchaRequired));
        }
        let credential = credentials.ok_or_else(AppError::session_expired)?;
        let action = cas::extract_login_form_action(&response.body)
            .unwrap_or_else(|| response.final_url.clone());
        let action = url::Url::parse(&response.final_url)
            .and_then(|u| u.join(&action))
            .map_err(|_| AppError::changed())?;
        if action.scheme() != "https" || action.host_str() != Some("sso.buaa.edu.cn") {
            return Err(AppError::changed());
        }
        let form = cas::form_urlencode(&cas::login_fields(
            &response.body,
            &credential.username,
            &credential.password,
            None,
        ));
        let posted = session
            .send_direct(HttpRequest::post_form(action.as_str(), form))
            .await?;
        let posted = follow(session, posted).await?;
        if cas::detect_captcha(&posted.body).is_some() {
            return Err(AppError::new(ErrorCode::CaptchaRequired));
        }
        if cas::extract_execution(&posted.body).is_some() {
            return Err(AppError::session_expired());
        }
        let refreshed = session
            .send_direct(HttpRequest::get(format!("{BASE}/sso/manageLogin")))
            .await?;
        follow(session, refreshed).await?;
    }
    let sso = session
        .cgyy_sso_token()
        .ok_or_else(AppError::session_expired)?;
    let value = decode(
        session,
        request("/api/login", BTreeMap::new(), None, Some(&sso)),
    )
    .await?;
    value["data"]["token"]["access_token"]
        .as_str()
        .filter(|s| !s.is_empty())
        .map(str::to_owned)
        .ok_or_else(AppError::changed)
}
const PAGE: &str = "page";
const SIZE: &str = "size";
/// Official mobile page size for `/api/orders/mine` (§6B.1).
pub const ORDERS_PAGE_SIZE: i64 = 5;
/// Hard bound on the pages one read may walk. This is deliberately small: a
/// short visible history is reported as such instead of scanning everything.
pub const ORDERS_MAX_PAGES: i64 = 4;

pub async fn load<T: HttpTransport>(
    session: &Session<T>,
    kind: &str,
    site: i64,
    date: &str,
    token: Option<&str>,
) -> Result<Value, AppError> {
    if kind == "order" {
        if site <= 0 {
            return Err(AppError::invalid());
        }
        return decode(
            session,
            request(&format!("/api/orders/{site}"), BTreeMap::new(), token, None),
        )
        .await;
    }
    if kind == "lockCode" {
        return decode(
            session,
            request("/api/orders/lock/code", BTreeMap::new(), token, None),
        )
        .await;
    }
    let (path, params) = match kind {
        "venues" => (
            "/api/front/website/venues",
            vec![
                ("page", "-1".to_owned()),
                ("size", "-1".into()),
                ("reservationRoleId", "3".into()),
            ],
        ),
        "day" => (
            "/api/reservation/day/info",
            vec![
                ("searchDate", date.into()),
                ("venueSiteId", site.to_string()),
            ],
        ),
        "orders" => {
            let token = token.ok_or_else(AppError::invalid)?;
            return read_orders(session, token).await;
        }
        _ => return Err(AppError::invalid()),
    };
    decode(
        session,
        request(
            path,
            params.into_iter().map(|(k, v)| (k.into(), v)).collect(),
            token,
            None,
        ),
    )
    .await
}

/// One explicit `page`/`size` orders read. Callers own the bounded paging loop.
pub async fn load_orders<T: HttpTransport>(
    session: &Session<T>,
    page: i64,
    size: i64,
    token: &str,
) -> Result<Value, AppError> {
    if page < 0 || !(1..=50).contains(&size) {
        return Err(AppError::invalid());
    }
    decode(
        session,
        request(
            "/api/orders/mine",
            BTreeMap::from([
                (PAGE.to_owned(), page.to_string()),
                (SIZE.to_owned(), size.to_string()),
            ]),
            Some(token),
            None,
        ),
    )
    .await
}

/// Bounded orders read. Starts at the official page 0 / size 5 and merges at
/// most [`ORDERS_MAX_PAGES`] pages, stopping on a short page, a reported
/// `totalElements` or a repeated id (which means the server re-sorted between
/// pages). The merged rows keep the raw upstream fields so cancellation and
/// read-back checks keep their existing gates.
pub async fn read_orders<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
) -> Result<Value, AppError> {
    let mut rows: Vec<Value> = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut total: Option<i64> = None;
    for page in 0..ORDERS_MAX_PAGES {
        let value = load_orders(session, page, ORDERS_PAGE_SIZE, token).await?;
        let data = cgyy::envelope(&value)?;
        let page_rows = match data["content"]
            .as_array()
            .or_else(|| data["list"].as_array())
        {
            Some(rows) => rows,
            None => return Err(AppError::changed()),
        };
        total = cgyy::number(&data["totalElements"]).filter(|count| *count >= 0);
        let mut merged = 0;
        let mut repeated = false;
        for row in page_rows {
            let id = cgyy::number(&row["id"]);
            if let Some(id) = id {
                if !seen.insert(id) {
                    repeated = true;
                    break;
                }
            }
            rows.push(row.clone());
            merged += 1;
        }
        let short = (merged as i64) < ORDERS_PAGE_SIZE;
        if repeated || short || total.is_some_and(|count| rows.len() as i64 >= count) {
            break;
        }
    }
    let mut data = serde_json::Map::new();
    data.insert("content".into(), Value::Array(rows));
    if let Some(total) = total {
        data.insert("totalElements".into(), Value::from(total));
    }
    Ok(serde_json::json!({"code": 200, "data": Value::Object(data)}))
}
/// Signed business request; caller owns mutation confirmation and retry policy.
pub async fn business<T: HttpTransport>(
    session: &Session<T>,
    path: &str,
    params: BTreeMap<String, String>,
    token: &str,
) -> Result<Value, AppError> {
    decode(session, request(path, params, Some(token), None)).await
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn signature_matches_apple_vector() {
        assert_eq!(
            sign(
                "/api/front/website/venues",
                &[
                    ("page".into(), "-1".into()),
                    ("size".into(), "-1".into()),
                    ("reservationRoleId".into(), "3".into())
                ]
                .into(),
                1_700_000_000_000
            ),
            "e5293206cc00281c757eed3674ab37ea"
        );
    }
}
