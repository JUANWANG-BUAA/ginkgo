//! API.md §6H student income JSON decoder. Whitelist projection only; never
//! retains ID-card numbers, bank account numbers, phone numbers or raw rows.
use crate::{AppError, ErrorCode};
use ginkgo_domain::features::finance::FinanceIncomeEntry;
use serde_json::Value;

pub fn parse_login_token(value: &Value) -> Result<String, AppError> {
    let data = envelope_data(value)?;
    match data.get("token") {
        Some(Value::String(token)) if !token.trim().is_empty() => Ok(token.trim().to_owned()),
        _ => Err(AppError::changed()),
    }
}

pub fn parse_page(value: &Value) -> Result<(Vec<FinanceIncomeEntry>, usize), AppError> {
    let data = envelope_data(value)?;
    let (rows_key, total_key) = if data.get("mx").is_some() || data.get("total").is_some() {
        ("mx", "total")
    } else if data.get("data").is_some() || data.get("count").is_some() {
        ("data", "count")
    } else {
        return Err(AppError::changed());
    };
    let rows = data
        .get(rows_key)
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let total = parse_total(data.get(total_key))?;
    if rows.len() > total || total > 10_000 {
        return Err(AppError::changed());
    }
    let mut entries = Vec::with_capacity(rows.len());
    for row in rows {
        entries.push(parse_entry(row)?);
    }
    Ok((entries, total))
}

fn envelope_data(value: &Value) -> Result<&Value, AppError> {
    let code = value
        .get("code")
        .and_then(|c| c.as_i64().or_else(|| c.as_str()?.trim().parse().ok()))
        .ok_or_else(AppError::changed)?;
    match code {
        200 => value
            .get("data")
            .filter(|data| data.is_object())
            .ok_or_else(AppError::changed),
        401 | 403 => Err(AppError::module_auth_required()),
        _ => Err(AppError::new(ErrorCode::BusinessRejected)),
    }
}

fn parse_total(value: Option<&Value>) -> Result<usize, AppError> {
    let raw = match value {
        Some(Value::Number(n)) => n.as_u64(),
        Some(Value::String(s)) => s.trim().parse::<u64>().ok(),
        _ => None,
    }
    .ok_or_else(AppError::changed)?;
    usize::try_from(raw).map_err(|_| AppError::changed())
}

fn parse_entry(row: &Value) -> Result<FinanceIncomeEntry, AppError> {
    if !row.is_object() {
        return Err(AppError::changed());
    }
    let id = match row.get("lsh") {
        Some(Value::String(s)) if !s.trim().is_empty() => s.trim().to_owned(),
        Some(Value::Number(n)) => n.to_string(),
        _ => return Err(AppError::changed()),
    };
    Ok(FinanceIncomeEntry {
        id,
        project: optional_text(row, "ffxmmc")?,
        description: optional_text(row, "zy")?,
        gross_minor: optional_minor(row.get("je"))?,
        tax_minor: optional_minor(row.get("se"))?,
        net_minor: optional_minor(row.get("sfje"))?,
        tax_rate: parse_tax_rate(row)?,
        recorded_date: optional_text(row, "lrrq")?,
        year: optional_scalar_text(row, "nian")?,
        month: optional_scalar_text(row, "yue")?,
    })
}

fn optional_text(row: &Value, key: &str) -> Result<Option<String>, AppError> {
    match row.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) => {
            let trimmed = s.trim();
            if trimmed.is_empty() || trimmed == "--" {
                Ok(None)
            } else {
                Ok(Some(trimmed.to_owned()))
            }
        }
        Some(_) => Err(AppError::changed()),
    }
}

fn optional_scalar_text(row: &Value, key: &str) -> Result<Option<String>, AppError> {
    match row.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) => {
            let trimmed = s.trim();
            Ok((!trimmed.is_empty() && trimmed != "--").then(|| trimmed.to_owned()))
        }
        Some(Value::Number(n)) => Ok(Some(n.to_string())),
        Some(_) => Err(AppError::changed()),
    }
}

fn parse_tax_rate(row: &Value) -> Result<Option<String>, AppError> {
    if let Some(rate) = optional_text(row, "slbfb")? {
        return Ok(Some(rate));
    }
    match row.get("sl") {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) if s.trim().is_empty() || s.trim() == "--" => Ok(None),
        Some(Value::String(s)) => format_ratio_percent(s.trim()),
        Some(Value::Number(n)) => format_ratio_percent(&n.to_string()),
        Some(_) => Err(AppError::changed()),
    }
}

fn format_ratio_percent(raw: &str) -> Result<Option<String>, AppError> {
    if raw.ends_with('%') {
        return Ok(Some(raw.to_owned()));
    }
    // Convert decimal ratio like "0.03", "0.2", "0.035", or "0" to percentage string
    // (multiply by 100) without floating-point drift.
    let cleaned = raw.replace(',', "");
    let (negative, rest) = match cleaned.strip_prefix('-') {
        Some(tail) => (true, tail),
        None => (false, cleaned.strip_prefix('+').unwrap_or(&cleaned)),
    };
    if rest.is_empty() {
        return Err(AppError::changed());
    }
    let (whole_str, frac_str) = rest.split_once('.').unwrap_or((rest, ""));
    if whole_str.is_empty()
        || frac_str.len() > 4
        || !whole_str.bytes().all(|b| b.is_ascii_digit())
        || !frac_str.bytes().all(|b| b.is_ascii_digit())
    {
        return Err(AppError::changed());
    }
    let whole_bps: i64 = whole_str
        .parse::<i64>()
        .ok()
        .and_then(|v| v.checked_mul(10_000))
        .ok_or_else(AppError::changed)?;
    let mut padded_frac = frac_str.to_owned();
    while padded_frac.len() < 4 {
        padded_frac.push('0');
    }
    let frac_bps: i64 = padded_frac.parse().map_err(|_| AppError::changed())?;
    let bps = whole_bps
        .checked_add(frac_bps)
        .ok_or_else(AppError::changed)?;
    let signed_bps = if negative { -bps } else { bps };
    let pct_whole = signed_bps / 100;
    let pct_rem = signed_bps.abs() % 100;
    let sign_prefix = if signed_bps < 0 && pct_whole == 0 {
        "-"
    } else {
        ""
    };
    if pct_rem == 0 {
        Ok(Some(format!("{sign_prefix}{pct_whole}%")))
    } else if pct_rem % 10 == 0 {
        Ok(Some(format!("{sign_prefix}{pct_whole}.{}%", pct_rem / 10)))
    } else {
        Ok(Some(format!("{sign_prefix}{pct_whole}.{pct_rem:02}%")))
    }
}

pub fn optional_minor(value: Option<&Value>) -> Result<Option<i64>, AppError> {
    match value {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) if s.trim().is_empty() || s.trim() == "--" => Ok(None),
        Some(Value::String(s)) => parse_decimal_minor(s.trim()).map(Some),
        Some(Value::Number(n)) => parse_decimal_minor(&n.to_string()).map(Some),
        Some(_) => Err(AppError::changed()),
    }
}

pub fn parse_decimal_minor(raw: &str) -> Result<i64, AppError> {
    let cleaned = raw.replace(',', "");
    let (negative, rest) = match cleaned.strip_prefix('-') {
        Some(tail) => (true, tail),
        None => (false, cleaned.strip_prefix('+').unwrap_or(&cleaned)),
    };
    if rest.is_empty() {
        return Err(AppError::changed());
    }
    let (whole_str, frac_str) = rest.split_once('.').unwrap_or((rest, ""));
    if whole_str.is_empty()
        || frac_str.len() > 2
        || !whole_str.bytes().all(|b| b.is_ascii_digit())
        || !frac_str.bytes().all(|b| b.is_ascii_digit())
    {
        return Err(AppError::changed());
    }
    let whole: i64 = whole_str.parse().map_err(|_| AppError::changed())?;
    let frac: i64 = match frac_str.len() {
        0 => 0,
        1 => frac_str.parse::<i64>().map_err(|_| AppError::changed())? * 10,
        _ => frac_str.parse::<i64>().map_err(|_| AppError::changed())?,
    };
    let total = whole
        .checked_mul(100)
        .and_then(|v| v.checked_add(frac))
        .ok_or_else(AppError::changed)?;
    Ok(if negative { -total } else { total })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_current_mx_total_and_legacy_data_count_shapes_and_strips_sensitive_fields() {
        let current = json!({
            "code": 200,
            "data": {
                "total": 2,
                "mx": [
                    {
                        "lsh": "LSH-001",
                        "ffxmmc": "助研津贴",
                        "zy": "11月助研",
                        "je": 1200.5,
                        "se": 0,
                        "sfje": "1200.50",
                        "slbfb": "0%",
                        "lrrq": "2026-11-15",
                        "nian": "2026",
                        "yue": "11",
                        "sfzh": "110101200001011234",
                        "yhkh": "6222020000000000"
                    }
                ]
            }
        });
        let (rows, total) = parse_page(&current).expect("valid mx/total page");
        assert_eq!(total, 2);
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].id, "LSH-001");
        assert_eq!(rows[0].gross_minor, Some(120_050));
        assert_eq!(rows[0].tax_minor, Some(0));
        assert_eq!(rows[0].net_minor, Some(120_050));
        assert_eq!(rows[0].tax_rate.as_deref(), Some("0%"));

        let legacy = json!({
            "code": 200,
            "data": {
                "count": 1,
                "data": [{
                    "lsh": "LSH-002",
                    "ffxmmc": "国家助学金",
                    "je": 800,
                    "sfje": 800,
                    "sl": 0.03
                }]
            }
        });
        let (legacy_rows, legacy_total) = parse_page(&legacy).expect("valid legacy page");
        assert_eq!(legacy_total, 1);
        assert_eq!(legacy_rows[0].tax_rate.as_deref(), Some("3%"));
    }

    #[test]
    fn rejects_module_401_and_inconsistent_pagination() {
        assert_eq!(
            parse_page(&json!({"code": 401, "message": "expired"}))
                .unwrap_err()
                .code,
            ErrorCode::ModuleAuthRequired
        );
        assert_eq!(
            parse_page(&json!({
                "code": 200,
                "data": {
                    "total": 0,
                    "mx": [{"lsh": "LSH-1"}]
                }
            }))
            .unwrap_err()
            .code,
            ErrorCode::ChangedResponse
        );
    }
}
