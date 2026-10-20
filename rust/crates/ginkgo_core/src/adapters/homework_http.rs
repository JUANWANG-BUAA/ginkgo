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
    decode_page(&response)
}

pub fn page_payload(term_code: &str, page: i32) -> String {
    format!(
        r#"{{"pageSize":15,"pageNum":{page},"sqlid":"{ASSIGNMENT_SQL_ID}","xnxq":"{term_code}","kcid":"","yzwz":""}}"#
    )
}

fn decode_page(response: &HttpResponse) -> Result<HomeworkPage, AppError> {
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
    let code = value
        .get("code")
        .and_then(|code| {
            code.as_i64()
                .or_else(|| code.as_str().and_then(|text| text.parse().ok()))
        })
        .ok_or_else(AppError::changed)?;
    if matches!(code, 401 | 403) {
        return Err(AppError::session_expired());
    }
    if code != 200 {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    let content = value
        .get("content")
        .cloned()
        .ok_or_else(AppError::changed)?;
    homework::parse_page(content)
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
