//! Public OPAC projections (API §6.1). The school wraps holdings in a JSON
//! *string*, so that string is decoded with explicit size/depth/entry bounds
//! instead of being handed to the UI.
use crate::AppError;
pub use ginkgo_domain::features::library_books::*;
use serde_json::Value;

/// A holdings document larger than this is treated as a changed response.
pub const HOLDINGS_MAX_BYTES: usize = 512 * 1024;
/// Nesting bound for the second decode; the real document is two levels deep.
pub const HOLDINGS_MAX_DEPTH: usize = 8;
/// Copy bound for one book's holdings.
pub const HOLDINGS_MAX_ITEMS: usize = 500;

fn number(value: &Value) -> Option<i64> {
    value
        .as_i64()
        .or_else(|| value.as_f64().map(|value| value as i64))
        .or_else(|| value.as_str()?.trim().parse().ok())
}

fn text(value: &Value) -> String {
    match value {
        Value::String(text) => {
            let text = text.trim();
            if text.is_empty() || text == "null" {
                String::new()
            } else {
                text.to_owned()
            }
        }
        Value::Number(number) => number.to_string(),
        _ => String::new(),
    }
}

/// Bidirectional string-or-array field (`callno` is an array in search results
/// and a string elsewhere). Values are joined, never reordered.
fn joined(value: &Value) -> String {
    match value {
        Value::Array(items) => items
            .iter()
            .map(text)
            .filter(|item| !item.is_empty())
            .collect::<Vec<_>>()
            .join(" · "),
        other => text(other),
    }
}

/// The OPAC envelope uses a numeric `code === 0`; HTTP 200 alone is not success.
pub fn envelope(value: &Value) -> Result<&Value, AppError> {
    let code = number(&value["code"]).ok_or_else(AppError::changed)?;
    if code != 0 {
        return Err(AppError::new(crate::ErrorCode::BusinessRejected));
    }
    value.get("data").ok_or_else(AppError::changed)
}

pub fn page(value: &Value, page: i64, page_size: i64) -> Result<BookPage, AppError> {
    let data = envelope(value)?;
    let total = number(&data["total"])
        .filter(|count| *count >= 0)
        .unwrap_or(0);
    let actual_total = number(&data["actualTotal"])
        .filter(|count| *count >= 0)
        .unwrap_or(total);
    // The school answers `dataList: null` for a genuine empty match. An absent
    // list with a positive count is inconsistent, so only the former is read as
    // "no hits" instead of being reported as an empty catalogue.
    let rows: &[Value] = match data["dataList"]
        .as_array()
        .or_else(|| data["list"].as_array())
    {
        Some(rows) => rows,
        None if total == 0 && actual_total == 0 => &[],
        None => return Err(AppError::changed()),
    };
    let mut items = Vec::with_capacity(rows.len().min(page_size.max(0) as usize + 1));
    for row in rows {
        let bib_id = ["bibId", "id", "groupId"]
            .iter()
            .map(|key| text(&row[key]))
            .find(|value| !value.is_empty())
            .ok_or_else(AppError::changed)?;
        // Real search rows carry `pub_year`; other sources may use
        // `publishDate` or `year`.
        let year = ["publishDate", "pub_year", "year"]
            .iter()
            .map(|key| text(&row[key]))
            .find(|value| !value.is_empty())
            .unwrap_or_default();
        items.push(BookHit {
            bib_id,
            title: text(&row["title"]),
            author: joined(&row["author"]),
            publisher: joined(&row["publisher"]),
            year,
            callno: joined(&row["callno"]),
            isbn: joined(&row["isbn"]),
            items_available: number(&row["itemsAvailable"]).filter(|count| *count >= 0),
            item_count: number(&row["itemCount"]).filter(|count| *count >= 0),
        });
    }
    Ok(BookPage {
        page,
        page_size,
        total,
        actual_total,
        has_more: page * page_size < actual_total,
        items,
    })
}

fn depth(value: &Value) -> usize {
    match value {
        Value::Array(items) => 1 + items.iter().map(depth).max().unwrap_or(0),
        Value::Object(items) => 1 + items.values().map(depth).max().unwrap_or(0),
        _ => 1,
    }
}

/// `data.holdings` is a JSON string; anything else is a changed response.
pub fn holdings(value: &Value) -> Result<Vec<BookHolding>, AppError> {
    let data = envelope(value)?;
    let encoded = data["holdings"]
        .as_str()
        .or_else(|| data["holdingList"].as_str())
        .ok_or_else(AppError::changed)?;
    if encoded.len() > HOLDINGS_MAX_BYTES {
        return Err(AppError::changed());
    }
    let decoded: Value = serde_json::from_str(encoded).map_err(|_| AppError::changed())?;
    if depth(&decoded) > HOLDINGS_MAX_DEPTH {
        return Err(AppError::changed());
    }
    let rows = decoded.as_array().ok_or_else(AppError::changed)?;
    if rows.len() > HOLDINGS_MAX_ITEMS {
        return Err(AppError::changed());
    }
    rows.iter()
        .map(|row| {
            // Only the school's own status text is shown; numeric codes such as
            // `circStatus`/`itemStatus` are never decoded into availability.
            let location = text(&row["locationName"]);
            let location = if location.is_empty() {
                text(&row["location"])
            } else {
                location
            };
            Ok(BookHolding {
                call_no: joined(&row["callNo"]),
                bar_code: text(&row["barCode"]),
                library: text(&row["library"]),
                location,
                status: text(&row["status"]),
            })
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn search_page_flattens_arrays_and_keeps_unknowns_empty() {
        let body = json!({"code":0,"data":{
            "total":41,"actualTotal":41,"offset":0,"limit":2,
            "dataList":[
                {"bibId":"B1","title":"合成书名","author":["甲","乙"],"publisher":"合成出版社","publishDate":"2020","callno":["TP1/1"],"isbn":["9787000000000"],"itemsAvailable":2,"itemCount":3},
                {"bibId":"B2","title":"另一本"}
            ]
        }});
        let page = page(&body, 1, 2).expect("page");
        assert_eq!(page.total, 41);
        assert!(page.has_more);
        assert_eq!(page.items.len(), 2);
        assert_eq!(page.items[0].author, "甲 · 乙");
        assert_eq!(page.items[0].callno, "TP1/1");
        assert_eq!(page.items[0].items_available, Some(2));
        // Missing fields stay empty/None instead of being invented.
        assert_eq!(page.items[1].author, "");
        assert_eq!(page.items[1].item_count, None);
    }

    #[test]
    fn empty_match_uses_a_null_list_but_an_inconsistent_one_is_rejected() {
        // Observed live: `total:0` with `dataList:null` is a genuine empty match.
        let empty = json!({"code":0,"data":{"total":0,"actualTotal":0,"dataList":null}});
        let empty_page = page(&empty, 1, 20).expect("empty");
        assert!(empty_page.items.is_empty());
        assert!(!empty_page.has_more, "no hits means no next page");
        // A positive count with no list is inconsistent, not "no results".
        let broken = json!({"code":0,"data":{"total":5,"actualTotal":5,"dataList":null}});
        assert!(page(&broken, 1, 20).is_err());
    }

    #[test]
    fn search_rows_use_pub_year_and_report_the_school_total() {
        let body = json!({"code":0,"data":{
            "total":10000,"actualTotal":26976,"limit":2,
            "dataList":[{"bibId":"B1","title":"物理:力学","pub_year":"2016"}]
        }});
        let capped = page(&body, 1, 2).expect("page");
        assert_eq!(capped.items[0].year, "2016");
        // The list UI caps `total`; `actualTotal` keeps the school's own value.
        assert_eq!(capped.total, 10000);
        assert_eq!(capped.actual_total, 26976);
        assert!(capped.has_more);
    }

    #[test]
    fn non_zero_code_is_a_business_rejection_not_an_empty_page() {
        let body = json!({"code":401,"message":"denied"});
        assert_eq!(
            page(&body, 1, 20).expect_err("code").code,
            crate::ErrorCode::BusinessRejected
        );
        assert!(holdings(&body).is_err());
    }

    #[test]
    fn holdings_are_decoded_once_from_their_json_string() {
        let inner = json!([{
            "callNo":"TP1/1","barCode":"C1","library":"学院路","locationName":"三层",
            "circStatus":0,"itemStatus":"41","status":"可借","location":"备用位置"
        }]);
        let body = json!({"code":0,"data":{"holdings":inner.to_string()}});
        let rows = holdings(&body).expect("holdings");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].call_no, "TP1/1");
        assert_eq!(rows[0].location, "三层");
        assert_eq!(rows[0].status, "可借");
    }

    #[test]
    fn malformed_or_oversized_holdings_are_rejected() {
        for value in [
            json!({"code":0,"data":{"holdings":"not json"}}),
            json!({"code":0,"data":{"holdings":"{}"}}),
            json!({"code":0,"data":{"holdings":null}}),
            json!({"code":0,"data":{}}),
        ] {
            assert!(holdings(&value).is_err(), "{value}");
        }
        // Deeply nested or oversized documents never reach the projection.
        let deep = format!(
            "{}{}",
            "[".repeat(HOLDINGS_MAX_DEPTH + 1),
            "]".repeat(HOLDINGS_MAX_DEPTH + 1)
        );
        assert!(holdings(&json!({"code":0,"data":{"holdings":deep}})).is_err());
        let large = format!("[\"{}\"]", "x".repeat(HOLDINGS_MAX_BYTES));
        assert!(holdings(&json!({"code":0,"data":{"holdings":large}})).is_err());
    }
}
