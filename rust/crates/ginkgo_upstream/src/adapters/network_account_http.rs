//! API.md §6I read-only portal metrics (`it.buaa.edu.cn`) & campus network traffic
//! (`zfw.buaa.edu.cn`). Reuses shared SSO cookies, never submits passwords or recharge forms.
use crate::{
    auth::{cas, session::Session},
    codecs::network_account::{self, KEY_BOOK_NUM, KEY_CLOUD_DRIVE, KEY_MAIL_UNREAD, KEY_NET_FEE},
    foundation::{
        http::{HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError, ErrorCode,
};
use ginkgo_domain::features::network_account::{NetworkTrafficProduct, PortalMetricValue};
use serde_json::Value;

pub const PORTAL_LOGIN_START: &str =
    "https://it.buaa.edu.cn/manage/common/login/index?redirect=https%3A%2F%2Fit.buaa.edu.cn%2Fhome%2F";
pub const PORTAL_HOME: &str = "https://it.buaa.edu.cn/home/";
pub const PORTAL_INFO: &str = "https://it.buaa.edu.cn/personal/frontend/data/info";
pub const PORTAL_ITEMS: &str =
    "https://it.buaa.edu.cn/personal/frontend/data/items?type=personal_data";
pub const PORTAL_DETAIL_BASE: &str = "https://it.buaa.edu.cn/personal/frontend/data/detail";

pub const ZFW_CAS_START: &str = "https://zfw.buaa.edu.cn/sso/cas/index";
pub const ZFW_PAY_CARD: &str = "https://zfw.buaa.edu.cn/pay/card";
pub const ZFW_HOME: &str = "https://zfw.buaa.edu.cn/home";

const JSON_LIMIT: usize = 512 * 1024;
const HTML_LIMIT: usize = 4 * 1024 * 1024;
const DESKTOP_UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0";

pub(crate) struct PortalMetricsSnapshot {
    pub net_fee_minor: Option<i64>,
    pub net_fee_failure: Option<ErrorCode>,
    pub unreturned_books: Option<PortalMetricValue>,
    pub unread_mail: Option<PortalMetricValue>,
    pub cloud_drive_free: Option<PortalMetricValue>,
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
            if is_gateway_login_url(location.trim())
                || joined.is_some_and(|u| is_gateway_login_url(u.as_str()))
            {
                return Err(AppError::with_detail(
                    ErrorCode::AccessPolicyDenied,
                    "webvpn_login_required",
                ));
            }
        }
    }
    Ok(())
}

fn resolve_https_target(
    location: &str,
    base: &str,
    allowed_host: &str,
) -> Result<url::Url, AppError> {
    let resolved = webvpn::resolve_redirect(location, base).ok_or_else(AppError::changed)?;
    if is_gateway_login_url(&resolved) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    crate::auth::redirect::reject_reported_error(&resolved)?;
    let mut parsed = url::Url::parse(&resolved).map_err(|_| AppError::changed())?;
    if !parsed.username().is_empty() || parsed.password().is_some() {
        return Err(AppError::changed());
    }
    let valid_port = match parsed.scheme() {
        "https" => parsed.port_or_known_default() == Some(443),
        "http" => {
            parsed.port_or_known_default() == Some(80)
                && parsed.host_str().is_some_and(|h| {
                    h.eq_ignore_ascii_case("sso.buaa.edu.cn")
                        || h.eq_ignore_ascii_case(allowed_host)
                })
        }
        _ => false,
    };
    if !valid_port {
        return Err(AppError::changed());
    }
    let allowed = match parsed.host_str() {
        Some("sso.buaa.edu.cn") => parsed.path() == "/login",
        Some(host) => host.eq_ignore_ascii_case(allowed_host),
        None => false,
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

async fn portal_json_get<T: HttpTransport>(
    session: &Session<T>,
    url: &str,
) -> Result<Value, AppError> {
    let mut req = HttpRequest::get(url)
        .header("User-Agent", DESKTOP_UA)
        .header("Accept", "application/json, text/plain, */*")
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Referer", PORTAL_HOME);
    req.response_limit = Some(JSON_LIMIT);
    let resp = session.send_with_fallback(req).await?;
    check_gateway_response(&resp)?;
    if matches!(resp.status, 301 | 302 | 303 | 307 | 308 | 401 | 403) {
        return Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "portal_login_required",
        ));
    }
    if resp.status != 200 {
        return Err(AppError::unavailable());
    }
    let final_url = url::Url::parse(&resp.final_url).map_err(|_| AppError::changed())?;
    if final_url.host_str() != Some("it.buaa.edu.cn")
        || cas::is_login_redirect(&resp.final_url, &resp.body)
        || resp.body.trim_start().starts_with('<')
    {
        return Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "portal_login_required",
        ));
    }
    serde_json::from_str(&resp.body).map_err(|_| AppError::changed())
}

pub(crate) async fn bootstrap_portal<T: HttpTransport>(
    session: &Session<T>,
) -> Result<(), AppError> {
    let mut current = PORTAL_LOGIN_START.to_owned();
    let mut landed_portal = false;
    for _ in 0..10 {
        let mut req = HttpRequest::get(&current)
            .header("User-Agent", DESKTOP_UA)
            .header("Accept", "text/html,*/*")
            .header("Referer", PORTAL_HOME);
        req.response_limit = Some(HTML_LIMIT);
        let resp = session.send_with_fallback(req).await?;
        check_gateway_response(&resp)?;
        if matches!(resp.status, 301 | 302 | 303 | 307 | 308) {
            let location = resp.header("location").ok_or_else(AppError::changed)?;
            current = resolve_https_target(location, &resp.final_url, "it.buaa.edu.cn")?.into();
            continue;
        }
        if resp.status == 401 {
            return Err(AppError::session_expired());
        }
        if resp.status == 403 {
            return Err(AppError::module_auth_required());
        }
        if resp.status != 200 {
            return Err(AppError::unavailable());
        }
        let landed = url::Url::parse(&resp.final_url).map_err(|_| AppError::changed())?;
        if landed.host_str() == Some("sso.buaa.edu.cn")
            || cas::is_login_redirect(&resp.final_url, &resp.body)
        {
            return Err(AppError::session_expired());
        }
        if landed.host_str() == Some("it.buaa.edu.cn")
            && !landed.path().starts_with("/manage/common/login")
        {
            landed_portal = true;
            break;
        }
        return Err(AppError::changed());
    }
    if !landed_portal {
        return Err(AppError::new(ErrorCode::RedirectLimit));
    }
    let info_val = portal_json_get(session, PORTAL_INFO).await?;
    network_account::parse_portal_info(&info_val)
}

async fn fetch_portal_detail<T: HttpTransport>(
    session: &Session<T>,
    id: &str,
) -> Result<PortalMetricValue, AppError> {
    let mut detail_url = url::Url::parse(PORTAL_DETAIL_BASE).map_err(|_| AppError::changed())?;
    detail_url.query_pairs_mut().append_pair("id", id);
    let val = portal_json_get(session, detail_url.as_str()).await?;
    network_account::parse_portal_detail(&val)
}

pub(crate) async fn fetch_portal_metrics<T: HttpTransport>(
    session: &Session<T>,
    check_owner: impl Fn() -> Result<(), AppError>,
) -> Result<PortalMetricsSnapshot, AppError> {
    check_owner()?;
    match portal_json_get(session, PORTAL_INFO)
        .await
        .and_then(|val| network_account::parse_portal_info(&val))
    {
        Ok(()) => {}
        Err(err) if err.detail.as_deref() == Some("portal_login_required") => {
            bootstrap_portal(session).await?;
        }
        Err(err) => return Err(err),
    }
    check_owner()?;
    let val = portal_json_get(session, PORTAL_ITEMS).await?;
    let items_map = network_account::parse_portal_items(&val)?;
    check_owner()?;

    let (net_fee_minor, net_fee_failure) = match items_map.get(KEY_NET_FEE) {
        Some(Ok(id)) => {
            check_owner()?;
            let res = fetch_portal_detail(session, id)
                .await
                .and_then(|metric| network_account::parse_net_fee_minor(&metric));
            check_owner()?;
            match res {
                Ok(minor) => (Some(minor), None),
                Err(err) => (None, Some(err.code)),
            }
        }
        Some(Err(err)) => (None, Some(err.code.clone())),
        None => (None, Some(ErrorCode::ChangedResponse)),
    };

    let unreturned_books = match items_map.get(KEY_BOOK_NUM) {
        Some(Ok(id)) => {
            check_owner()?;
            let res = fetch_portal_detail(session, id).await.and_then(|metric| {
                let _ = network_account::parse_non_negative_count(&metric)?;
                Ok(metric)
            });
            check_owner()?;
            res.ok()
        }
        _ => None,
    };

    let unread_mail = match items_map.get(KEY_MAIL_UNREAD) {
        Some(Ok(id)) => {
            check_owner()?;
            let res = fetch_portal_detail(session, id).await.and_then(|metric| {
                let _ = network_account::parse_non_negative_count(&metric)?;
                Ok(metric)
            });
            check_owner()?;
            res.ok()
        }
        _ => None,
    };

    let cloud_drive_free = match items_map.get(KEY_CLOUD_DRIVE) {
        Some(Ok(id)) => {
            check_owner()?;
            let res = fetch_portal_detail(session, id).await;
            check_owner()?;
            res.ok()
        }
        _ => None,
    };

    Ok(PortalMetricsSnapshot {
        net_fee_minor,
        net_fee_failure,
        unreturned_books,
        unread_mail,
        cloud_drive_free,
    })
}

pub(crate) async fn bootstrap_zfw<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {
    let mut current = ZFW_CAS_START.to_owned();
    for _ in 0..10 {
        let mut req = HttpRequest::get(&current)
            .header("User-Agent", DESKTOP_UA)
            .header("Accept", "text/html,*/*")
            .header("Referer", ZFW_HOME);
        req.response_limit = Some(HTML_LIMIT);
        let resp = session.send_with_fallback(req).await?;
        check_gateway_response(&resp)?;
        if matches!(resp.status, 301 | 302 | 303 | 307 | 308) {
            let location = resp.header("location").ok_or_else(AppError::changed)?;
            current = resolve_https_target(location, &resp.final_url, "zfw.buaa.edu.cn")?.into();
            continue;
        }
        if resp.status == 401 {
            return Err(AppError::session_expired());
        }
        if resp.status == 403 {
            return Err(AppError::module_auth_required());
        }
        if resp.status != 200 {
            return Err(AppError::unavailable());
        }
        let landed = url::Url::parse(&resp.final_url).map_err(|_| AppError::changed())?;
        if landed.host_str() == Some("sso.buaa.edu.cn")
            || cas::is_login_redirect(&resp.final_url, &resp.body)
        {
            return Err(AppError::session_expired());
        }
        if landed.host_str() == Some("zfw.buaa.edu.cn")
            && landed.path().trim_end_matches('/') != "/login"
            && !resp.body.contains("/sso/cas/index")
        {
            return Ok(());
        }
        return Err(AppError::module_auth_required());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

async fn read_zfw_home_once<T: HttpTransport>(
    session: &Session<T>,
) -> Result<Vec<NetworkTrafficProduct>, AppError> {
    let mut req = HttpRequest::get(ZFW_HOME)
        .header("User-Agent", DESKTOP_UA)
        .header("Accept", "text/html,*/*")
        .header("Referer", ZFW_PAY_CARD);
    req.response_limit = Some(HTML_LIMIT);
    let resp = session.send_with_fallback(req).await?;
    check_gateway_response(&resp)?;
    if matches!(resp.status, 301 | 302 | 303 | 307 | 308 | 401 | 403) {
        return Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "zfw_login_required",
        ));
    }
    if resp.status != 200 {
        return Err(AppError::unavailable());
    }
    let landed = url::Url::parse(&resp.final_url).map_err(|_| AppError::changed())?;
    if landed.host_str() != Some("zfw.buaa.edu.cn")
        || landed.path().trim_end_matches('/') != "/home"
        || cas::is_login_redirect(&resp.final_url, &resp.body)
        || resp.body.contains("/sso/cas/index")
    {
        return Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "zfw_login_required",
        ));
    }
    network_account::parse_traffic_html(&resp.body)
}

pub(crate) async fn fetch_traffic<T: HttpTransport>(
    session: &Session<T>,
    check_owner: impl Fn() -> Result<(), AppError>,
) -> Result<Vec<NetworkTrafficProduct>, AppError> {
    check_owner()?;
    match read_zfw_home_once(session).await {
        Ok(products) => {
            check_owner()?;
            Ok(products)
        }
        Err(err) if err.detail.as_deref() == Some("zfw_login_required") => {
            bootstrap_zfw(session).await?;
            check_owner()?;
            let products = read_zfw_home_once(session).await?;
            check_owner()?;
            Ok(products)
        }
        Err(err) => Err(err),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::MockTransport;
    use serde_json::json;

    #[tokio::test]
    async fn bootstraps_portal_on_10013_and_isolates_single_metric_failure() {
        let transport =
            MockTransport::with_responses(vec![
            HttpResponse::new(200, PORTAL_INFO, json!({"e": 10013, "m": "no login"}).to_string()),
            HttpResponse::new(302, PORTAL_LOGIN_START, "")
                .with_header("Location", "/manage/common/cas_login/30001"),
            HttpResponse::new(
                302,
                "https://it.buaa.edu.cn/manage/common/cas_login/30001",
                "",
            )
            .with_header("Location", "https://it.buaa.edu.cn/home/"),
            HttpResponse::new(200, PORTAL_HOME, "<html>home</html>"),
            HttpResponse::new(
                200,
                PORTAL_INFO,
                json!({"e": 0, "d": {"info": {"identity": "研究生", "depart": "合成学院"}}})
                    .to_string(),
            ),
            HttpResponse::new(
                200,
                PORTAL_ITEMS,
                json!({
                    "e": 0,
                    "d": {
                        "data": [
                            {"key": "net.netFee", "id": 11},
                            {"key": "book.bookNum", "id": 12},
                            {"key": "mail.unread", "id": 13},
                            {"key": "wangPan.wangPan", "id": 14}
                        ]
                    }
                })
                .to_string(),
            ),
            HttpResponse::new(
                200,
                "https://it.buaa.edu.cn/personal/frontend/data/detail?id=11",
                json!({"e": 0, "d": {"data": {"value": "25.80", "unit": "元"}}}).to_string(),
            ),
            HttpResponse::new(
                200,
                "https://it.buaa.edu.cn/personal/frontend/data/detail?id=12",
                json!({"e": 0, "d": {"data": {"value": 2}}}).to_string(),
            ),
            // Mail endpoint returns non-zero business code: must not discard netFee or books!
            HttpResponse::new(
                200,
                "https://it.buaa.edu.cn/personal/frontend/data/detail?id=13",
                json!({"e": 500, "m": "mail down"}).to_string(),
            ),
            HttpResponse::new(
                200,
                "https://it.buaa.edu.cn/personal/frontend/data/detail?id=14",
                json!({"e": 0, "d": {"data": {"value": "98.5", "unit": "G", "account": "secret"}}})
                    .to_string(),
            ),
        ]);
        let session = Session::new(transport.clone());
        let snap = fetch_portal_metrics(&session, || Ok(()))
            .await
            .expect("portal metrics");
        assert_eq!(snap.net_fee_minor, Some(2580));
        assert!(snap.net_fee_failure.is_none());
        assert_eq!(
            snap.unreturned_books.as_ref().map(|v| v.value.as_str()),
            Some("2")
        );
        assert!(snap.unread_mail.is_none());
        assert_eq!(
            snap.cloud_drive_free.as_ref().map(|v| v.value.as_str()),
            Some("98.5")
        );
        let requests = transport.requests();
        assert_eq!(requests[1].url, PORTAL_LOGIN_START);
        assert_eq!(requests[1].header_value("Referer"), Some(PORTAL_HOME));
    }

    #[tokio::test]
    async fn bootstraps_zfw_on_redirect_and_reads_home_traffic_without_recharge_post() {
        let traffic_html = r#"
        <table>
          <thead><tr>
            <th data-col-seq="0">产品名称</th>
            <th data-col-seq="1">已用流量</th>
            <th data-col-seq="2">免费流量剩余(不含套餐)</th>
            <th data-col-seq="3">计费流量剩余(不含套餐)</th>
          </tr></thead>
          <tbody><tr>
            <td data-col-seq="0">学生网</td>
            <td data-col-seq="1">5.5G</td>
            <td data-col-seq="2">24.5G</td>
            <td data-col-seq="3">0G</td>
          </tr></tbody>
        </table>
        "#;
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, ZFW_HOME, "").with_header("Location", "/sso/cas/index"),
            HttpResponse::new(302, ZFW_CAS_START, "")
                .with_header("Location", "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fzfw.buaa.edu.cn%2Fsso%2Fcas%2Findex"),
            HttpResponse::new(
                302,
                "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fzfw.buaa.edu.cn%2Fsso%2Fcas%2Findex",
                "",
            )
            .with_header("Location", "https://zfw.buaa.edu.cn/sso/cas/index?ticket=ST-1"),
            HttpResponse::new(302, "https://zfw.buaa.edu.cn/sso/cas/index?ticket=ST-1", "")
                .with_header("Location", "/pay/card"),
            HttpResponse::new(200, ZFW_PAY_CARD, "<html>card landing</html>"),
            HttpResponse::new(200, ZFW_HOME, traffic_html),
        ]);
        let session = Session::new(transport.clone());
        let rows = fetch_traffic(&session, || Ok(())).await.expect("traffic");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].free_remaining_text, "24.5G");
        for req in transport.requests() {
            assert_eq!(req.method, crate::foundation::http::HttpMethod::Get);
        }
    }
}
