use crate::{AppError, ErrorCode};
use serde_json::Value;

pub fn ensure_success(value: &Value) -> Result<(), AppError> {
    let success = value
        .get("success")
        .and_then(Value::as_bool)
        .ok_or_else(AppError::changed)?;
    if success {
        return Ok(());
    }
    let kind = value.get("type").and_then(Value::as_i64);
    let sub_type = value.get("sub_type").and_then(Value::as_str);
    if kind == Some(401) || sub_type == Some("4000011") {
        return Err(AppError::new(ErrorCode::SessionExpired));
    }
    Err(AppError::new(ErrorCode::BusinessRejected))
}

pub fn campus_card_number(value: &Value) -> Result<String, AppError> {
    ensure_success(value)?;
    value
        .pointer("/data/data")
        .and_then(Value::as_array)
        .and_then(|rows| rows.first())
        .and_then(|row| row.get("stuNo"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_owned)
        .ok_or_else(AppError::changed)
}

fn money_minor(value: &Value) -> Result<i64, AppError> {
    let text = match value {
        Value::String(value) => value.trim().to_owned(),
        Value::Number(value) => value.to_string(),
        _ => return Err(AppError::changed()),
    };
    let (negative, unsigned) = text
        .strip_prefix('-')
        .map_or((false, text.as_str()), |value| (true, value));
    let mut parts = unsigned.split('.');
    let whole = parts.next().ok_or_else(AppError::changed)?;
    let fraction = parts.next().unwrap_or("");
    if parts.next().is_some()
        || whole.is_empty()
        || !whole.chars().all(|ch| ch.is_ascii_digit())
        || !fraction.chars().all(|ch| ch.is_ascii_digit())
        || fraction.len() > 2
    {
        return Err(AppError::changed());
    }
    let whole = whole.parse::<i64>().map_err(|_| AppError::changed())?;
    let fraction = format!("{fraction:0<2}")
        .parse::<i64>()
        .map_err(|_| AppError::changed())?;
    let minor = whole
        .checked_mul(100)
        .and_then(|value| value.checked_add(fraction))
        .ok_or_else(AppError::changed)?;
    if negative {
        minor.checked_neg().ok_or_else(AppError::changed)
    } else {
        Ok(minor)
    }
}

pub fn balance_minor(value: &Value) -> Result<i64, AppError> {
    ensure_success(value)?;
    money_minor(
        value
            .pointer("/data/balance")
            .ok_or_else(AppError::changed)?,
    )
}
