//! SPOC assignment pagination request (API.md §7.1).
use crate::{
    auth::{cas, session::Session},
    codecs::homework::{self, HomeworkPage},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};

pub const SPOC_BASE: &str = "https://spoc.buaa.edu.cn/spocnewht";
pub const ASSIGNMENT_SQL_ID: &str = "1713252980496efac7d5d9985e81693116d3e8a52ebf2b";
const DESKTOP_UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpocAuth {
    pub token: String,
    pub role: String,
}

pub async fn load_page<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    term_code: &str,
    page: i32,
) -> Result<HomeworkPage, AppError> {
    if auth.token.trim().is_empty()
        || auth.role.trim().is_empty()
        || term_code.trim().is_empty()
        || !(1..=100).contains(&page)
    {
        return Err(AppError::invalid());
    }
    let plain = page_payload(term_code, page);
    let encoded = homework::encrypt_page_param(&plain);
    let body = serde_json::json!({"param": encoded}).to_string();
    let request = headers(
        HttpRequest::post_form(format!("{SPOC_BASE}/inco/ht/queryListByPage"), body)
            .header("Content-Type", "application/json"),
        auth,
    );
    let response = session.send_with_fallback(request).await?;
    let page_data = decode_page(&response)?;
    if page_data.page_num != page {
        return Err(AppError::with_detail(
            ErrorCode::ChangedResponse,
            "spoc_page_num",
        ));
    }
    Ok(page_data)
}

pub fn page_payload(term_code: &str, page: i32) -> String {
    format!(
        r#"{{"pageSize":15,"pageNum":{page},"sqlid":"{ASSIGNMENT_SQL_ID}","xnxq":{term},"kcid":"","yzwz":""}}"#,
        term = serde_json::Value::String(term_code.to_owned())
    )
}

/// Classify a SPOC answer that is not the expected JSON.
fn classify_refusal(response: &HttpResponse) -> AppError {
    cas::module_refusal(&response.final_url, &response.body)
}

fn decode_page(response: &HttpResponse) -> Result<HomeworkPage, AppError> {
    check_gateway(response)?;
    if matches!(response.status, 401 | 403) {
        return Err(classify_refusal(response));
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    if response.body.trim_start().starts_with('<') {
        return Err(classify_refusal(response));
    }
    let value: serde_json::Value = serde_json::from_str(&response.body)
        .map_err(|_| AppError::with_detail(ErrorCode::ChangedResponse, "spoc_page_json"))?;
    homework::parse_page(homework::content(&value)?.clone())
}

// API.md §7.1 and SpocHomeworkClient.swift: SPA -> full CAS callback -> role.
pub async fn authenticate<T: HttpTransport>(session: &Session<T>) -> Result<SpocAuth, AppError> {
    // Match Swift's best-effort landing warmup so a transient SPA page hiccup
    // never aborts the actual CAS ticket exchange, while avoiding a second
    // 10s connect timeout when the host is already unreachable on this route.
    if let Err(err) = follow_spoc_redirects(
        session,
        HttpRequest::get("https://spoc.buaa.edu.cn/spocnew/")
            .header("User-Agent", DESKTOP_UA)
            .header("Accept", "text/html,application/xhtml+xml"),
    )
    .await
    {
        if matches!(
            err.code,
            ErrorCode::NetworkUnreachable
                | ErrorCode::ModuleAuthRequired
                | ErrorCode::AccessPolicyDenied
        ) {
            return Err(err);
        }
    }
    let (callback, redirected_token) = follow_spoc_redirects(
        session,
        HttpRequest::get(format!("{SPOC_BASE}/cas"))
            .header("User-Agent", DESKTOP_UA)
            .header("Accept", "text/html,application/xhtml+xml"),
    )
    .await?;
    check_gateway(&callback)?;
    let url = url::Url::parse(&callback.final_url)
        .map_err(|_| AppError::with_detail(ErrorCode::ChangedResponse, "spoc_callback_url"))?;
    let token = extract_spoc_token(&url)
        .or(redirected_token)
        .ok_or_else(AppError::session_expired)?;
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(
                format!("{SPOC_BASE}/sys/casLogin"),
                serde_json::json!({"token": token}).to_string(),
            )
            .header("User-Agent", DESKTOP_UA)
            .header("Content-Type", "application/json")
            .header("Token", &format!("Inco-{token}"))
            .header("X-Requested-With", "XMLHttpRequest")
            .header("Accept", "application/json, text/javascript, */*; q=0.01"),
        )
        .await?;
    let value = decode(&response)?;
    let role_data = homework::content(&value)?;
    fn role(value: &serde_json::Value) -> Option<String> {
        match value {
            serde_json::Value::String(s) if !s.is_empty() => Some(s.clone()),
            serde_json::Value::Number(n) => Some(n.to_string()),
            serde_json::Value::Array(items) => items.iter().find_map(role),
            _ => None,
        }
    }
    // The school's SPA presents role[].jsmc and sends the selected jsdm as
    // RoleCode. Prefer an explicitly named student role; never guess numeric
    // codes or infer per-course membership from the account-level role.
    let student_role = role_data["role"].as_array().and_then(|roles| {
        roles.iter().find_map(|item| {
            let label = item["jsmc"].as_str()?.trim();
            matches!(label, "学生" | "本科生" | "研究生")
                .then(|| role(&item["jsdm"]))
                .flatten()
        })
    });
    let code = student_role
        .or_else(|| {
            ["jsdm", "rolecode", "jsdmList"]
                .iter()
                .find_map(|key| role(&role_data[key]))
                .or_else(|| {
                    role_data["role"]
                        .as_array()?
                        .iter()
                        .find_map(|item| role(&item["jsdm"]))
                })
        })
        .ok_or_else(|| AppError::with_detail(ErrorCode::ChangedResponse, "spoc_role_missing"))?;
    Ok(SpocAuth { token, role: code })
}

fn decode(response: &HttpResponse) -> Result<serde_json::Value, AppError> {
    check_gateway(response)?;
    if matches!(response.status, 401 | 403) || response.body.trim_start().starts_with('<') {
        return Err(classify_refusal(response));
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    serde_json::from_str(&response.body)
        .map_err(|_| AppError::with_detail(ErrorCode::ChangedResponse, "spoc_decode_json"))
}

async fn get<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    path: &str,
) -> Result<serde_json::Value, AppError> {
    let (response, _) = follow_spoc_redirects(
        session,
        headers(HttpRequest::get(format!("{SPOC_BASE}{path}")), auth),
    )
    .await?;
    let value = decode(&response)?;
    Ok(homework::content(&value)?.clone())
}

fn headers(request: HttpRequest, auth: &SpocAuth) -> HttpRequest {
    request
        .header("User-Agent", DESKTOP_UA)
        .header("Token", &format!("Inco-{}", auth.token))
        .header("RoleCode", &auth.role)
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Accept", "application/json, text/javascript, */*; q=0.01")
}

pub async fn load<T: HttpTransport>(
    session: &Session<T>,
) -> Result<homework::HomeworkData, AppError> {
    let auth = authenticate(session).await?;
    let param =
        "YHrxtTavu6raCwC0/qdgYffB9evWHBkTng/XS4W6j3f/TPo02iEPSoegscDTRNzIPRG49o3RHl4JiFCXAiBkkA==";
    let response = session
        .send_with_fallback(headers(
            HttpRequest::post_form(
                format!("{SPOC_BASE}/inco/ht/queryOne"),
                serde_json::json!({"param":param}).to_string(),
            )
            .header("Content-Type", "application/json"),
            &auth,
        ))
        .await?;
    let value = decode(&response)?;
    let term = homework::content(&value)?;
    let code = term["mrxq"]
        .as_str()
        .filter(|s| !s.is_empty())
        .ok_or_else(|| AppError::with_detail(ErrorCode::ChangedResponse, "spoc_term_mrxq"))?;
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("kcmc", "")
        .append_pair("xnxq", code)
        .finish();
    let courses = get(session, &auth, &format!("/jxkj/queryKclb?{query}")).await?;
    homework::apply_course_context(&mut [], &courses)?;
    let mut items = Vec::new();
    let mut ids = std::collections::BTreeSet::new();
    for number in 1..=100 {
        let mut page = load_page(session, &auth, code, number).await?;
        homework::apply_course_context(&mut page.items, &courses)?;
        let has_next = page
            .has_next
            .unwrap_or_else(|| page.pages.is_some_and(|pages| number < pages));
        for item in page.items {
            if !ids.insert(item.id.clone()) {
                return Err(AppError::with_detail(
                    ErrorCode::ChangedResponse,
                    "spoc_dup_item",
                ));
            }
            items.push(item);
        }
        if !has_next {
            // Combine all three SPOC course-role signals without letting a
            // student-scoped `queryKclb` `juese` skip TA verification:
            // 1. `/kc/queryXskcListPage` + `/kc/queryZjkcListPage` (mycourse/index)
            // 2. `/kc/queryYhSflx?kcid=...` (coursecenter/index canonical ACL:
            //    "1"/"6"=teacher, "3"=assistant, "2"=student)
            // 3. `/jxkj/queryKclb` `juese` ("1"=teacher, "2"=assistant, "3"=student)
            // Classification is optional: errors never erase assignments.
            let unique_course_ids: Vec<String> = items
                .iter()
                .filter_map(|item| item.course_id.clone())
                .collect::<std::collections::BTreeSet<_>>()
                .into_iter()
                .take(30)
                .collect();
            let (lists_complete, students, assistants, sflx_roles) =
                match tokio::time::timeout(std::time::Duration::from_secs(12), async {
                    tokio::join!(
                        course_ids(session, &auth, "/kc/queryXskcListPage"),
                        course_ids(session, &auth, "/kc/queryZjkcListPage"),
                        query_course_sflx_roles(session, &auth, &unique_course_ids),
                    )
                })
                .await
                {
                    Ok((Ok(students), Ok(assistants), sflx)) => (true, students, assistants, sflx),
                    Ok((Ok(students), Err(_), sflx)) => {
                        (false, students, std::collections::BTreeSet::new(), sflx)
                    }
                    Ok((Err(_), Ok(assistants), sflx)) => {
                        (false, std::collections::BTreeSet::new(), assistants, sflx)
                    }
                    Ok((Err(_), Err(_), sflx)) => (
                        false,
                        std::collections::BTreeSet::new(),
                        std::collections::BTreeSet::new(),
                        sflx,
                    ),
                    Err(_) => (
                        false,
                        std::collections::BTreeSet::new(),
                        std::collections::BTreeSet::new(),
                        std::collections::BTreeMap::new(),
                    ),
                };
            apply_course_roles_with_sflx(&mut items, &students, &assistants, &sflx_roles);
            let sflx_complete = !unique_course_ids.is_empty()
                && unique_course_ids
                    .iter()
                    .all(|id| sflx_roles.contains_key(id));
            let roles_complete = lists_complete || sflx_complete;
            return Ok(homework::HomeworkData {
                term_code: code.to_owned(),
                term_name: term["dqxq"].as_str().unwrap_or("").to_owned(),
                items,
                roles_complete,
            });
        }
    }
    Err(AppError::changed())
}

async fn query_course_sflx<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    course_id: &str,
) -> Option<&'static str> {
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("kcid", course_id)
        .finish();
    let value = get(session, auth, &format!("/kc/queryYhSflx?{query}"))
        .await
        .ok()?;
    let raw = match &value {
        serde_json::Value::String(s) => s.trim().to_owned(),
        serde_json::Value::Number(n) => n.to_string(),
        _ => return None,
    };
    match raw.as_str() {
        "1" | "6" => Some("teacher"),
        "3" => Some("assistant"),
        "2" => Some("student"),
        _ => None,
    }
}

async fn query_course_sflx_roles<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    course_ids: &[String],
) -> std::collections::BTreeMap<String, &'static str> {
    let mut roles = std::collections::BTreeMap::new();
    for chunk in course_ids.chunks(4) {
        match chunk {
            [a] => {
                if let Some(role) = query_course_sflx(session, auth, a).await {
                    roles.insert(a.clone(), role);
                }
            }
            [a, b] => {
                let (ra, rb) = tokio::join!(
                    query_course_sflx(session, auth, a),
                    query_course_sflx(session, auth, b),
                );
                for (id, role) in [(a, ra), (b, rb)] {
                    if let Some(role) = role {
                        roles.insert(id.clone(), role);
                    }
                }
            }
            [a, b, c] => {
                let (ra, rb, rc) = tokio::join!(
                    query_course_sflx(session, auth, a),
                    query_course_sflx(session, auth, b),
                    query_course_sflx(session, auth, c),
                );
                for (id, role) in [(a, ra), (b, rb), (c, rc)] {
                    if let Some(role) = role {
                        roles.insert(id.clone(), role);
                    }
                }
            }
            [a, b, c, d] => {
                let (ra, rb, rc, rd) = tokio::join!(
                    query_course_sflx(session, auth, a),
                    query_course_sflx(session, auth, b),
                    query_course_sflx(session, auth, c),
                    query_course_sflx(session, auth, d),
                );
                for (id, role) in [(a, ra), (b, rb), (c, rc), (d, rd)] {
                    if let Some(role) = role {
                        roles.insert(id.clone(), role);
                    }
                }
            }
            _ => {}
        }
    }
    roles
}

#[cfg(test)]
fn apply_course_roles(
    items: &mut [homework::HomeworkItem],
    students: &std::collections::BTreeSet<String>,
    assistants: &std::collections::BTreeSet<String>,
) {
    apply_course_roles_with_sflx(
        items,
        students,
        assistants,
        &std::collections::BTreeMap::new(),
    );
}

fn apply_course_roles_with_sflx(
    items: &mut [homework::HomeworkItem],
    students: &std::collections::BTreeSet<String>,
    assistants: &std::collections::BTreeSet<String>,
    sflx_roles: &std::collections::BTreeMap<String, &'static str>,
) {
    for item in items {
        let Some(id) = item.course_id.as_deref() else {
            continue;
        };
        if let Some(role) = sflx_roles.get(id) {
            item.course_role = Some((*role).into());
            continue;
        }
        if matches!(item.course_role.as_deref(), Some("assistant" | "teacher")) {
            continue;
        }
        if assistants.contains(id) && !students.contains(id) {
            item.course_role = Some("assistant".into());
        } else if students.contains(id) {
            item.course_role = Some("student".into());
        }
    }
}

pub(crate) async fn course_ids<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    path: &str,
) -> Result<std::collections::BTreeSet<String>, AppError> {
    let mut ids = std::collections::BTreeSet::new();
    for page in 1..=100 {
        let value = get(
            session,
            auth,
            &format!("{path}?pageSize=100&pageNum={page}"),
        )
        .await?;
        let empty = Vec::new();
        let rows = match value.get("list") {
            Some(serde_json::Value::Array(list)) => list,
            Some(serde_json::Value::Null) => &empty,
            _ => return Err(AppError::changed()),
        };
        for row in rows {
            let id = match row.get("kcid") {
                Some(serde_json::Value::String(id)) if !id.trim().is_empty() => id.clone(),
                Some(serde_json::Value::Number(num)) => num.to_string(),
                _ => return Err(AppError::changed()),
            };
            ids.insert(id);
        }
        let has_next = match value.get("hasNextPage") {
            Some(serde_json::Value::Bool(next)) => *next,
            None | Some(serde_json::Value::Null) => rows.len() >= 100,
            _ => return Err(AppError::changed()),
        };
        if !has_next {
            return Ok(ids);
        }
    }
    Err(AppError::changed())
}

pub async fn load_detail<T: HttpTransport>(
    session: &Session<T>,
    id: &str,
) -> Result<homework::HomeworkDetail, AppError> {
    if id.trim().is_empty() {
        return Err(AppError::invalid());
    }
    let auth = authenticate(session).await?;
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("id", id)
        .finish();
    let assignment = get(session, &auth, &format!("/kczy/queryKczyInfoByid?{query}")).await?;
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("kczyid", id)
        .finish();
    let submission = get(
        session,
        &auth,
        &format!("/kczy/queryXsSubmitKczyInfo?{query}"),
    )
    .await?;
    homework::parse_detail(
        &serde_json::json!({"assignment":{"code":200,"content":assignment},"submission":{"code":200,"content":submission}}),
    )
}

fn is_gateway_login_url(raw: &str) -> bool {
    url::Url::parse(raw).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|h| h.eq_ignore_ascii_case(crate::foundation::webvpn::GATEWAY_HOST))
            && url.path().trim_end_matches('/').ends_with("/login")
    })
}

fn check_gateway(response: &HttpResponse) -> Result<(), AppError> {
    if is_gateway_login_url(&response.final_url) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    if matches!(response.status, 301 | 302 | 303 | 307 | 308) {
        if let Some(location) = response.header("location") {
            let trimmed = location.trim();
            let joined = url::Url::parse(&response.final_url)
                .and_then(|base| base.join(trimmed))
                .ok();
            if is_gateway_login_url(trimmed)
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

/// Resolve a SPOC/SSO GET redirect. Like `evaluation_http` on the same
/// `spoc.buaa.edu.cn` host, INCO/Spring behind TLS-terminating nginx may emit
/// `http://spoc.buaa.edu.cn/...` callbacks; safely upgrade only `spoc.buaa.edu.cn`
/// and `sso.buaa.edu.cn/login` to HTTPS on default ports.
fn resolve_spoc_redirect(location: &str, base: &str) -> Result<String, AppError> {
    let resolved =
        crate::foundation::webvpn::resolve_redirect(location, base).ok_or_else(|| {
            AppError::with_detail(ErrorCode::ChangedResponse, "spoc_redirect_resolve")
        })?;
    if is_gateway_login_url(&resolved) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    crate::auth::redirect::reject_reported_error(&resolved)?;
    let mut parsed = url::Url::parse(&resolved)
        .map_err(|_| AppError::with_detail(ErrorCode::ChangedResponse, "spoc_redirect_url"))?;
    if !parsed.username().is_empty() || parsed.password().is_some() {
        return Err(AppError::with_detail(
            ErrorCode::ChangedResponse,
            "spoc_redirect_userinfo",
        ));
    }
    let allowed = match parsed.scheme() {
        "https" => {
            parsed.port_or_known_default() == Some(443)
                && matches!(
                    parsed.host_str(),
                    Some("spoc.buaa.edu.cn" | "sso.buaa.edu.cn")
                )
        }
        "http" => {
            parsed.port_or_known_default() == Some(80)
                && match parsed.host_str() {
                    Some("spoc.buaa.edu.cn") => true,
                    Some("sso.buaa.edu.cn") => parsed.path() == "/login",
                    _ => false,
                }
        }
        _ => false,
    };
    if !allowed {
        let tag = match parsed.scheme() {
            "https" => "spoc_redirect_https_host",
            "http" => "spoc_redirect_http_host",
            _ => "spoc_redirect_scheme",
        };
        return Err(AppError::with_detail(ErrorCode::ChangedResponse, tag));
    }
    if parsed.scheme() == "http" {
        parsed
            .set_scheme("https")
            .map_err(|()| AppError::changed())?;
        parsed.set_port(None).map_err(|()| AppError::changed())?;
    }
    Ok(parsed.into())
}

async fn follow_spoc_redirects<T: HttpTransport>(
    session: &Session<T>,
    initial: HttpRequest,
) -> Result<(HttpResponse, Option<String>), AppError> {
    let mut current = initial;
    let mut seen_token: Option<String> = None;
    for _ in 0..10 {
        let negotiation: Vec<_> = current
            .headers
            .iter()
            .filter(|(name, _)| {
                ["user-agent", "accept", "accept-language"]
                    .iter()
                    .any(|allowed| name.eq_ignore_ascii_case(allowed))
            })
            .map(|(name, value)| (name.clone(), value.clone()))
            .collect();
        let response = session.send_with_fallback(current).await?;
        check_gateway(&response)?;
        if let Ok(parsed) = url::Url::parse(&response.final_url) {
            if parsed.host_str() == Some("spoc.buaa.edu.cn") {
                if let Some(token) = extract_spoc_token(&parsed) {
                    seen_token = Some(token);
                }
            }
        }
        if !(300..400).contains(&response.status) {
            return Ok((response, seen_token));
        }
        let Some(location) = response.header("location") else {
            return Ok((response, seen_token));
        };
        let next = resolve_spoc_redirect(location, &response.final_url)?;
        if let Ok(parsed) = url::Url::parse(&next) {
            if parsed.host_str() == Some("spoc.buaa.edu.cn") {
                if let Some(token) = extract_spoc_token(&parsed) {
                    seen_token = Some(token);
                }
            }
        }
        current = HttpRequest::get(next);
        current.headers.extend(negotiation);
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

fn extract_spoc_token(url: &url::Url) -> Option<String> {
    if let Some((_, value)) = url
        .query_pairs()
        .find(|(key, value)| key == "token" && !value.is_empty())
    {
        return Some(value.into_owned());
    }
    let fragment = url.fragment()?;
    let (_, query) = fragment.split_once('?')?;
    url::form_urlencoded::parse(query.as_bytes())
        .find(|(key, value)| key == "token" && !value.is_empty())
        .map(|(_, value)| value.into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        foundation::http::{HttpMethod, HttpResponse},
        test_support::MockTransport,
    };
    use serde_json::{json, Value};

    fn content(name: &str) -> Value {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../fixtures/homework")
            .join(name);
        let fixture: Value =
            serde_json::from_str(&std::fs::read_to_string(path).expect("fixture")).expect("json");
        fixture["input"]["body"].clone()
    }

    fn auth() -> SpocAuth {
        SpocAuth {
            token: "fixture-token".into(),
            role: "01".into(),
        }
    }
    #[test]
    fn per_course_membership_preserves_students_unknown_and_missing_ids() {
        let mut page = content("spoc-page-v1.json");
        page["list"] = json!([
            {"zyid":"student","zymc":"学生作业","sskcid":"student-course","kcmc":"合成课程"},
            {"zyid":"assistant","zymc":"助教作业","sskcid":"assistant-course","kcmc":"另一合成课程"},
            {"zyid":"unknown","zymc":"未知课程作业","sskcid":"unknown-course"},
            {"zyid":"missing","zymc":"缺少课程归属"}
        ]);
        let mut items = homework::parse_page(page).unwrap().items;
        let students = ["student-course".to_owned()].into();
        let assistants = ["student-course".to_owned(), "assistant-course".to_owned()].into();
        apply_course_roles(&mut items, &students, &assistants);
        assert_eq!(items[0].course_role.as_deref(), Some("student"));
        assert_eq!(items[1].course_role.as_deref(), Some("assistant"));
        assert_eq!(items[2].course_role, None);
        assert_eq!(items[3].course_role, None);

        // Authoritative role already assigned from `/jxkj/queryKclb` `juese`
        // must never be overwritten by fallback membership lists.
        items[1].course_role = Some("assistant".into());
        let all_students = ["student-course".to_owned(), "assistant-course".to_owned()].into();
        apply_course_roles(
            &mut items,
            &all_students,
            &std::collections::BTreeSet::new(),
        );
        assert_eq!(items[1].course_role.as_deref(), Some("assistant"));
    }

    #[tokio::test]
    async fn course_membership_paginates_and_rejects_ambiguous_shapes() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(
                200,
                "page-one",
                json!({"code":200,"content":{
                    "list":[{"kcid":"student-one"}], "hasNextPage":true
                }})
                .to_string(),
            ),
            HttpResponse::new(
                200,
                "page-two",
                json!({"code":200,"content":{
                    "list":[{"kcid":"student-two"}], "hasNextPage":false
                }})
                .to_string(),
            ),
            HttpResponse::new(
                200,
                "changed",
                json!({"code":200,"content":{
                    "list":[{"unexpected":"course-id"}]
                }})
                .to_string(),
            ),
        ]);
        let session = Session::new(transport.clone());
        let ids = course_ids(&session, &auth(), "/kc/queryXskcListPage")
            .await
            .unwrap();
        assert_eq!(ids.len(), 2);
        assert!(transport.requests()[1]
            .url
            .ends_with("pageSize=100&pageNum=2"));
        assert_eq!(
            course_ids(&session, &auth(), "/kc/queryZjkcListPage")
                .await
                .unwrap_err()
                .code,
            ErrorCode::ChangedResponse
        );
    }
    #[tokio::test]
    async fn explicit_student_role_wins_without_guessing_numeric_codes() {
        for (payload, expected) in [
            (
                json!({"jsdm": "teacher-code", "role": [
                    {"jsdm": "ta-code", "jsmc": "助教"},
                    {"jsdm": "student-code", "jsmc": "学生"}
                ]}),
                "student-code",
            ),
            (
                json!({"role": [{"jsdm": "ta-code", "jsmc": "助教"}]}),
                "ta-code",
            ),
            (
                json!({"jsdm": "existing-code", "role": [
                    {"jsdm": "unknown-code", "jsmc": "未知身份"}
                ]}),
                "existing-code",
            ),
        ] {
            let transport = MockTransport::with_responses(vec![
                HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
                HttpResponse::new(
                    404,
                    "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
                    "",
                ),
                HttpResponse::new(
                    200,
                    "role",
                    json!({"code":200,"content":payload}).to_string(),
                ),
            ]);
            assert_eq!(
                authenticate(&Session::new(transport)).await.unwrap().role,
                expected
            );
        }
    }

    #[tokio::test]
    async fn posts_encrypted_page_with_token_headers() {
        let envelope = json!({"code": 200, "content": content("spoc-page-v1.json")});
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            format!("{SPOC_BASE}/inco/ht/queryListByPage"),
            envelope.to_string(),
        )]);
        let session = Session::new(transport);
        let page = load_page(&session, &auth(), "2025-20262", 1)
            .await
            .expect("page");
        assert_eq!(page.items.len(), 2);

        let requests = session.transport().requests();
        let request = &requests[0];
        assert_eq!(request.method, HttpMethod::Post);
        assert_eq!(request.header_value("Token"), Some("Inco-fixture-token"));
        assert_eq!(request.header_value("RoleCode"), Some("01"));
        let body: Value =
            serde_json::from_str(request.body.as_deref().expect("body")).expect("json body");
        assert_eq!(
            body["param"],
            "hkJ9jAFVEMFUgJEjbOLv4eRZqXHIsmF+WbYaG1ipT1L1N+BbxRXtBj6Gcjri4Mo+y6q22/FkNm/isiC2+B+/hNejBx2cQJfNp9zoxorVJBa86sID0ROtPQ/2V07JCmVC3qsgIWBokL7EYyiPfilw+0ryJ6e61jRnLn90sQFosew="
        );
    }

    #[tokio::test]
    async fn unauthorized_envelope_demands_module_authentication() {
        // SPOC refused its own token. The shared school session is untouched,
        // so this must not be reported as a global session expiry.
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            format!("{SPOC_BASE}/inco/ht/queryListByPage"),
            r#"{"code":401,"content":null}"#,
        )]);
        assert_eq!(
            load_page(&Session::new(transport), &auth(), "2025-20262", 1)
                .await
                .expect_err("auth")
                .code,
            ErrorCode::ModuleAuthRequired
        );
    }

    #[tokio::test]
    async fn a_cas_login_page_is_still_a_global_session_expiry() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login",
            r#"<html><input name="execution" value="token"></html>"#,
        )]);
        assert_eq!(
            load_page(&Session::new(transport), &auth(), "2025-20262", 1)
                .await
                .expect_err("auth")
                .code,
            ErrorCode::SessionExpired
        );
    }

    #[tokio::test]
    async fn a_spoc_login_page_demands_module_authentication() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            format!("{SPOC_BASE}/inco/ht/queryListByPage"),
            "<html><body>请先登录 SPOC</body></html>",
        )]);
        assert_eq!(
            load_page(&Session::new(transport), &auth(), "2025-20262", 1)
                .await
                .expect_err("auth")
                .code,
            ErrorCode::ModuleAuthRequired
        );
    }

    #[tokio::test]
    async fn page_response_structure_change_is_reported() {
        let transport = MockTransport::with_responses(vec![HttpResponse::new(
            200,
            format!("{SPOC_BASE}/inco/ht/queryListByPage"),
            r#"{"code":200,"content":{"pageNum":1,"list":[{"zyid":"a"}]}}"#,
        )]);
        assert_eq!(
            load_page(&Session::new(transport), &auth(), "2025-20262", 1)
                .await
                .expect_err("changed")
                .code,
            ErrorCode::ChangedResponse
        );
    }
    #[tokio::test]
    async fn detail_ids_are_encoded_once_and_valid_absent_body_is_not_a_protocol_error() {
        // Golden shape from Swift loadDetailOnce / UBAA LocalSpocClient. A
        // missing optional zynr is independent of metadata/submission reads.
        let envelope = |content: Value| json!({"code": 200, "content": content}).to_string();
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                404,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
                "callback",
            ),
            HttpResponse::new(200, "role", envelope(json!({"rolecode": "01"}))),
            HttpResponse::new(
                200,
                "detail",
                envelope(
                    json!({"id": "synthetic", "zymc": "合成作业", "zykssj": "2026-10-01 08:00:00", "zyjzsj": "2026-10-08 23:59:00", "zyfs": "100"}),
                ),
            ),
            HttpResponse::new(
                200,
                "submission",
                envelope(json!({"tjzt": "1", "tjsj": "2026-10-02 09:00:00"})),
            ),
        ]);
        let detail = load_detail(&Session::new(transport.clone()), "synthetic+a/b%2F")
            .await
            .expect("metadata with optional absent body");
        assert!(detail.content.is_none());
        assert_eq!(detail.due_at.as_deref(), Some("2026-10-08 23:59:00"));
        assert_eq!(detail.score.as_deref(), Some("100"));
        assert_eq!(detail.status, homework::HomeworkStatus::Submitted);
        assert!(detail.submitted_at.is_some());
        let requests = transport.requests();
        for (index, key) in [(3, "id"), (4, "kczyid")] {
            let url = url::Url::parse(&requests[index].url).expect("detail url");
            assert_eq!(
                url.query_pairs().collect::<Vec<_>>(),
                [(key.into(), "synthetic+a/b%2F".into())]
            );
            assert!(requests[index].url.ends_with("synthetic%2Ba%2Fb%252F"));
        }
    }

    #[tokio::test]
    async fn authenticate_upgrades_http_spoc_callback_and_detects_webvpn_login_redirect() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(302, format!("{SPOC_BASE}/cas"), "").with_header(
                "Location",
                "http://spoc.buaa.edu.cn/spocnew/cas?token=fixture-http-token",
            ),
            HttpResponse::new(
                404,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture-http-token",
                "",
            ),
            HttpResponse::new(
                200,
                format!("{SPOC_BASE}/sys/casLogin"),
                json!({"code": 200, "content": {"rolecode": "01"}}).to_string(),
            ),
        ]);
        let auth = authenticate(&Session::new(transport.clone()))
            .await
            .expect("http spoc callback upgraded");
        assert_eq!(auth.token, "fixture-http-token");
        assert_eq!(auth.role, "01");
        assert_eq!(
            transport.requests()[2].url,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture-http-token"
        );

        let gateway_transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(302, format!("{SPOC_BASE}/cas"), "")
                .with_header("Location", "https://d.buaa.edu.cn/login"),
        ]);
        let err = authenticate(&Session::new(gateway_transport))
            .await
            .expect_err("gateway redirect");
        assert_eq!(err.code, ErrorCode::AccessPolicyDenied);
        assert_eq!(err.detail.as_deref(), Some("webvpn_login_required"));

        assert_eq!(
            resolve_spoc_redirect("http://evil.example/cas?token=x", SPOC_BASE)
                .expect_err("foreign host")
                .detail
                .as_deref(),
            Some("spoc_redirect_http_host")
        );
    }
}
