use crate::AppError;
use chrono::{DateTime, Timelike};
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
