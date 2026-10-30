//! SPOC homework list parsing and pagination-parameter encryption.
//!
//! The AES-CBC + zero padding + Base64 shape is shared with the Apple client;
//! the golden vector comes from the existing Swift regression test.
use crate::AppError;
use aes::{
    cipher::{BlockEncrypt, KeyInit},
    Aes128,
};
use base64::{engine::general_purpose::STANDARD, Engine};
pub use ginkgo_domain::features::homework::*;
use serde_json::Value;

const KEY: &[u8; 16] = b"inco12345678ocni";
const IV: &[u8; 16] = b"ocni12345678inco";

pub fn encrypt_page_param(plain: &str) -> String {
    let mut data = plain.as_bytes().to_vec();
    let padding = (16 - data.len() % 16) % 16;
    data.extend(std::iter::repeat_n(0, padding));
    let cipher = Aes128::new(KEY.into());
    let mut previous = *IV;
    let mut encrypted = Vec::with_capacity(data.len());
    for chunk in data.chunks(16) {
        let mut block = [0u8; 16];
        for (index, byte) in chunk.iter().enumerate() {
            block[index] = byte ^ previous[index];
        }
        let mut block = aes::Block::from(block);
        cipher.encrypt_block(&mut block);
        previous = block.into();
        encrypted.extend_from_slice(&previous);
    }
    STANDARD.encode(encrypted)
}

pub fn parse_page(value: Value) -> Result<HomeworkPage, AppError> {
    let rows = value
        .get("list")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let page_num = value.get("pageNum").and_then(Value::as_i64).unwrap_or(1) as i32;
    let pages = value
        .get("pages")
        .and_then(Value::as_i64)
        .map(|pages| pages as i32);
    let has_next = value.get("hasNextPage").and_then(Value::as_bool);
    if let (Some(has_next), Some(pages)) = (has_next, pages) {
        if has_next != (page_num < pages) {
            return Err(AppError::changed());
        }
    }
    if pages.is_none() && has_next.is_none()
        || page_num < 1
        || pages.is_some_and(|pages| pages < page_num && !rows.is_empty())
    {
        return Err(AppError::changed());
    }
    let items = rows
        .iter()
        .map(|row| {
            let raw_id = required_string(row, "zyid")?;
            let title = required_string(row, "zymc")?;
            let (status, status_detail) = map_status(optional_string(row, "tjzt").as_deref());
            Ok(HomeworkItem {
                course_role: None,
                id: format!("spoc:{raw_id}"),
                course_id: optional_string(row, "sskcid"),
                course_name: optional_string(row, "kcmc")
                    .filter(|name| !name.trim().is_empty())
                    .unwrap_or_else(|| "SPOC 课程".into()),
                teacher_name: None,
                title,
                published_at: optional_string(row, "zykssj"),
                due_at: optional_string(row, "zyjzsj"),
                status,
                status_detail,
                score: optional_string(row, "mf"),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    Ok(HomeworkPage {
        page_num,
        pages,
        has_next,
        items,
    })
}

/// Course context uses kcid/kcmc/skjs, matching SpocHomeworkClient.Course.
/// Never infer the teacher from a title, list position or a different course.
pub fn apply_course_context(items: &mut [HomeworkItem], courses: &Value) -> Result<(), AppError> {
    let rows = courses.as_array().ok_or_else(AppError::changed)?;
    let mut context = std::collections::BTreeMap::new();
    for row in rows {
        let id = row["kcid"]
            .as_str()
            .filter(|s| !s.trim().is_empty())
            .ok_or_else(AppError::changed)?;
        let name = row["kcmc"]
            .as_str()
            .filter(|s| !s.trim().is_empty())
            .ok_or_else(AppError::changed)?;
        let teacher = match row.get("skjs") {
            None | Some(Value::Null) => None,
            Some(Value::String(value)) => Some(value.trim()).filter(|s| !s.is_empty()),
            _ => return Err(AppError::changed()),
        };
        if context.insert(id, (name, teacher)).is_some() {
            return Err(AppError::changed());
        }
    }
    for item in items {
        item.teacher_name = None;
        if let Some((name, teacher)) = item.course_id.as_deref().and_then(|id| context.get(id)) {
            if item.course_name == "SPOC 课程" {
                item.course_name = (*name).to_owned();
            }
            item.teacher_name = teacher.map(str::to_owned);
        }
    }
    Ok(())
}

fn map_status(raw: Option<&str>) -> (HomeworkStatus, Option<String>) {
    match raw.map(str::trim) {
        Some("1" | "已做" | "已提交") => (HomeworkStatus::Submitted, None),
        None | Some("" | "0" | "未做" | "未提交") => (HomeworkStatus::Pending, None),
        Some(value) => (HomeworkStatus::Unknown, Some(value.to_string())),
    }
}

fn required_string(row: &Value, key: &str) -> Result<String, AppError> {
    optional_string(row, key)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(AppError::changed)
}

fn optional_string(row: &Value, key: &str) -> Option<String> {
    match row.get(key)? {
        Value::String(value) => Some(value.clone()),
        Value::Number(number) => Some(number.to_string()),
        _ => None,
    }
}

/// SPOC envelope success is 200 (API.md §7.1), independent of other portals.
pub fn content(value: &Value) -> Result<&Value, AppError> {
    let code = value
        .get("code")
        .and_then(|v| v.as_i64().or_else(|| v.as_str()?.parse().ok()))
        .ok_or_else(AppError::changed)?;
    match code {
        200 => value.get("content").ok_or_else(AppError::changed),
        // SPOC refuses its own token. The shared school session is untouched
        // by that refusal, so this is a module-scoped authentication demand.
        401 | 403 => Err(AppError::module_auth_required()),
        _ => Err(AppError::new(crate::ErrorCode::BusinessRejected)),
    }
}

pub fn parse_detail(value: &Value) -> Result<HomeworkDetail, AppError> {
    let assignment = content(&value["assignment"])?;
    if !assignment.is_object() {
        return Err(AppError::changed());
    }
    let submission = content(&value["submission"])?;
    if !submission.is_null() && !submission.is_object() {
        return Err(AppError::changed());
    }
    let (mut status, status_detail) = map_status(optional_string(submission, "tjzt").as_deref());
    if !submission.is_null() && optional_string(submission, "tjzt").is_none() {
        status = HomeworkStatus::Unknown;
    }
    // Swift AssignmentDetail.zynr and UBAA LocalSpocAssignmentDetailRaw.zynr
    // accept string/null. A changed object/array must not look like a valid
    // empty body or overwrite a prior complete detail snapshot.
    let html = match assignment.get("zynr") {
        None | Some(Value::Null) => None,
        Some(Value::String(value)) => Some(value),
        _ => return Err(AppError::changed()),
    };
    // Display plain text only; never execute untrusted upstream HTML.
    let text = html
        .map(|html| {
            let mut out = String::new();
            let mut inside = false;
            for ch in html.chars() {
                match ch {
                    '<' => {
                        inside = true;
                        out.push('\n');
                    }
                    '>' => inside = false,
                    _ if !inside => out.push(ch),
                    _ => {}
                }
            }
            out.replace("&nbsp;", " ")
                .replace("&lt;", "<")
                .replace("&gt;", ">")
                .replace("&amp;", "&")
                .trim()
                .to_owned()
        })
        .filter(|s| !s.is_empty());
    Ok(HomeworkDetail {
        source_url: None,
        content: text,
        published_at: optional_string(assignment, "zykssj"),
        due_at: optional_string(assignment, "zyjzsj"),
        score: optional_string(assignment, "zyfs"),
        status,
        status_detail,
        submitted_at: optional_string(submission, "tjsj"),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ErrorCode;
    use serde_json::json;

    #[test]
    fn pagination_param_matches_ubaa_golden_vector() {
        let plain = r#"{"pageSize":15,"pageNum":1,"sqlid":"1713252980496efac7d5d9985e81693116d3e8a52ebf2b","xnxq":"2025-20262","kcid":"","yzwz":""}"#;
        assert_eq!(
            encrypt_page_param(plain),
            "hkJ9jAFVEMFUgJEjbOLv4eRZqXHIsmF+WbYaG1ipT1L1N+BbxRXtBj6Gcjri4Mo+y6q22/FkNm/isiC2+B+/hNejBx2cQJfNp9zoxorVJBa86sID0ROtPQ/2V07JCmVC3qsgIWBokL7EYyiPfilw+0ryJ6e61jRnLn90sQFosew="
        );
    }

    #[test]
    fn parser_maps_known_and_unknown_statuses() {
        let page = parse_page(json!({
            "pageNum": 1,
            "pages": 2,
            "hasNextPage": true,
            "list": [
                {"zyid": "a", "zymc": "作业一", "tjzt": "1", "sskcid": "c1", "kcmc": "软件工程"},
                {"zyid": "b", "zymc": "作业二", "tjzt": "待老师确认"}
            ]
        }))
        .expect("page");
        assert_eq!(page.items.len(), 2);
        assert_eq!(page.items[0].status, HomeworkStatus::Submitted);
        assert_eq!(page.items[1].status, HomeworkStatus::Unknown);
        assert_eq!(page.items[1].status_detail.as_deref(), Some("待老师确认"));
    }

    #[test]
    fn inconsistent_has_next_is_a_structure_error() {
        let error = parse_page(json!({
            "pageNum": 1,
            "pages": 1,
            "hasNextPage": true,
            "list": []
        }))
        .expect_err("inconsistent");
        assert_eq!(error.code, ErrorCode::ChangedResponse);
    }
}
