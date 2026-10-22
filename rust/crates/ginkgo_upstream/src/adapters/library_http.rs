//! booking.lib v4 HTTP. Read recovery and single-attempt mutations are separate (API.md §5).
use crate::{
    auth::{cas, session::Session},
    features::library::{
        self, LibraryArea, LibraryBooking, LibrarySeat, LibrarySlot, LibraryVenue,
    },
    foundation::{
        http::{HttpMethod, HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError, ErrorCode,
};
use serde_json::{json, Value};

pub const BASE: &str = "https://booking.lib.buaa.edu.cn";
pub const LOGIN_START: &str = "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbooking.lib.buaa.edu.cn%2Fv4%2Flogin%2Fcas";
pub const LOGIN_USER: &str = "https://booking.lib.buaa.edu.cn/v4/login/user";
const USER_AGENT: &str =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/147.0.0.0 Safari/537.36";

fn library_auth_error() -> AppError {
    AppError::with_detail(ErrorCode::SessionExpired, "library_login")
}

fn webvpn_required() -> AppError {
    AppError::with_detail(ErrorCode::AccessPolicyDenied, "webvpn_login_required")
}

/// Walk the library CAS chain manually (API.md §5.1: at most eight hops, the
/// cas parameter may live in the query string or the fragment), then exchange
/// it for the business token.
pub async fn login<T: HttpTransport>(session: &Session<T>) -> Result<String, AppError> {
    let mut url = LOGIN_START.to_string();
    for hop in 0..8 {
        if let Some(token) = cas_token(&url) {
            return exchange(session, &token).await;
        }
        let response = session.send_with_fallback(HttpRequest::get(&url)).await?;
        if let Some(token) = cas_token(&response.final_url) {
            return exchange(session, &token).await;
        }
        if is_gateway_login(&response) {
            return Err(webvpn_required());
        }
        if response.status == 401 || response.status == 403 {
            return Err(library_auth_error());
        }
        if (300..400).contains(&response.status) {
            let Some(location) = response.header("location") else {
                return Err(AppError::changed());
            };
            let next = crate::auth::redirect::resolve_get(location, &response.final_url)?;
            let Ok(parsed) = url::Url::parse(&next) else {
                return Err(library_auth_error());
            };
            let host = parsed.host_str().unwrap_or_default();
            if parsed.scheme() != "https"
                || !["sso.buaa.edu.cn", "booking.lib.buaa.edu.cn"].contains(&host)
            {
                return Err(library_auth_error());
            }
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
            return Err(library_auth_error());
        }
        return Err(AppError::changed());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

async fn exchange<T: HttpTransport>(session: &Session<T>, cas: &str) -> Result<String, AppError> {
    let request = json_request(LOGIN_USER, None, &json!({"cas": cas}));
    let response = session.send(request).await?;
    let value = parse_envelope(&response)?;
    library::parse_login_user(&value)
}

pub async fn venues<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    day: &str,
) -> Result<Vec<LibraryVenue>, AppError> {
    if !is_day(day) {
        return Err(AppError::invalid());
    }
    let data = post(session, token, "space/pcTopFor", &json!({ "day": day })).await?;
    library::parse_venues(&data)
}

pub async fn areas<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    library_id: &str,
    day: &str,
) -> Result<Vec<LibraryArea>, AppError> {
    if library_id.trim().is_empty() || !is_day(day) {
        return Err(AppError::invalid());
    }
    let data = post(
        session,
        token,
        "space/pick",
        &json!({
            "premisesIds": library_id,
            "categoryIds": [],
            "storeyIds": [],
            "boutiqueIds": [],
            "date": day,
        }),
    )
    .await?;
    library::parse_areas(&data)
}

pub async fn slots<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    area_id: &str,
) -> Result<Vec<LibrarySlot>, AppError> {
    if area_id.trim().is_empty() {
        return Err(AppError::invalid());
    }
    let data = post(session, token, "Space/map", &json!({ "id": area_id })).await?;
    library::parse_slots(&data)
}

pub async fn seats<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    area_id: &str,
    slot: &LibrarySlot,
) -> Result<Vec<LibrarySeat>, AppError> {
    if area_id.trim().is_empty() || slot.id.is_empty() || !is_day(&slot.day) {
        return Err(AppError::invalid());
    }
    let data = post(
        session,
        token,
        "Space/seat",
        &json!({
            "id": area_id,
            "day": slot.day,
            "label_id": [],
            "start_time": slot.start,
            "end_time": slot.end,
            "begdate": "",
            "enddate": "",
        }),
    )
    .await?;
    library::parse_seats(&data)
}

pub async fn bookings<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
) -> Result<Vec<LibraryBooking>, AppError> {
    let data = post(session, token, "index/subscribe", &json!({})).await?;
    library::parse_bookings(&data)
}

/// Read-only history, same bearer token and envelope as current bookings.
pub async fn history<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    page: i32,
    limit: i32,
) -> Result<library::LibraryHistoryPage, AppError> {
    if page < 1 || !(1..=100).contains(&limit) {
        return Err(AppError::invalid());
    }
    let data = post(
        session,
        token,
        "member/seat",
        &json!({"type":"1", "page":page, "limit":limit}),
    )
    .await?;
    library::parse_history(&data, page, limit)
}

async fn post<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    path: &str,
    body: &Value,
) -> Result<Value, AppError> {
    let request = json_request(&format!("{BASE}/v4/{path}"), Some(token), body);
    let response = session.send(request).await?;
    let value = parse_envelope(&response)?;
    Ok(value.get("data").cloned().unwrap_or(Value::Null))
}

fn json_request(url: &str, token: Option<&str>, body: &Value) -> HttpRequest {
    let mut request = HttpRequest::new(HttpMethod::Post, url)
        .header("Content-Type", "application/json")
        .header("Accept", "application/json, text/plain, */*")
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Origin", BASE)
        .header("Referer", BASE)
        .header("User-Agent", USER_AGENT);
    if let Some(token) = token {
        request = request.header("Authorization", &format!("bearer{token}"));
    }
    request.body = Some(body.to_string());
    request
}

/// The envelope is shared by every business endpoint: HTTP auth, a login
/// message or code outside {0,1} must not be mistaken for an empty list.
pub fn parse_envelope(response: &HttpResponse) -> Result<Value, AppError> {
    if matches!(response.status, 401 | 403)
        || cas::is_login_redirect(&response.final_url, &response.body)
    {
        return Err(library_auth_error());
    }
    if is_gateway_login(response) {
        return Err(webvpn_required());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::unavailable());
    }
    if response.body.trim_start().starts_with('<') {
        return Err(AppError::changed());
    }
    let value: Value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    let code = value
        .get("code")
        .and_then(|code| {
            code.as_i64()
                .or_else(|| code.as_str().and_then(|text| text.trim().parse().ok()))
        })
        .ok_or_else(AppError::changed)?;
    let message = value
        .get("message")
        .or_else(|| value.get("msg"))
        .and_then(Value::as_str)
        .unwrap_or_default();
    if ["登录失效", "请重新登录", "未登录"]
        .iter()
        .any(|keyword| message.contains(keyword))
    {
        return Err(library_auth_error());
    }
    if code != 0 && code != 1 {
        return Err(AppError::with_detail(
            ErrorCode::BusinessRejected,
            "library_rejected",
        ));
    }
    Ok(value)
}

fn is_gateway_login(response: &HttpResponse) -> bool {
    url::Url::parse(&response.final_url).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|host| host.eq_ignore_ascii_case(webvpn::GATEWAY_HOST))
            && url.path().trim_end_matches('/').ends_with("/login")
    })
}

fn is_day(value: &str) -> bool {
    value.len() == 10 && chrono::NaiveDate::parse_from_str(value, "%Y-%m-%d").is_ok()
}

/// API.md §5.1: the cas parameter may follow ?, & or # and must be
/// percent-decoded. A  is not a space here, so no form decoding.
pub fn cas_token(raw: &str) -> Option<String> {
    for marker in ["?cas=", "&cas=", "#cas="] {
        if let Some(start) = raw.find(marker) {
            let value = &raw[start + marker.len()..];
            let end = value.find(['&', '#']).unwrap_or(value.len());
            let decoded = percent_decode(&value[..end])?;
            if !decoded.is_empty() {
                return Some(decoded);
            }
        }
    }
    None
}

fn percent_decode(input: &str) -> Option<String> {
    let bytes = input.as_bytes();
    let mut output = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let hex = std::str::from_utf8(&bytes[index + 1..index + 3]).ok()?;
            output.push(u8::from_str_radix(hex, 16).ok()?);
            index += 3;
        } else {
            output.push(bytes[index]);
            index += 1;
        }
    }
    String::from_utf8(output).ok()
}

/// Single attempt: never route-fallback, replay on auth failure, or follow a redirect.
pub async fn mutate<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    path: &str,
    body: &Value,
) -> crate::features::mutation::MutationOutcome {
    use crate::features::{library_mutation, mutation::MutationOutcome};
    let response = session
        .send(json_request(
            &format!("{BASE}/v4/{path}"),
            Some(token),
            body,
        ))
        .await;
    let Ok(response) = response else {
        return MutationOutcome::uncertain();
    };
    if !(200..300).contains(&response.status) {
        return MutationOutcome::uncertain();
    }
    match serde_json::from_str::<Value>(&response.body) {
        Ok(value) => library_mutation::parse_result(&value),
        Err(_) => MutationOutcome::uncertain(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::MockTransport;
    use serde_json::json;

    fn token_body() -> String {
        json!({"code": 0, "data": {"member": {"token": "fixture-token"}}}).to_string()
    }

    #[tokio::test]
    async fn cas_redirects_are_walked_and_the_token_is_exchanged() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, LOGIN_START, "")
                .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1"),
            HttpResponse::new(302, "https://sso.buaa.edu.cn/login?ticket=ST-1", "").with_header(
                "Location",
                "https://booking.lib.buaa.edu.cn/v4/login/cas?cas=fixture%2Btoken#/home",
            ),
            HttpResponse::new(200, LOGIN_USER, token_body()),
        ]);
        let session = Session::new(transport.clone());
        assert_eq!(login(&session).await.expect("token"), "fixture-token");
        let requests = transport.requests();
        assert_eq!(requests.len(), 3);
        assert_eq!(requests[2].method, HttpMethod::Post);
        assert_eq!(requests[2].url, LOGIN_USER);
        assert_eq!(
            requests[2].header_value("Content-Type"),
            Some("application/json")
        );
        assert!(requests[2]
            .body
            .as_deref()
            .unwrap_or("")
            .contains("fixture+token"));
    }

    #[tokio::test]
    async fn cross_host_redirects_are_rejected() {
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(302, LOGIN_START, "")
                .with_header("Location", "https://example.com/login?cas=stolen")]);
        let session = Session::new(transport);
        assert_eq!(
            login(&session).await.expect_err("host").code,
            ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn business_requests_use_the_documented_nonstandard_authorization() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            format!("{BASE}/v4/space/pcTopFor"),
            json!({"code": 1, "data": {"list": [
                {"id": "1", "name": "学院路馆", "free_num": 12, "total_num": 30}
            ]}})
            .to_string(),
        )]);
        let session = Session::new(transport.clone());
        let venues = venues(&session, "fixture-token", "2026-10-20")
            .await
            .expect("venues");
        assert_eq!(venues.len(), 1);
        let request = &transport.requests()[0];
        assert_eq!(
            request.header_value("Authorization"),
            Some("bearerfixture-token")
        );
        assert_eq!(request.header_value("Origin"), Some(BASE));
        assert_eq!(request.body.as_deref(), Some(r#"{"day":"2026-10-20"}"#));
    }

    #[tokio::test]
    async fn envelopes_keep_auth_rejection_drift_and_business_errors_apart() {
        let cases = [
            (
                HttpResponse::new(401, LOGIN_USER, ""),
                ErrorCode::SessionExpired,
                Some("library_login"),
            ),
            (
                HttpResponse::new(
                    200,
                    LOGIN_USER,
                    json!({"code": 0, "message": "登录失效，请重新登录"}).to_string(),
                ),
                ErrorCode::SessionExpired,
                Some("library_login"),
            ),
            (
                HttpResponse::new(200, LOGIN_USER, "<html>cas</html>"),
                ErrorCode::ChangedResponse,
                None,
            ),
            (
                HttpResponse::new(
                    200,
                    LOGIN_USER,
                    json!({"code": 5, "message": "fixture"}).to_string(),
                ),
                ErrorCode::BusinessRejected,
                Some("library_rejected"),
            ),
            (
                HttpResponse::new(200, LOGIN_USER, "not json"),
                ErrorCode::ChangedResponse,
                None,
            ),
        ];
        for (response, code, detail) in cases {
            let transport = MockTransport::with_responses(vec![response]);
            let session = Session::new(transport);
            let error = venues(&session, "token", "2026-10-20")
                .await
                .expect_err("classified");
            assert_eq!(error.code, code);
            assert_eq!(error.detail.as_deref(), detail);
        }
    }

    #[tokio::test]
    async fn invalid_timeline_inputs_never_hit_the_network() {
        let session = Session::new(MockTransport::default());
        assert_eq!(
            venues(&session, "token", "2026/10/20")
                .await
                .expect_err("day")
                .code,
            ErrorCode::InvalidRequest
        );
        assert_eq!(
            areas(&session, "token", "", "2026-10-20")
                .await
                .expect_err("library")
                .code,
            ErrorCode::InvalidRequest
        );
    }

    #[test]
    fn cas_token_handles_query_fragment_and_percent_encoding() {
        assert_eq!(
            cas_token("https://x/v4/login/cas?cas=abc%2Fdef").as_deref(),
            Some("abc/def")
        );
        assert_eq!(
            cas_token("https://x/#/home?cas=token-1#frag").as_deref(),
            Some("token-1")
        );
        assert_eq!(cas_token("https://x/?next=1"), None);
    }
}
