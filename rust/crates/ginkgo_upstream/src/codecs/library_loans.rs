//! API §6.2: empty response verified; nonempty fields are static evidence only.
use crate::{AppError, ErrorCode};
use ginkgo_domain::features::library_loans::{LibraryLoan, LibraryLoanPage};
use serde_json::Value;
pub const PAGE_SIZE: u32 = 100;
fn number(v: &Value, key: &str) -> Result<u32, AppError> {
    v.get(key)
        .and_then(Value::as_u64)
        .and_then(|n| n.try_into().ok())
        .ok_or_else(AppError::changed)
}
fn text(v: Option<&Value>) -> Result<Option<String>, AppError> {
    match v {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) if s.len() <= 4096 => Ok(Some(s.clone())),
        // Bibliographic fields may be arrays, as in public OPAC projections.
        Some(Value::Array(a)) if a.len() <= 32 => {
            let parts = a
                .iter()
                .map(|v| match v {
                    Value::String(s) if s.len() <= 4096 => Ok(s.as_str()),
                    _ => Err(AppError::changed()),
                })
                .collect::<Result<Vec<_>, _>>()?;
            Ok(Some(parts.join(" / ")))
        }
        _ => Err(AppError::changed()),
    }
}
pub fn page(v: &Value, requested: u32) -> Result<LibraryLoanPage, AppError> {
    match v.get("code").and_then(Value::as_i64) {
        Some(0) => {}
        Some(_) => return Err(AppError::new(ErrorCode::BusinessRejected)),
        None => return Err(AppError::changed()),
    }
    let data = v
        .get("data")
        .filter(|v| v.is_object())
        .ok_or_else(AppError::changed)?;
    if !(1..=100).contains(&requested) {
        return Err(AppError::invalid());
    }
    let current = number(data, "currentPage")?;
    let size = number(data, "pageSize")?;
    let total = number(data, "total")?;
    let pages = number(data, "totalPage")?;
    let items = data
        .get("items")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    if current != requested
        || size != PAGE_SIZE
        || items.len() > size as usize
        || (total > 0 && pages != total.div_ceil(size))
        || (total == 0 && pages > 1)
        || (total > 0 && current > pages)
        || (total == 0 && (current != 1 || !items.is_empty()))
    {
        return Err(AppError::changed());
    }
    let expected = total.saturating_sub((current - 1) * size).min(size) as usize;
    if items.len() != expected {
        return Err(AppError::changed());
    }
    let mut ids = std::collections::BTreeSet::new();
    let items = items
        .iter()
        .map(|row| {
            let id = row
                .get("loanId")
                .and_then(Value::as_str)
                .filter(|s| !s.is_empty() && s.len() <= 256)
                .ok_or_else(AppError::changed)?;
            if !ids.insert(id) {
                return Err(AppError::changed());
            }
            let attrs = match row.get("bibAttrs") {
                None | Some(Value::Null) => None,
                Some(v) if v.is_object() => Some(v),
                _ => return Err(AppError::changed()),
            };
            Ok(LibraryLoan {
                id: id.into(),
                title: text(attrs.and_then(|v| v.get("title")))?,
                author: text(attrs.and_then(|v| v.get("author")))?,
                call_number: text(attrs.and_then(|v| v.get("callno")))?,
                borrowed_at: text(row.get("loanDate"))?,
                due_at: text(row.get("dueDate"))?,
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    Ok(LibraryLoanPage {
        items,
        page: current,
        total,
        has_more: current < pages,
    })
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn response(items: Value, total: u32) -> Value {
        json!({"code":0,"data":{"items":items,"currentPage":1,"pageSize":100,"total":total,"totalPage":total.div_ceil(100)}})
    }
    #[test]
    fn explicit_empty_and_synthetic_nonempty() {
        assert!(page(&response(json!([]), 0), 1).unwrap().items.is_empty());
        let p = page(&response(json!([{"loanId":"fixture","bibAttrs":{"title":"合成书名","author":["甲"]},"dueDate":"2026-11-01"}]),1),1).unwrap();
        assert_eq!(p.items[0].title.as_deref(), Some("合成书名"));
        assert_eq!(p.items[0].due_at.as_deref(), Some("2026-11-01"));
    }
    #[test]
    fn drift_and_business_denial_never_become_empty() {
        for v in [
            json!({}),
            json!({"code":"0","data":{}}),
            response(json!([]), 1),
            response(json!([{"loanId":"a","bibAttrs":{"title":{}}}]), 1),
            response(json!([{"loanId":"a"},{"loanId":"a"}]), 2),
        ] {
            assert!(page(&v, 1).is_err());
        }
        assert_eq!(
            page(&json!({"code":401}), 1).err().unwrap().code,
            ErrorCode::BusinessRejected
        );
        assert_eq!(
            page(&json!({"code":1}), 1).err().unwrap().code,
            ErrorCode::BusinessRejected
        );
        assert!(page(&response(json!([]), 0), 2).is_err());
    }
}
