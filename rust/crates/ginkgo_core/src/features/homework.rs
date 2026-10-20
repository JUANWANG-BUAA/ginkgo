//! SPOC homework list parsing and pagination-parameter encryption.
//!
//! The AES-CBC + zero padding + Base64 shape is shared with the Apple client;
//! the golden vector comes from the existing Swift regression test.
use crate::{AppError, ErrorCode};
use aes::{
    cipher::{BlockEncrypt, KeyInit},
    Aes128,
};
use base64::{engine::general_purpose::STANDARD, Engine};
use serde::{Deserialize, Serialize};
use serde_json::Value;

const KEY: &[u8; 16] = b"inco12345678ocni";
const IV: &[u8; 16] = b"ocni12345678inco";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HomeworkStatus {
    Pending,
    Submitted,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkItem {
    pub id: String,
    pub course_id: Option<String>,
    pub course_name: String,
    pub title: String,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub status: HomeworkStatus,
    pub status_detail: Option<String>,
    pub score: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkPage {
    pub page_num: i32,
    pub pages: Option<i32>,
    pub has_next: Option<bool>,
    pub items: Vec<HomeworkItem>,
}

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
    let items = rows
        .iter()
        .map(|row| {
            let raw_id = required_string(row, "zyid")?;
            let title = required_string(row, "zymc")?;
            let (status, status_detail) = map_status(optional_string(row, "tjzt").as_deref());
            Ok(HomeworkItem {
                id: format!("spoc:{raw_id}"),
                course_id: optional_string(row, "sskcid"),
                course_name: optional_string(row, "kcmc")
                    .filter(|name| !name.trim().is_empty())
                    .unwrap_or_else(|| "SPOC 课程".into()),
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

#[cfg(test)]
mod tests {
    use super::*;
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
