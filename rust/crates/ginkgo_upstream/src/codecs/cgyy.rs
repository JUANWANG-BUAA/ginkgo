//! Read-only CGYY projections. No reservation tokens, lock codes or participant data.
use crate::{AppError, ErrorCode};
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
        return Err(AppError::new(ErrorCode::BusinessRejected));
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
pub fn orders(value: &Value) -> Result<Vec<Order>, AppError> {
    let data = envelope(value)?;
    let rows = data["content"]
        .as_array()
        .or_else(|| data["list"].as_array())
        .ok_or_else(AppError::changed)?;
    rows.iter()
        .map(|row| {
            Ok(Order {
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
        })
        .collect()
}
