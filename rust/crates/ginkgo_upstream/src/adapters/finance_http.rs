//! API.md §6H read-only student income HTTP flow (`icw` -> `chaxun.icw`).
//!
//! Reuses the shared SSO cookie session without submitting passwords, unwraps
//! WebVPN relative redirects, upgrades the documented `icw.buaa.edu.cn` same-path
//! HTTP callback to HTTPS, and keeps the query JWT strictly in local memory.
use crate::{
    auth::{cas, session::Session},
    codecs::finance,
    foundation::{
        http::{HttpMethod, HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError, ErrorCode,
};
use ginkgo_domain::features::finance::FinanceIncomeEntry;
use serde_json::Value;
use std::collections::HashSet;

pub const PORTAL_START: &str =
    "https://sso.buaa.edu.cn/login?service=http%3A%2F%2Ficw.buaa.edu.cn%2Fcheckbuaa.aspx";
pub const JUMP_URL: &str = "https://icw.buaa.edu.cn/jump.aspx?sysid=wscx";
pub const API_LOGIN_URL: &str = "https://chaxun.icw.buaa.edu.cn/api-zhcx/login";
pub const API_SRCX_URL: &str = "https://chaxun.icw.buaa.edu.cn/api-zhcx/getStudentSRCX";

const RESPONSE_LIMIT: usize = 512 * 1024;
const PAGE_SIZE: u32 = 100;
const MAX_PAGES: u32 = 50;

pub(crate) struct FinanceToken {
    pub user_id: String,
    pub token: String,
}

fn is_gateway_login_url(raw: &str) -> bool {
    url::Url::parse(raw).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|h| h.eq_ignore_ascii_case(webvpn::GATEWAY_HOST))
            && url.path().trim_end_matches('/').ends_with("/login")
    })
}

fn check_gateway_response(response: &HttpResponse) -> Result<(), AppError> {
    if is_gateway_login_url(&response.final_url) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    if matches!(response.status, 301 | 302 | 303 | 307 | 308) {
        if let Some(location) = response.header("location") {
            let joined = url::Url::parse(&response.final_url)
                .and_then(|base| base.join(location.trim()))
                .ok();
            if joined.is_some_and(|u| is_gateway_login_url(u.as_str())) {
                return Err(AppError::with_detail(
                    ErrorCode::AccessPolicyDenied,
                    "webvpn_login_required",
                ));
            }
        }
    }
    Ok(())
}

fn resolve_allowed_target(location: &str, base: &str) -> Result<url::Url, AppError> {
    let resolved = webvpn::resolve_redirect(location, base).ok_or_else(AppError::changed)?;
    if is_gateway_login_url(&resolved) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    let mut parsed = url::Url::parse(&resolved).map_err(|_| AppError::changed())?;
    if !parsed.username().is_empty() || parsed.password().is_some() || parsed.fragment().is_some() {
        return Err(AppError::changed());
    }
    let default_port = match parsed.scheme() {
        "https" => parsed.port_or_known_default() == Some(443),
        "http" => {
            parsed.host_str() == Some("icw.buaa.edu.cn")
                && parsed.port_or_known_default() == Some(80)
        }
        _ => false,
    };
    if !default_port {
        return Err(AppError::changed());
    }
    let allowed = match parsed.host_str() {
        Some("sso.buaa.edu.cn") => parsed.scheme() == "https" && parsed.path() == "/login",
        Some("icw.buaa.edu.cn") => matches!(
            parsed.path(),
            "/checkbuaa.aspx" | "/Newindex.aspx" | "/jump.aspx"
        ),
        Some("chaxun.icw.buaa.edu.cn") => {
            parsed.scheme() == "https" && parsed.path() == "/gxzhcxzhb/login"
        }
        _ => false,
    };
    if !allowed {
        return Err(AppError::changed());
    }
    if parsed.scheme() == "http" {
        parsed
            .set_scheme("https")
            .map_err(|()| AppError::changed())?;
        parsed.set_port(None).map_err(|()| AppError::changed())?;
    }
    Ok(parsed)
}

async fn establish_portal<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {
    let mut current = PORTAL_START.to_owned();
    for _ in 0..12 {
        let mut request = HttpRequest::get(&current)
            .header("Accept", "text/html,application/xhtml+xml,*/*;q=0.8");
        request.response_limit = Some(RESPONSE_LIMIT);
        let response = session.send_with_fallback(request).await?;
        check_gateway_response(&response)?;
        if matches!(response.status, 301 | 302 | 303 | 307 | 308) {
            let location = response.header("location").ok_or_else(AppError::changed)?;
            current = resolve_allowed_target(location, &response.final_url)?.into();
            continue;
        }
        if response.status == 401 {
            return Err(AppError::session_expired());
        }
        if response.status == 403 {
            return Err(AppError::module_auth_required());
        }
        if response.status != 200 {
            return Err(AppError::unavailable());
        }
        let landed = resolve_allowed_target(&response.final_url, &current)
            .unwrap_or_else(|_| url::Url::parse(&current).expect("validated URL"));
        if landed.host_str() == Some("sso.buaa.edu.cn")
            || cas::is_login_redirect(landed.as_str(), &response.body)
        {
            return Err(AppError::session_expired());
        }
        if landed.host_str() == Some("icw.buaa.edu.cn") && landed.path() == "/Newindex.aspx" {
            return Ok(());
        }
        return Err(AppError::changed());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

pub(crate) async fn authenticate<T: HttpTransport>(
    session: &Session<T>,
    expected_account: &str,
) -> Result<FinanceToken, AppError> {
    establish_portal(session).await?;

    let mut jump_req =
        HttpRequest::get(JUMP_URL).header("Accept", "text/html,application/xhtml+xml,*/*;q=0.8");
    jump_req.response_limit = Some(RESPONSE_LIMIT);
    let jump_resp = session.send_with_fallback(jump_req).await?;
    check_gateway_response(&jump_resp)?;
    if !matches!(jump_resp.status, 301 | 302 | 303 | 307 | 308) {
        if cas::is_login_redirect(&jump_resp.final_url, &jump_resp.body) {
            return Err(AppError::session_expired());
        }
        return Err(AppError::changed());
    }
    let location_raw = jump_resp.header("location").ok_or_else(AppError::changed)?;
    let query_login = resolve_allowed_target(location_raw, &jump_resp.final_url)?;
    if query_login.host_str() != Some("chaxun.icw.buaa.edu.cn")
        || query_login.path() != "/gxzhcxzhb/login"
    {
        return Err(AppError::changed());
    }

    let extract_param = |name: &str| -> Result<String, AppError> {
        let mut matches: Vec<_> = query_login
            .query_pairs()
            .filter(|(k, _)| k == name)
            .collect();
        if matches.len() != 1 || matches[0].1.trim().is_empty() {
            return Err(AppError::changed());
        }
        Ok(matches.swap_remove(0).1.into_owned())
    };
    let user_id = extract_param("Userid")?;
    if !expected_account.trim().is_empty() && !user_id.eq_ignore_ascii_case(expected_account.trim())
    {
        return Err(AppError::session_expired());
    }
    let cypt = extract_param("Cypt")?;
    let stamp = extract_param("Stamp")?;

    let form = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("username", &user_id)
        .append_pair("password", &cypt)
        .append_pair("yzm", "yzm")
        .append_pair("stamp", &stamp)
        .finish();
    let mut login_req = HttpRequest::post_form(API_LOGIN_URL, form)
        .header("Accept", "application/json")
        .header("Referer", query_login.as_str());
    login_req.response_limit = Some(RESPONSE_LIMIT);
    let login_resp = session.send(login_req).await?;
    check_gateway_response(&login_resp)?;
    if login_resp.status == 401 {
        return Err(AppError::module_auth_required());
    }
    if login_resp.status == 403 {
        return Err(AppError::new(ErrorCode::AccessPolicyDenied));
    }
    if login_resp.status != 200 {
        return Err(AppError::unavailable());
    }
    let value: Value = serde_json::from_str(&login_resp.body).map_err(|_| AppError::changed())?;
    let token = finance::parse_login_token(&value)?;
    Ok(FinanceToken { user_id, token })
}

pub(crate) async fn fetch_all_pages<T: HttpTransport>(
    session: &Session<T>,
    credential: &FinanceToken,
    check_owner: impl Fn() -> Result<(), AppError>,
) -> Result<(Vec<FinanceIncomeEntry>, u32), AppError> {
    let mut all_entries = Vec::new();
    let mut seen_ids = HashSet::new();
    let mut expected_total: Option<usize> = None;

    for page in 1..=MAX_PAGES {
        check_owner()?;
        let body = serde_json::json!({
            "userId": credential.user_id,
            "currentPage": page,
            "limit": PAGE_SIZE,
        })
        .to_string();
        let mut req = HttpRequest::new(HttpMethod::Post, API_SRCX_URL)
            .header("Content-Type", "application/json")
            .header("Accept", "application/json")
            .header("Authorization", &format!("Bearer {}", credential.token));
        req.body = Some(body);
        req.response_limit = Some(RESPONSE_LIMIT);
        let resp = session.send(req).await?;
        check_owner()?;
        check_gateway_response(&resp)?;
        if resp.status == 401 {
            return Err(AppError::module_auth_required());
        }
        if resp.status == 403 {
            return Err(AppError::new(ErrorCode::AccessPolicyDenied));
        }
        if resp.status != 200 {
            return Err(AppError::unavailable());
        }
        let value: Value = serde_json::from_str(&resp.body).map_err(|_| AppError::changed())?;
        let (batch, total) = finance::parse_page(&value)?;
        if expected_total.is_some_and(|prev| prev != total) || batch.len() > PAGE_SIZE as usize {
            return Err(AppError::changed());
        }
        expected_total = Some(total);
        let batch_empty = batch.is_empty();
        for entry in batch {
            if !seen_ids.insert(entry.id.clone()) {
                return Err(AppError::changed());
            }
            all_entries.push(entry);
        }
        if all_entries.len() == total {
            let total_u32 = u32::try_from(total).map_err(|_| AppError::changed())?;
            return Ok((all_entries, total_u32));
        }
        if batch_empty || all_entries.len() > total {
            return Err(AppError::changed());
        }
    }
    Err(AppError::changed())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::MockTransport;
    use serde_json::json;

    #[tokio::test]
    async fn follows_http_to_https_portal_and_paginates_incomes() {
        let jump_target =
            "https://chaxun.icw.buaa.edu.cn/gxzhcxzhb/login?Userid=sy2501001&Cypt=ticket-1&Stamp=1700";
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, PORTAL_START, "").with_header(
                "Location",
                "http://icw.buaa.edu.cn/checkbuaa.aspx?ticket=ST-1",
            ),
            HttpResponse::new(
                302,
                "https://icw.buaa.edu.cn/checkbuaa.aspx?ticket=ST-1",
                "",
            )
            .with_header("Location", "/Newindex.aspx"),
            HttpResponse::new(
                200,
                "https://icw.buaa.edu.cn/Newindex.aspx",
                "<html>ok</html>",
            ),
            HttpResponse::new(302, JUMP_URL, "").with_header("Location", jump_target),
            HttpResponse::new(
                200,
                API_LOGIN_URL,
                json!({"code": 200, "data": {"token": "jwt-synthetic"}}).to_string(),
            ),
            HttpResponse::new(
                200,
                API_SRCX_URL,
                json!({
                    "code": 200,
                    "data": {
                        "total": 1,
                        "mx": [{
                            "lsh": "202611001",
                            "ffxmmc": "助研津贴",
                            "zy": "合成科研补助",
                            "je": 800,
                            "se": 0,
                            "sfje": 800,
                            "lrrq": "2026-11-10",
                            "nian": "2026",
                            "yue": "11"
                        }]
                    }
                })
                .to_string(),
            ),
        ]);
        let session = Session::new(transport.clone());
        let cred = authenticate(&session, "sy2501001")
            .await
            .expect("authenticated");
        let (rows, total) = fetch_all_pages(&session, &cred, || Ok(()))
            .await
            .expect("fetched");
        assert_eq!(total, 1);
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].net_minor, Some(80_000));
        let requests = transport.requests();
        assert_eq!(
            requests[1].url,
            "https://icw.buaa.edu.cn/checkbuaa.aspx?ticket=ST-1"
        );
        assert_eq!(
            requests[5].header_value("Authorization"),
            Some("Bearer jwt-synthetic")
        );
    }

    #[tokio::test]
    async fn webvpn_gateway_login_redirect_is_classified_for_gateway_recovery() {
        let wrapped = webvpn::wrap(PORTAL_START).expect("wrapped");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, &wrapped, "")
                .with_header("Location", "https://d.buaa.edu.cn/login"),
            HttpResponse::new(200, "https://d.buaa.edu.cn/login", "<form/>"),
        ]);
        let session = Session::new(transport);
        session.set_route(crate::auth::session::RouteMode::WebVpn);
        for _ in 0..2 {
            let err = authenticate(&session, "sy2501001")
                .await
                .err()
                .expect("gateway err");
            assert_eq!(err.code, ErrorCode::AccessPolicyDenied);
            assert_eq!(err.detail.as_deref(), Some("webvpn_login_required"));
        }
    }

    #[tokio::test]
    async fn mismatched_portal_account_is_rejected() {
        let jump_target =
            "https://chaxun.icw.buaa.edu.cn/gxzhcxzhb/login?Userid=other999&Cypt=ticket-1&Stamp=1700";
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(
                200,
                "https://icw.buaa.edu.cn/Newindex.aspx",
                "<html>ok</html>",
            ),
            HttpResponse::new(302, JUMP_URL, "").with_header("Location", jump_target),
        ]);
        let session = Session::new(transport);
        let err = authenticate(&session, "sy2501001")
            .await
            .err()
            .expect("account mismatch");
        assert_eq!(err.code, ErrorCode::SessionExpired);
    }
}
