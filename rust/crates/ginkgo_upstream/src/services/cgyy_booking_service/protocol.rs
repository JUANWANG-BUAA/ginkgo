//! CGYY 预约的纯协议辅助：入参校验、可用格解析、签名载荷、验证码坐标。
//!
//! 这里不持有客户端状态，也不发请求；写入时序留在 `cgyy_booking_service`。

use super::BookingContext;
use crate::{AppError, ErrorCode};
use ginkgo_domain::features::cgyy_booking::*;
use serde_json::{json, Value};
use std::collections::BTreeMap;

pub(super) fn number(v: &Value) -> Option<i64> {
    crate::codecs::cgyy::number(v)
}

pub(super) fn text(v: &Value) -> Option<&str> {
    v.as_str().filter(|s| !s.is_empty())
}

pub(super) fn data(value: &Value) -> Result<&Value, AppError> {
    crate::codecs::cgyy::envelope(value)
}

pub(super) fn validate(booking: &BookingRequest) -> Result<(), AppError> {
    if booking.site_id <= 0
        || booking.space_id <= 0
        || booking.time_ids.is_empty()
        || booking.time_ids.len() > 12
        || booking.time_ids.iter().any(|id| *id <= 0)
        || booking
            .time_ids
            .iter()
            .collect::<std::collections::HashSet<_>>()
            .len()
            != booking.time_ids.len()
        || booking.phone.len() != 11
        || !booking.phone.bytes().all(|c| c.is_ascii_digit())
        || booking.joiner_num < 1
        || booking.joiner_num > 100
        || booking.purpose_type <= 0
        || [
            booking.theme.as_str(),
            &booking.activity_content,
            &booking.joiners,
        ]
        .iter()
        .any(|s| s.trim().is_empty() || s.len() > 8000)
        || chrono::NaiveDate::parse_from_str(&booking.date, "%Y-%m-%d").is_err()
    {
        return Err(AppError::invalid());
    }
    Ok(())
}

pub(super) fn choices(value: &Value, date: &str) -> Result<Vec<BookingChoice>, AppError> {
    // Reuse strict read parser's availability semantics; never infer missing cells.
    let parsed = crate::codecs::cgyy::day(value, 1, date)?;
    let root = data(value)?;
    let rows = root["reservationDateSpaceInfo"][date]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let times = root["spaceTimeInfo"]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let mut output = Vec::new();
    for (index, space) in parsed.spaces.iter().enumerate() {
        let id = number(&rows[index]["id"])
            .or_else(|| number(&rows[index]["spaceId"]))
            .filter(|id| *id > 0)
            .ok_or_else(AppError::changed)?;
        for (index, slot) in space.slots.iter().enumerate() {
            if slot.status == "空闲" {
                output.push(BookingChoice {
                    space_id: id,
                    space_name: space.name.clone(),
                    time_id: number(&times[index]["id"]).ok_or_else(AppError::changed)?,
                    time: slot.time.clone(),
                });
            }
        }
    }
    Ok(output)
}

pub(super) fn selections(value: &Value, booking: &BookingRequest) -> Result<String, AppError> {
    let available = choices(value, &booking.date)?;
    if !booking.time_ids.iter().all(|id| {
        available
            .iter()
            .any(|c| c.space_id == booking.space_id && c.time_id == *id)
    }) {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    let root = data(value)?;
    let row = root["reservationDateSpaceInfo"][&booking.date]
        .as_array()
        .ok_or_else(AppError::changed)?
        .iter()
        .find(|r| number(&r["id"]).or_else(|| number(&r["spaceId"])) == Some(booking.space_id))
        .ok_or_else(AppError::changed)?;
    let group = number(&row["venueSpaceGroupId"]);
    let items: Vec<Value> = booking
        .time_ids
        .iter()
        .map(|id| json!({"spaceId": booking.space_id, "timeId": id, "venueSpaceGroupId": group}))
        .collect();
    serde_json::to_string(&items).map_err(|_| AppError::invalid())
}

pub(super) fn purposes(value: &Value) -> Vec<Purpose> {
    fn visit(value: &Value, result: &mut BTreeMap<i64, String>) {
        match value {
            Value::Array(items) => {
                for item in items {
                    visit(item, result);
                }
            }
            Value::Object(items) => {
                if let Some(name) = text(&value["name"]).filter(|n| n.contains('类')) {
                    if let Some(id) = number(&value["key"])
                        .or_else(|| number(&value["value"]))
                        .or_else(|| number(&value["id"]))
                    {
                        result.entry(id).or_insert_with(|| name.into());
                    }
                }
                for item in items.values() {
                    visit(item, result);
                }
            }
            _ => {}
        }
    }
    let mut result = BTreeMap::new();
    visit(value, &mut result);
    result
        .into_iter()
        .map(|(id, name)| Purpose { id, name })
        .collect()
}

pub(super) fn fallback_purposes() -> Vec<Purpose> {
    [
        "导学活动类",
        "学业支持类（串讲、答疑、学习小组讨论等）",
        "学术研讨类（竞赛、答辩、展示等小组讨论）",
        "党建活动类",
        "工作会议类（单位工作例会、学生组织工作会议等）",
        "团队建设类（班级、社团、学生会等学生组织团建）",
        "培训面试类（梦拓、学生组织培训及面试等）",
        "博雅课程类",
        "讲座、沙龙研讨类",
        "其他特色活动类",
    ]
    .into_iter()
    .enumerate()
    .map(|(index, name)| Purpose {
        id: index as i64 + 1,
        name: name.into(),
    })
    .collect()
}

pub(super) fn base_form(context: &BookingContext) -> BTreeMap<String, String> {
    let mut form = BTreeMap::from([
        ("venueSiteId".into(), context.booking.site_id.to_string()),
        ("reservationDate".into(), context.booking.date.clone()),
        ("reservationOrderJson".into(), context.selections.clone()),
        ("token".into(), context.reservation_token.clone()),
    ]);
    // Official drafts take `weekStartDate` from the day response. A missing
    // anchor is omitted instead of being signed with the requested date.
    if !context.week_start.is_empty() {
        form.insert("weekStartDate".into(), context.week_start.clone());
    }
    form
}

pub(super) fn encrypt(text: &str, secret: &str) -> Result<String, AppError> {
    use aes::{Aes128, Aes192, Aes256};
    use base64::Engine;
    use cipher::{BlockEncrypt, KeyInit};
    let mut bytes = text.as_bytes().to_vec();
    let padding = 16 - bytes.len() % 16;
    bytes.resize(bytes.len() + padding, padding as u8);
    macro_rules! encrypt_blocks {
        ($cipher:ty) => {{
            let cipher =
                <$cipher>::new_from_slice(secret.as_bytes()).map_err(|_| AppError::changed())?;
            for chunk in bytes.chunks_exact_mut(16) {
                cipher.encrypt_block(cipher::generic_array::GenericArray::from_mut_slice(chunk));
            }
        }};
    }
    match secret.len() {
        16 => encrypt_blocks!(Aes128),
        24 => encrypt_blocks!(Aes192),
        32 => encrypt_blocks!(Aes256),
        _ => return Err(AppError::changed()),
    }
    Ok(base64::engine::general_purpose::STANDARD.encode(bytes))
}

/// Upstream captcha coordinate: `310 * offset / width` (§6B.1). Raw device or
/// image pixels never travel as the protocol value; the pair is normalised and
/// clamped to the documented range.
pub(super) fn protocol_point(offset: f64, width: Option<f64>) -> Result<String, AppError> {
    if !offset.is_finite() || !(0.0..=10_000.0).contains(&offset) || offset <= 0.0 {
        return Err(AppError::invalid());
    }
    let value = match width {
        None => offset,
        Some(width) if width.is_finite() && width > 0.0 && width <= 10_000.0 => {
            310.0 * offset / width
        }
        Some(_) => return Err(AppError::invalid()),
    };
    if !(0.0..=310.0).contains(&value) {
        return Err(AppError::invalid());
    }
    // Two decimals keep the signed form stable without claiming server precision.
    Ok(format!("{}", (value * 100.0).round() / 100.0))
}

/// A trade number only narrows the match when both sides report one; an absent
/// value stays unverified instead of being treated as a mismatch.
pub(super) fn trade_matches(draft: &str, response: &str, row: &Value) -> bool {
    let row = row["tradeNo"].as_str().unwrap_or_default();
    [draft, response]
        .into_iter()
        .filter(|value| !value.is_empty())
        .all(|value| row.is_empty() || row == value)
}
