//! booking.lib v4 whitelist models and action hints (API.md §5.2, §5.6).
use crate::AppError;
pub use ginkgo_domain::features::library::*;
use serde_json::Value;

pub fn parse_login_user(value: &Value) -> Result<String, AppError> {
    let token = value
        .get("data")
        .and_then(|data| data.get("member"))
        .and_then(|member| member.get("token"))
        .and_then(text)
        .ok_or_else(AppError::changed)?;
    Ok(token)
}

pub fn parse_venues(data: &Value) -> Result<Vec<LibraryVenue>, AppError> {
    let rows = data
        .get("list")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let venues = rows
        .iter()
        .map(|row| {
            let id = required_text(row, "id")?;
            let name = required_text(row, "name")?;
            let free = required_int(row, "free_num")?;
            let total = required_int(row, "total_num")?;
            validate_counts(free, total)?;
            Ok(LibraryVenue {
                id,
                name,
                free,
                total,
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    unique(&venues)
}

pub fn parse_areas(data: &Value) -> Result<Vec<LibraryArea>, AppError> {
    let rows = data
        .get("area")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let areas = rows
        .iter()
        .map(|row| {
            let id = required_text(row, "id")?;
            let name = required_text(row, "name")?;
            let free = required_int(row, "free_num")?;
            let total = required_int(row, "total_num")?;
            validate_counts(free, total)?;
            Ok(LibraryArea {
                id,
                name,
                free,
                total,
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    unique(&areas)
}

pub fn parse_slots(data: &Value) -> Result<Vec<LibrarySlot>, AppError> {
    let rows = data
        .get("date")
        .and_then(|date| date.get("list"))
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut slots = Vec::new();
    for row in rows {
        let day = row
            .get("day")
            .and_then(text)
            .or_else(|| row.get("date").and_then(text))
            .ok_or_else(AppError::changed)?;
        let times = row
            .get("times")
            .and_then(Value::as_array)
            .ok_or_else(AppError::changed)?;
        for slot in times {
            let id = required_text(slot, "id")?;
            let start = required_text(slot, "start")?;
            let end = required_text(slot, "end")?;
            slots.push(LibrarySlot {
                id: format!("{day}/{id}"),
                day: day.clone(),
                start,
                end,
            });
        }
    }
    unique(&slots)
}

pub fn parse_seats(data: &Value) -> Result<Vec<LibrarySeat>, AppError> {
    let rows = data
        .get("list")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let seats = rows
        .iter()
        .map(|row| {
            let id = required_text(row, "id")?;
            let name = row
                .get("name")
                .and_then(text)
                .or_else(|| row.get("no").and_then(text))
                .ok_or_else(AppError::changed)?;
            let status = required_text(row, "status")?;
            let status_name = row
                .get("status_name")
                .and_then(text)
                .or_else(|| row.get("statusName").and_then(text))
                .unwrap_or_default();
            Ok(LibrarySeat {
                id,
                name,
                status_name,
                available: status == "1",
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    unique(&seats)
}

/// The current-booking endpoint answers data as an array; older bodies wrap it
/// in a list object. Both are accepted, anything else is a structure change.
pub fn parse_bookings(data: &Value) -> Result<Vec<LibraryBooking>, AppError> {
    if data.is_null() {
        return Ok(Vec::new());
    }
    let rows = match data {
        Value::Array(rows) => rows.as_slice(),
        Value::Object(_) => data
            .get("list")
            .and_then(Value::as_array)
            .ok_or_else(AppError::changed)?
            .as_slice(),
        _ => return Err(AppError::changed()),
    };
    let bookings = rows
        .iter()
        .map(|row| {
            let id = required_text(row, "id")?;
            let name = first_text(
                row,
                &["nameMerge", "name_merge", "name", "room_name", "space_name"],
            )
            .unwrap_or_default();
            let area_name = first_text(row, &["areaName", "area_name", "name"]).unwrap_or_default();
            let seat_number = first_text(row, &["no", "seat_no", "seatNo"]).unwrap_or_default();
            let space_name = first_text(row, &["spaceName", "space_name"]).unwrap_or_default();
            let title = first_text(row, &["title", "theme"]).unwrap_or_default();
            let raw_day = first_text(row, &["day", "date", "start_date"]).unwrap_or_default();
            let raw_begin =
                first_text(row, &["beginTime", "begin_time", "start_time"]).unwrap_or_default();
            let raw_end =
                first_text(row, &["endTime", "end_time", "finish_time"]).unwrap_or_default();
            let (begin_day, begin) = split_date_time(&raw_begin);
            let (_, end) = split_date_time(&raw_end);
            let day = if raw_day.is_empty() {
                begin_day
            } else {
                raw_day
            };
            let start_time = begin;
            let end_time = if end.is_empty() { raw_end } else { end };
            let status =
                first_text(row, &["status", "statusName", "status_name"]).unwrap_or_default();
            let status_name = first_text(row, &["status_name", "statusName"])
                .unwrap_or_else(|| default_status_name(&status));
            let display = if !name.is_empty() {
                name
            } else if !space_name.is_empty() {
                space_name
            } else if !title.is_empty() {
                title
            } else {
                [area_name.as_str(), seat_number.as_str()]
                    .iter()
                    .filter(|value| !value.is_empty())
                    .copied()
                    .collect::<Vec<_>>()
                    .join(" · ")
            };
            Ok(LibraryBooking {
                id,
                title: display,
                area_name,
                seat_number,
                day,
                start_time,
                end_time,
                status,
                status_name,
                booking_type: row
                    .get("type")
                    .or_else(|| row.get("type_id"))
                    .and_then(|v| {
                        v.as_i64()
                            .and_then(|n| i32::try_from(n).ok())
                            .or_else(|| v.as_str()?.parse().ok())
                    }),
                can_cancel: flag(row.get("oksign").or_else(|| row.get("okSign"))),
                flag_in: flag(row.get("flag_in").or_else(|| row.get("flagIn"))),
                flag_out: flag(row.get("flag_out").or_else(|| row.get("flagOut"))),
                flag_leave: flag(row.get("flag_leave").or_else(|| row.get("flagLeave"))),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    unique(&bookings)
}

fn default_status_name(status: &str) -> String {
    match status {
        "6" => "已取消",
        "8" => "已结束",
        "1" => "进行中",
        _ => "",
    }
    .to_owned()
}

fn validate_counts(free: i32, total: i32) -> Result<(), AppError> {
    if free < 0 || total < 0 || total < free {
        return Err(AppError::changed());
    }
    Ok(())
}

fn unique<T: HasId + Clone>(items: &[T]) -> Result<Vec<T>, AppError> {
    let mut seen = std::collections::BTreeSet::new();
    for item in items {
        if !seen.insert(item.id()) {
            return Err(AppError::changed());
        }
    }
    Ok(items.to_vec())
}

trait HasId {
    fn id(&self) -> &str;
}

impl HasId for LibraryVenue {
    fn id(&self) -> &str {
        &self.id
    }
}
impl HasId for LibraryArea {
    fn id(&self) -> &str {
        &self.id
    }
}
impl HasId for LibrarySlot {
    fn id(&self) -> &str {
        &self.id
    }
}
impl HasId for LibrarySeat {
    fn id(&self) -> &str {
        &self.id
    }
}
impl HasId for LibraryBooking {
    fn id(&self) -> &str {
        &self.id
    }
}

fn required_text(row: &Value, key: &str) -> Result<String, AppError> {
    row.get(key).and_then(text).ok_or_else(AppError::changed)
}

fn required_int(row: &Value, key: &str) -> Result<i32, AppError> {
    row.get(key).and_then(integer).ok_or_else(AppError::changed)
}

fn first_text(row: &Value, keys: &[&str]) -> Option<String> {
    keys.iter().find_map(|key| {
        row.get(*key)
            .and_then(text)
            .filter(|value| !value.is_empty())
    })
}

fn text(value: &Value) -> Option<String> {
    match value {
        Value::String(text) => {
            let text = text.trim();
            (!text.is_empty()).then(|| text.to_owned())
        }
        Value::Number(number) => Some(number.to_string()),
        _ => None,
    }
}

fn integer(value: &Value) -> Option<i32> {
    match value {
        Value::Number(number) => number.as_i64().and_then(|value| i32::try_from(value).ok()),
        Value::String(text) => text.trim().parse::<i32>().ok(),
        _ => None,
    }
}

fn split_date_time(value: &str) -> (String, String) {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return (String::new(), String::new());
    }
    for separator in [' ', 'T'] {
        if let Some((day, time)) = trimmed.split_once(separator) {
            if day.len() == 10 && !time.is_empty() {
                return (day.to_owned(), time.to_owned());
            }
        }
    }
    (String::new(), trimmed.to_owned())
}

/// member/seat pagination, matching LibraryClient.swift:392–453.
pub fn parse_history(
    data: &Value,
    requested_page: i32,
    limit: i32,
) -> Result<LibraryHistoryPage, AppError> {
    if requested_page < 1 || !(1..=100).contains(&limit) {
        return Err(AppError::invalid());
    }
    let rows = data
        .get("data")
        .or_else(|| data.get("list"))
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    // Unlike current bookings, a history record must include its status.
    if rows
        .iter()
        .any(|row| first_text(row, &["status", "status_name", "statusName"]).is_none())
    {
        return Err(AppError::changed());
    }
    let bookings = parse_bookings(&Value::Array(rows.clone()))?;
    fn number(data: &Value, keys: &[&str]) -> Result<Option<i64>, AppError> {
        match keys
            .iter()
            .filter_map(|key| data.get(key))
            .find(|value| !value.is_null())
        {
            None => Ok(None),
            Some(value) => value
                .as_i64()
                .or_else(|| value.as_str()?.parse().ok())
                .map(Some)
                .ok_or_else(AppError::changed),
        }
    }
    let page = number(data, &["current_page", "page"])?.unwrap_or(i64::from(requested_page));
    let page_size = number(data, &["per_page", "limit"])?.unwrap_or(i64::from(limit));
    let total = number(data, &["total", "count"])?;
    let last = number(data, &["last_page", "lastPage"])?;
    let explicit_next = match data
        .get("has_more")
        .or_else(|| data.get("hasNextPage"))
        .filter(|v| !v.is_null())
    {
        None => None,
        Some(value) => Some(match value.as_bool() {
            Some(value) => value,
            None => match value.as_i64().or_else(|| value.as_str()?.parse().ok()) {
                Some(0) => false,
                Some(1) => true,
                _ => return Err(AppError::changed()),
            },
        }),
    };
    if page != i64::from(requested_page)
        || !(1..=100).contains(&page_size)
        || total.is_some_and(|n| n < 0)
        || last.is_some_and(|n| n < 0)
        || rows.len() as i64 > page_size
        || (total.is_none()
            && last.is_none()
            && explicit_next.is_none()
            && rows.len() as i64 != page_size)
    {
        return Err(AppError::changed());
    }
    let by_total = total.map(|n| page * page_size < n);
    let by_last = last.map(|n| page < n);
    if explicit_next.is_some_and(|next| {
        by_total.is_some_and(|n| next != n) || by_last.is_some_and(|n| next != n)
    }) || by_total.zip(by_last).is_some_and(|(a, b)| a != b)
        || total.is_some_and(|n| !rows.is_empty() && (page - 1) * page_size + rows.len() as i64 > n)
    {
        return Err(AppError::changed());
    }
    Ok(LibraryHistoryPage {
        bookings,
        page: requested_page,
        page_size: page_size as i32,
        total,
        has_next: explicit_next
            .or(by_last)
            .or(by_total)
            .unwrap_or(rows.len() as i64 == page_size),
    })
}

fn flag(value: Option<&Value>) -> Option<bool> {
    match value? {
        Value::Bool(b) => Some(*b),
        Value::Number(n) => n.as_i64().map(|n| n != 0),
        Value::String(s) => match s.trim().to_ascii_lowercase().as_str() {
            "1" | "true" | "yes" => Some(true),
            "0" | "false" | "no" | "" => Some(false),
            _ => None,
        },
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn venues_and_areas_require_consistent_counts() {
        let venues = parse_venues(&json!({
            "list": [
                {"id": "1", "name": "学院路馆", "free_num": 12, "total_num": 30, "children": []},
                {"id": "2", "name": "沙河馆", "free_num": "0", "total_num": 8}
            ]
        }))
        .expect("venues");
        assert_eq!(venues.len(), 2);
        assert_eq!(venues[1].free, 0);
        assert_eq!(
            parse_venues(
                &json!({"list": [{"id": "1", "name": "x", "free_num": 9, "total_num": 2}]})
            )
            .expect_err("impossible counts")
            .code,
            crate::ErrorCode::ChangedResponse
        );
    }

    #[test]
    fn slots_compose_a_day_scoped_id_and_reject_duplicates() {
        let slots = parse_slots(&json!({
            "date": {"list": [
                {"day": "2026-10-20", "times": [
                    {"id": "1", "start": "08:00", "end": "10:00"},
                    {"id": "2", "start": "10:00", "end": "12:00"}
                ]},
                {"date": "2026-10-21", "times": [
                    {"id": "1", "start": "08:00", "end": "10:00"}
                ]}
            ]}
        }))
        .expect("slots");
        assert_eq!(slots.len(), 3);
        assert_eq!(slots[0].id, "2026-10-20/1");
        assert_eq!(slots[2].day, "2026-10-21");
    }

    #[test]
    fn seats_use_status_one_as_available() {
        let seats = parse_seats(&json!({
            "list": [
                {"id": "a", "name": "A-01", "status": "1", "status_name": "空闲"},
                {"id": "b", "no": "B-02", "status": 0, "statusName": "占用"}
            ]
        }))
        .expect("seats");
        assert!(seats[0].available);
        assert!(!seats[1].available);
        assert_eq!(seats[1].name, "B-02");
    }

    #[test]
    fn bookings_accept_camel_and_snake_fields_without_member_identity() {
        let bookings = parse_bookings(&json!([
            {
                "id": "77",
                "nameMerge": "学院路馆 · A区 · 12号",
                "areaName": "A区",
                "no": "12",
                "day": "2026-10-20",
                "beginTime": "2026-10-20 08:00:00",
                "endTime": "2026-10-20 12:00:00",
                "status": 1,
                "status_name": "使用中",
                "member": {"name": "should not be read"}
            }
        ]))
        .expect("bookings");
        assert_eq!(bookings[0].title, "学院路馆 · A区 · 12号");
        assert_eq!(bookings[0].start_time, "08:00:00");
        assert_eq!(bookings[0].end_time, "12:00:00");
        assert_eq!(bookings[0].status_name, "使用中");
    }

    #[test]
    fn empty_booking_data_is_a_valid_empty_list() {
        assert!(parse_bookings(&Value::Null).expect("empty").is_empty());
        assert!(parse_bookings(&json!([])).expect("empty array").is_empty());
    }
}
