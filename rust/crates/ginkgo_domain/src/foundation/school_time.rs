use crate::AppError;
use chrono::{DateTime, NaiveDateTime, TimeZone, Timelike, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct DayRequest {
    pub instant: String,
}

#[derive(Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct SchoolDay {
    pub time_zone: String,
    pub local_date: String,
    pub minutes_since_midnight: u32,
}

pub fn beijing_day(instant: &str) -> Result<SchoolDay, AppError> {
    let instant = DateTime::parse_from_rfc3339(instant).map_err(|_| AppError::invalid())?;
    let local = instant.with_timezone(&chrono_tz::Asia::Shanghai);
    Ok(SchoolDay {
        time_zone: "Asia/Shanghai".into(),
        local_date: local.format("%Y-%m-%d").to_string(),
        minutes_since_midnight: local.hour() * 60 + local.minute(),
    })
}

/// The instant of a school wall time.
///
/// A bare clock time (`08:00`, `08:00:00`) belongs to `date` when one is
/// given; a full school timestamp or an RFC3339 instant is absolute. Anything
/// else stays unknown: a rule must never invent a lesson or deadline time.
pub fn school_instant(date: Option<&str>, raw: &str) -> Option<DateTime<Utc>> {
    if let Ok(value) = DateTime::parse_from_rfc3339(raw) {
        return Some(value.with_timezone(&Utc));
    }
    let text = match date {
        Some(day) if raw.len() <= 8 => format!("{day} {raw}"),
        _ => raw.to_owned(),
    };
    [
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M",
    ]
    .iter()
    .find_map(|format| NaiveDateTime::parse_from_str(&text, format).ok())
    .and_then(|wall| {
        chrono_tz::Asia::Shanghai
            .from_local_datetime(&wall)
            .single()
    })
    .map(|value| value.with_timezone(&Utc))
}
