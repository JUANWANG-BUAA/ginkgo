//! SPOC assignment pagination request (API.md §7.1).
use crate::{
    auth::session::Session,
    features::homework::{self, HomeworkPage},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};

pub const SPOC_BASE: &str = "https://spoc.buaa.edu.cn/spocnewht";
pub const ASSIGNMENT_SQL_ID: &str = "1713252980496efac7d5d9985e81693116d3e8a52ebf2b";

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
    let request = HttpRequest::post_form(format!("{SPOC_BASE}/inco/ht/queryListByPage"), body)
        .header("Content-Type", "application/json")
        .header("Token", &format!("Inco-{}", auth.token))
        .header("RoleCode", &auth.role)
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Accept", "application/json, text/javascript, */*; q=0.01");
    let response = session.send_with_fallback(request).await?;
    let page_data = decode_page(&response)?;
    if page_data.page_num != page {
        return Err(AppError::changed());
    }
    Ok(page_data)
}

pub fn page_payload(term_code: &str, page: i32) -> String {
    format!(
        r#"{{"pageSize":15,"pageNum":{page},"sqlid":"{ASSIGNMENT_SQL_ID}","xnxq":{term},"kcid":"","yzwz":""}}"#,
        term = serde_json::Value::String(term_code.to_owned())
    )
}

fn decode_page(response: &HttpResponse) -> Result<HomeworkPage, AppError> {
    check_gateway(response)?;
    if matches!(response.status, 401 | 403) {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    if response.body.trim_start().starts_with('<') {
        return Err(AppError::session_expired());
    }
    let value: serde_json::Value =
        serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    homework::parse_page(homework::content(&value)?.clone())
}

// API.md §7.1 and SpocHomeworkClient.swift: SPA -> full CAS callback -> role.
pub async fn authenticate<T: HttpTransport>(session: &Session<T>) -> Result<SpocAuth, AppError> {
    let _ = session
        .send_following_redirects(HttpRequest::get("https://spoc.buaa.edu.cn/spocnew/"))
        .await?;
    let callback = session
        .send_following_redirects(HttpRequest::get(format!("{SPOC_BASE}/cas")))
        .await?;
    check_gateway(&callback)?;
    let url = url::Url::parse(&callback.final_url).map_err(|_| AppError::changed())?;
    let token = url
        .query_pairs()
        .find(|(key, value)| key == "token" && !value.is_empty())
        .map(|(_, value)| value.into_owned())
        .ok_or_else(AppError::session_expired)?;
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(
                format!("{SPOC_BASE}/sys/casLogin"),
                serde_json::json!({"token": token}).to_string(),
            )
            .header("Content-Type", "application/json")
            .header("Token", &format!("Inco-{token}")),
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
    let code = ["jsdm", "rolecode", "jsdmList"]
        .iter()
        .find_map(|key| role(&role_data[key]))
        .or_else(|| {
            role_data["role"]
                .as_array()?
                .iter()
                .find_map(|item| role(&item["jsdm"]))
        })
        .ok_or_else(AppError::changed)?;
    Ok(SpocAuth { token, role: code })
}

fn decode(response: &HttpResponse) -> Result<serde_json::Value, AppError> {
    check_gateway(response)?;
    if matches!(response.status, 401 | 403) || response.body.trim_start().starts_with('<') {
        return Err(AppError::session_expired());
    }
    if !(200..300).contains(&response.status) {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}

async fn get<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    path: &str,
) -> Result<serde_json::Value, AppError> {
    let response = session
        .send_following_redirects(headers(
            HttpRequest::get(format!("{SPOC_BASE}{path}")),
            auth,
        ))
        .await?;
    let value = decode(&response)?;
    Ok(homework::content(&value)?.clone())
}

fn headers(request: HttpRequest, auth: &SpocAuth) -> HttpRequest {
    request
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
        .ok_or_else(AppError::changed)?;
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
                return Err(AppError::changed());
            }
            items.push(item);
        }
        if !has_next {
            return Ok(homework::HomeworkData {
                term_code: code.to_owned(),
                term_name: term["dqxq"].as_str().unwrap_or("").to_owned(),
                items,
            });
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

fn check_gateway(response: &HttpResponse) -> Result<(), AppError> {
    if url::Url::parse(&response.final_url).is_ok_and(|url| {
        url.host_str() == Some(crate::foundation::webvpn::GATEWAY_HOST)
            && url.path().trim_end_matches('/').ends_with("/login")
    }) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    Ok(())
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
    async fn unauthorized_envelope_is_session_expired() {
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
            ErrorCode::SessionExpired
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
}
