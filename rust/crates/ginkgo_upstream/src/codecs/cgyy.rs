//! Read-only CGYY projections. No reservation tokens, lock codes or participant data.
use crate::AppError;
pub use ginkgo_domain::features::cgyy::*;
use serde_json::Value;
pub fn number(v: &Value) -> Option<i64> {
    v.as_i64().or_else(|| v.as_str()?.parse().ok())
}
fn text(v: &Value) -> String {
    v.as_str()
        .filter(|s| *s != "null")
        .unwrap_or_default()
        .to_owned()
}
pub fn envelope(value: &Value) -> Result<&Value, AppError> {
    let code = number(&value["code"]).ok_or_else(AppError::changed)?;
    if code == 401 {
        return Err(AppError::session_expired());
    }
    if code != 200 {
        // Preserve the v1 read-parser classification. Mutation callers must not
        // interpret this as proof of non-commit: booking_failure always keeps
        // pending protection for generic envelope errors, including body 500.
        return Err(AppError::new(crate::ErrorCode::BusinessRejected));
    }
    value.get("data").ok_or_else(AppError::changed)
}
pub fn sites(value: &Value) -> Result<Vec<Site>, AppError> {
    let data = envelope(value)?;
    let rows = data
        .as_array()
        .or_else(|| data["content"].as_array())
        .or_else(|| data["data"].as_array())
        .ok_or_else(AppError::changed)?;
    let mut result = Vec::new();
    let mut ids = std::collections::HashSet::new();
    for venue in rows {
        let nested = venue
            .get("siteList")
            .map(|v| v.as_array().ok_or_else(AppError::changed))
            .transpose()?;
        let children = nested
            .filter(|v| !v.is_empty())
            .map(|v| v.as_slice())
            .unwrap_or_else(|| std::slice::from_ref(venue));
        for site in children {
            let id = number(&site["id"])
                .or_else(|| number(&site["siteId"]))
                .filter(|n| *n > 0)
                .ok_or_else(AppError::changed)?;
            let name = text(&site["siteName"]);
            let venue_name = text(&venue["venueName"]);
            if (name.is_empty() && venue_name.is_empty()) || !ids.insert(id) {
                return Err(AppError::changed());
            }
            result.push(Site {
                id,
                name,
                venue: venue_name,
                campus: text(&venue["campusName"]),
                seats: number(&site["seatCount"]),
                open_start: text(&site["openStartDate"]),
                open_end: text(&site["openEndDate"]),
            });
        }
    }
    result.sort_by(|a, b| a.venue.cmp(&b.venue).then(a.name.cmp(&b.name)));
    Ok(result)
}
pub fn day(value: &Value, site_id: i64, date: &str) -> Result<Day, AppError> {
    let data = envelope(value)?;
    let times = data["spaceTimeInfo"]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let dates = data["reservationDateSpaceInfo"]
        .as_object()
        .ok_or_else(AppError::changed)?;
    // Do not silently display a different day from the selected query.
    let rows = dates
        .get(date)
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut spaces = Vec::new();
    for row in rows {
        let name = text(&row["spaceName"]);
        if name.is_empty() {
            return Err(AppError::changed());
        }
        let mut slots = Vec::new();
        for time in times {
            let id = number(&time["id"]).ok_or_else(AppError::changed)?;
            let begin = text(&time["beginTime"]);
            let end = text(&time["endTime"]);
            if begin.is_empty() || end.is_empty() {
                return Err(AppError::changed());
            }
            let raw = row.get(id.to_string());
            let status = match raw {
                Some(raw) if raw.is_object() => {
                    let state = number(&raw["reservationStatus"]);
                    let free = state == Some(1)
                        && text(&raw["tradeNo"]).is_empty()
                        && number(&raw["orderId"]).is_none()
                        && raw["takeUp"] != true
                        && number(&raw["takeUp"]) != Some(1)
                        && !raw["takeUp"]
                            .as_str()
                            .is_some_and(|s| s.eq_ignore_ascii_case("true"));
                    if free {
                        "空闲"
                    } else if state.is_some() {
                        "不可预约"
                    } else {
                        "状态待确认"
                    }
                }
                _ => "状态待确认",
            };
            slots.push(Slot {
                time: format!("{begin}–{end}"),
                status: status.into(),
            });
        }
        spaces.push(Space { name, slots });
    }
    let dates = data
        .get("ableReservationDateList")
        .or_else(|| data.get("reservationDateList"))
        .and_then(Value::as_array)
        .map(|v| {
            v.iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();
    Ok(Day {
        site_id,
        date: date.into(),
        dates,
        spaces,
    })
}
/// Draft `weekStartDate`: the first date the day response advertises
/// (`reservationDateList[0]`, falling back to `ableReservationDateList[0]`).
/// It is never derived from the requested date; a missing or malformed value
/// stays absent so the field is omitted instead of signed with a guess.
pub fn week_start(value: &Value) -> Option<String> {
    let data = envelope(value).ok()?;
    ["reservationDateList", "ableReservationDateList"]
        .iter()
        .find_map(|key| {
            let items = data.get(*key)?.as_array()?;
            items.iter().find_map(|item| {
                let raw = item
                    .as_str()
                    .or_else(|| item.get("reservationDate").and_then(Value::as_str))?
                    .trim();
                chrono::NaiveDate::parse_from_str(raw, "%Y-%m-%d")
                    .ok()
                    .map(|parsed| parsed.to_string())
            })
        })
}
/// Conservative local cancellation gate; the mutation service rechecks fresh data.
pub(crate) fn can_cancel(row: &Value) -> bool {
    let start = chrono::NaiveDateTime::parse_from_str(
        &text(&row["reservationStartDate"]),
        "%Y-%m-%d %H:%M:%S",
    )
    .ok();
    let now: chrono::DateTime<chrono::Utc> = std::time::SystemTime::now().into();
    let now = now.with_timezone(&chrono_tz::Asia::Shanghai).naive_local();
    matches!(number(&row["orderStatus"]), Some(1 | 3))
        && number(&row["checkStatus"]).is_some_and(|s| (0..=6).contains(&s))
        && start.is_some_and(|start| now < start - chrono::Duration::hours(4))
}
pub fn orders(value: &Value) -> Result<Vec<Order>, AppError> {
    order_page(value).map(|(orders, _)| orders)
}

fn order_value(row: &Value) -> Result<Order, AppError> {
    Ok(Order {
        order_status: number(&row["orderStatus"]),
        check_status: number(&row["checkStatus"]),
        can_cancel: can_cancel(row),
        id: number(&row["id"]).ok_or_else(AppError::changed)?,
        place: ["venueName", "siteName", "venueSpaceName"]
            .iter()
            .map(|k| text(&row[k]))
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join(" · "),
        date: text(&row["reservationDate"]),
        time: format!(
            "{}–{}",
            text(&row["reservationStartDate"]),
            text(&row["reservationEndDate"])
        ),
        status: match number(&row["orderStatus"]) {
            Some(n) => format!("订单状态 {n}"),
            None => "状态待确认".into(),
        },
    })
}

pub fn order(value: &Value) -> Result<Order, AppError> {
    order_value(envelope(value)?)
}

fn optional_text(value: &Value) -> Option<String> {
    value
        .as_str()
        .map(str::trim)
        .filter(|text| !text.is_empty() && *text != "null")
        .map(str::to_owned)
}

pub fn lock_code(value: &Value) -> Result<CgyyLockCode, AppError> {
    let data = envelope(value)?;
    let order = &data["orderView"];
    Ok(CgyyLockCode {
        qr_code: optional_text(&data["qrCode"]),
        due_date: optional_text(&data["dueDate"]),
        trade_no: optional_text(&order["tradeNo"]),
        venue_name: optional_text(&order["venueName"]),
        site_name: optional_text(&order["siteName"]),
        space_name: optional_text(&order["venueSpaceName"]),
        order_name: optional_text(&order["orderName"]),
        reservation_date: optional_text(&order["reservationDate"]),
        reservation_date_detail: optional_text(&order["reservationDateDetail"]),
        reservation_start_date: optional_text(&order["reservationStartDate"]),
        reservation_end_date: optional_text(&order["reservationEndDate"]),
    })
}

/// One official orders page: the `content` rows plus `totalElements` when the
/// server reports a usable count. Paging metadata stays a hint, never a promise
/// that the caller has seen every historical order.
pub fn order_page(value: &Value) -> Result<(Vec<Order>, Option<i64>), AppError> {
    let data = envelope(value)?;
    let rows = data["content"]
        .as_array()
        .or_else(|| data["list"].as_array())
        .ok_or_else(AppError::changed)?;
    let total = number(&data["totalElements"]).filter(|count| *count >= 0);
    let orders = rows
        .iter()
        .map(order_value)
        .collect::<Result<Vec<_>, AppError>>()?;
    Ok((orders, total))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn day_body(extra: Value) -> Value {
        let mut data =
            json!({"spaceTimeInfo":[],"reservationDateSpaceInfo":{"2026-10-25":[]},"token":"A"});
        for (key, value) in extra.as_object().expect("object") {
            data[key.as_str()] = value.clone();
        }
        json!({"code":200,"data":data})
    }

    #[test]
    fn week_start_uses_the_advertised_first_date_not_the_query_date() {
        // Official drafts take reservationDateList[0]; the requested date is
        // only a fallback when the day response advertises nothing.
        assert_eq!(
            week_start(&day_body(
                json!({"reservationDateList":["2026-10-19","2026-10-26"]})
            )),
            Some("2026-10-19".into())
        );
        assert_eq!(
            week_start(&day_body(json!({"ableReservationDateList":["2026-10-12"]}))),
            Some("2026-10-12".into())
        );
        assert_eq!(week_start(&day_body(json!({}))), None);
        // Malformed or empty anchors are never signed.
        assert_eq!(
            week_start(&day_body(json!({"reservationDateList":["", "下周"]}))),
            None
        );
        assert_eq!(
            week_start(&day_body(json!({"reservationDateList":["2026-13-01"]}))),
            None
        );
    }

    #[test]
    fn order_page_reports_the_visible_count_without_claiming_history() {
        let page = json!({"code":200,"data":{
            "content":[{"id":3,"orderStatus":1,"reservationDate":"2026-10-25"}],
            "totalElements":41
        }});
        let (orders, total) = order_page(&page).expect("page");
        assert_eq!(orders.len(), 1);
        assert_eq!(orders[0].id, 3);
        assert_eq!(total, Some(41));
        let (_, missing) = order_page(&json!({"code":200,"data":{"content":[]}})).expect("page");
        assert_eq!(missing, None);
    }
}
