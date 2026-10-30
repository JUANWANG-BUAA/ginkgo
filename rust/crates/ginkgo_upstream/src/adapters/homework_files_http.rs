//! SPOC file protocol. No retry or redirect replay for mutations.
use super::homework_http::{self, SpocAuth, SPOC_BASE};
use crate::{
    auth::{cas, session::Session},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport},
    AppError, ErrorCode,
};
use ginkgo_domain::ports::*;
use md5::{Digest, Md5};
use serde_json::Value;
const FILE_BASE: &str = "https://spoc.buaa.edu.cn/inco-filesystem";
const CHUNK_SIZE: usize = 2_048_000;
fn headers(request: HttpRequest, auth: &SpocAuth) -> HttpRequest {
    request
        .header("Token", &format!("Inco-{}", auth.token))
        .header("RoleCode", &auth.role)
}
fn decode(response: HttpResponse) -> Result<Value, AppError> {
    if matches!(response.status, 401 | 403) || response.body.trim_start().starts_with('<') {
        return Err(cas::module_refusal(&response.final_url, &response.body));
    }
    if response.status / 100 != 2 {
        return Err(AppError::unavailable());
    }
    let value: Value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    // Only explicit numeric authentication codes; never infer logout from ordinary
    // business rejection text or conflate every HTTP-200 error with auth expiry.
    if matches!(value.get("code").and_then(Value::as_i64), Some(401 | 403)) {
        return Err(AppError::module_auth_required());
    }
    Ok(value)
}
fn content(value: Value) -> Result<Value, AppError> {
    if value["code"].as_i64() != Some(200) {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    value.get("content").cloned().ok_or_else(AppError::changed)
}
// File service acknowledgements can omit code on success. When present, an
// explicit rejection wins over contradictory deduplication or file metadata.
fn file_ack(value: &Value) -> Result<(), AppError> {
    if value
        .get("code")
        .is_some_and(|code| code.as_i64() != Some(200))
    {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    Ok(())
}
fn query(fields: &[(&str, &str)]) -> String {
    url::form_urlencoded::Serializer::new(String::new())
        .extend_pairs(fields.iter().copied())
        .finish()
}
fn text(value: &Value, key: &str) -> Option<String> {
    match value.get(key) {
        Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()),
        Some(Value::Number(n)) => Some(n.to_string()),
        _ => None,
    }
}
fn number(value: &Value, key: &str) -> Option<u32> {
    text(value, key)?.parse().ok()
}
pub(crate) struct Context {
    pub auth: SpocAuth,
    pub assignment: Value,
    pub workspace: HomeworkWorkspace,
    pub student_owned: bool,
}
pub(crate) async fn load<T: HttpTransport>(
    session: &Session<T>,
    id: &str,
) -> Result<Context, AppError> {
    if id.trim().is_empty() || id.len() > 256 || id.chars().any(char::is_control) {
        return Err(AppError::invalid());
    }
    let auth = homework_http::authenticate(session).await?;
    let assignment = content(decode(
        session
            .send(headers(
                HttpRequest::get(format!(
                    "{SPOC_BASE}/kczy/queryKczyInfoByid?{}",
                    query(&[("id", id)])
                )),
                &auth,
            ))
            .await?,
    )?)?;
    let submission = submission(session, &auth, id).await?;
    if !assignment.is_object() || !(submission.is_object() || submission.is_null()) {
        return Err(AppError::changed());
    }
    let extensions = text(&assignment, "xzwjlx")
        .unwrap_or_default()
        .split(',')
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.trim().trim_start_matches('.').to_lowercase())
        .collect();
    let methods: Vec<String> = text(&assignment, "bhtjlx")
        .unwrap_or_default()
        .split(',')
        .filter_map(|s| match s.trim() {
            "1" => Some("text"),
            "2" => Some("url"),
            "3" => Some("audio"),
            "4" => Some("annotation"),
            "5" => Some("file"),
            _ => None,
        })
        .map(str::to_owned)
        .collect();
    let limit = number(&assignment, "xztjcs");
    let count = if submission.is_null() {
        Some(0)
    } else {
        number(&submission, "ytjcs")
    };
    let reason = if text(&assignment, "zylx").as_deref() != Some("1") {
        Some("仅支持明确的个人作业，小组或未知类型请在官网提交")
    } else if text(&assignment, "sfzysjn").as_deref() != Some("1") {
        Some("作业未开放、已截止或开放状态未确认")
    } else if text(&assignment, "pyfs").as_deref() == Some("2") {
        Some("教师已完成打分，不可提交")
    } else if !methods.iter().any(|s| s == "file") {
        Some("本作业不支持文件提交")
    } else if limit.is_none() || count.is_none() || (limit != Some(9999) && count >= limit) {
        Some("提交次数不可用或已用尽")
    } else {
        None
    };
    let mut attachments = Vec::new();
    for (data, key, kind) in [
        (&assignment, "zyfjid", "teacher"),
        (&assignment, "pfbzwjid", "rubric"),
        (&assignment, "zswjid", "annotation"),
        (&submission, "scwjid", "submitted"),
        (&submission, "mtlywjid", "submitted"),
        (&submission, "pzwjid", "submitted"),
    ] {
        if let Some(file_id) = text(data, key) {
            attachments.push(HomeworkAttachment {
                id: file_id,
                name: kind.into(),
                kind: kind.into(),
            });
        }
    }
    if let Some(rows) = submission.get("fjxx2List").and_then(Value::as_array) {
        for row in rows {
            if let Some(id) = text(row, "id").or_else(|| text(row, "wjid")) {
                attachments.push(HomeworkAttachment {
                    id,
                    name: text(row, "wjysmc").unwrap_or_else(|| "feedback".into()),
                    kind: "feedback".into(),
                });
            }
        }
    }
    if attachments.len() > 32 {
        return Err(AppError::changed());
    }
    for attachment in &mut attachments {
        if let Ok(info) = file_info(session, &auth, &attachment.id).await {
            attachment.name = text(&info, "wjysmc")
                .or_else(|| text(&info, "fileName"))
                .unwrap_or_else(|| attachment.name.clone());
        }
    }
    let workspace = HomeworkWorkspace {
        assignment_id: format!("spoc:{id}"),
        allowed_methods: methods,
        allowed_extensions: extensions,
        submission_limit: limit,
        submitted_count: count,
        returned: text(&submission, "tjzt").as_deref() == Some("-99"),
        submitted_text: text(&submission, "wbsrnr"),
        feedback: text(&submission, "py"),
        attachments,
        can_submit_file: reason.is_none(),
        blocked_reason: reason.map(str::to_owned),
        file_limit_bytes: HOMEWORK_FILE_LIMIT as u64,
    };
    Ok(Context {
        auth,
        assignment,
        workspace,
        student_owned: false,
    })
}

pub(crate) async fn submission<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    id: &str,
) -> Result<Value, AppError> {
    content(decode(
        session
            .send(headers(
                HttpRequest::get(format!(
                    "{SPOC_BASE}/kczy/queryXsSubmitKczyInfo?{}",
                    query(&[("kczyid", id)])
                )),
                auth,
            ))
            .await?,
    )?)
}
async fn file_info<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    id: &str,
) -> Result<Value, AppError> {
    let response = session
        .send(headers(
            HttpRequest::post_form(
                format!(
                    "{FILE_BASE}/fileManagerSystem/queryFileById?{}",
                    query(&[("wjid", id)])
                ),
                String::new(),
            ),
            auth,
        ))
        .await?;
    let value = decode(response)?;
    if value.is_object() && text(&value, "wjysmc").is_some() {
        Ok(value)
    } else {
        Err(AppError::changed())
    }
}
pub(crate) fn course_id(context: &Context) -> Result<String, AppError> {
    text(&context.assignment, "sskcid").ok_or_else(AppError::changed)
}
pub(crate) fn accepts(workspace: &HomeworkWorkspace, name: &str) -> bool {
    let extension = name.rsplit('.').next().unwrap_or("").to_lowercase();
    workspace.can_submit_file
        && (workspace.allowed_extensions.is_empty()
            || workspace.allowed_extensions.iter().any(|e| e == &extension))
}

/// Resumable.js wire shape; no speculative GET probes and no automatic retry.
/// Server acknowledgement is not final submission success.
#[cfg(test)]
pub(crate) async fn upload<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    name: &str,
    bytes: &[u8],
) -> Result<String, AppError> {
    upload_checked(session, auth, name, bytes, || Ok(())).await
}
pub(crate) async fn upload_checked<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    name: &str,
    bytes: &[u8],
    check_owner: impl Fn() -> Result<(), AppError> + Send,
) -> Result<String, AppError> {
    validate_homework_file(name, bytes.len())?;
    let identifier = format!("{:x}", Md5::digest(bytes));
    // simple-uploader/Resumable defaults forceChunkSize=false: the last chunk
    // can contain the remainder plus one normal chunk (floor, not ceiling).
    let total = (bytes.len() / CHUNK_SIZE).max(1);
    for index in 0..total {
        check_owner()?;
        let start = index * CHUNK_SIZE;
        let end = if index + 1 == total {
            bytes.len()
        } else {
            (index + 1) * CHUNK_SIZE
        };
        let fields = vec![
            ("chunkNumber", (index + 1).to_string()),
            ("chunkSize", CHUNK_SIZE.to_string()),
            ("currentChunkSize", (end - start).to_string()),
            ("totalSize", bytes.len().to_string()),
            ("identifier", identifier.clone()),
            ("filename", name.into()),
            ("relativePath", name.into()),
            ("totalChunks", total.to_string()),
        ];
        let boundary = format!("ginkgo-{:032x}", rand::random::<u128>());
        let mut body = Vec::new();
        for (key, value) in fields {
            body.extend_from_slice(format!("--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{value}\r\n").as_bytes());
        }
        body.extend_from_slice(format!("--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\nContent-Type: application/octet-stream\r\n\r\n").as_bytes());
        body.extend_from_slice(&bytes[start..end]);
        body.extend_from_slice(format!("\r\n--{boundary}--\r\n").as_bytes());
        let mut request = headers(
            HttpRequest::new(
                crate::foundation::http::HttpMethod::Post,
                format!("{FILE_BASE}/fileManagerSystem/uploadFile"),
            ),
            auth,
        )
        .header(
            "Content-Type",
            &format!("multipart/form-data; boundary={boundary}"),
        );
        request.binary_body = Some(body);
        let response = decode(session.send(request).await?)?;
        check_owner()?;
        file_ack(&response)?;
        if response["mc"].as_bool() == Some(true) {
            return text(&response["data"], "id").ok_or_else(AppError::changed);
        }
        // Known chunk acknowledgement contains data array; do not merge a malformed reply.
        if response["data"].as_array().is_none() {
            return Err(AppError::changed());
        }
    }
    check_owner()?;
    let body = query(&[
        ("identifier", &identifier),
        ("filename", name),
        ("totalSize", &bytes.len().to_string()),
    ]);
    let response = decode(
        session
            .send(headers(
                HttpRequest::post_form(format!("{FILE_BASE}/fileManagerSystem/mergeFile"), body),
                auth,
            ))
            .await?,
    )?;
    check_owner()?;
    file_ack(&response)?;
    text(&response, "id").ok_or_else(AppError::changed)
}

pub(crate) async fn submit<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    id: &str,
    course: &str,
    file: &str,
    name: &str,
) -> Result<(), AppError> {
    let body = query(&[
        ("kczyid", id),
        ("tjfs", "5"),
        ("tjlx", "5"),
        ("ytjcs", "2"),
        ("sskcid", course),
        ("scwjid", file),
        ("scwjid_name", name),
    ]);
    let value = decode(
        session
            .send(headers(
                HttpRequest::post_form(format!("{SPOC_BASE}/kczy/submitKcz2"), body),
                auth,
            ))
            .await?,
    )?;
    content(value).map(|_| ())
}
pub(crate) async fn download<T: HttpTransport>(
    session: &Session<T>,
    auth: &SpocAuth,
    file: &str,
) -> Result<Vec<u8>, AppError> {
    let mut request = headers(
        HttpRequest::get(format!(
            "{FILE_BASE}/fileManagerSystem/downLoadFile?{}",
            query(&[("scjlid", file)])
        )),
        auth,
    );
    request.binary_response = true;
    request.response_limit = Some(HOMEWORK_FILE_LIMIT);
    // Intentionally refuse redirects: never leak Token to another origin.
    let response = session.send(request).await?;
    if response.status != 200
        || response
            .header("content-type")
            .is_some_and(|s| s.contains("text/html") || s.contains("application/json"))
    {
        return Err(AppError::unavailable());
    }
    let bytes = response.bytes.ok_or_else(AppError::changed)?;
    if bytes.len() > HOMEWORK_FILE_LIMIT {
        return Err(AppError::invalid());
    }
    Ok(bytes)
}
pub(crate) fn matches_file(submission: &Value, file: &str, baseline: u32) -> bool {
    text(submission, "tjlx").as_deref() == Some("5")
        && text(submission, "scwjid").as_deref() == Some(file)
        && number(submission, "ytjcs").is_some_and(|n| n > baseline)
}
