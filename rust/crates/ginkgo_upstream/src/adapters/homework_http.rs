//! SPOC assignment pagination request (API.md §7.1).
use crate::{
    auth::session::Session,
    codecs::homework::{self, HomeworkPage},
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
            // Public SPA mycourse/index: getXsList -> queryXskcListPage,
            // getZhuJiaoList -> queryZjkcListPage (audit 2026-10-21).
            // Classification is optional: errors never erase assignments.
            // Optional course membership must not hold a complete assignment
            // list hostage to an unavailable role endpoint.
            if let Ok((Ok(students), Ok(assistants))) =
                tokio::time::timeout(std::time::Duration::from_secs(4), async {
                    tokio::join!(
                        course_ids(session, &auth, "/kc/queryXskcListPage"),
                        course_ids(session, &auth, "/kc/queryZjkcListPage"),
                    )
                })
                .await
            {
                apply_course_roles(&mut items, &students, &assistants);
            }
            return Ok(homework::HomeworkData {
                term_code: code.to_owned(),
                term_name: term["dqxq"].as_str().unwrap_or("").to_owned(),
                items,
            });
        }
    }
    Err(AppError::changed())
}

fn apply_course_roles(
    items: &mut [homework::HomeworkItem],
    students: &std::collections::BTreeSet<String>,
    assistants: &std::collections::BTreeSet<String>,
) {
    for item in items {
        item.course_role = item.course_id.as_ref().and_then(|id| {
            if students.contains(id) {
                Some("student".into())
            } else if assistants.contains(id) {
                Some("assistant".into())
            } else {
                None
            }
        });
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
        let rows = value["list"].as_array().ok_or_else(AppError::changed)?;
        for row in rows {
            let id = row["kcid"]
                .as_str()
                .filter(|id| !id.trim().is_empty())
                .ok_or_else(AppError::changed)?;
            ids.insert(id.to_owned());
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
}
