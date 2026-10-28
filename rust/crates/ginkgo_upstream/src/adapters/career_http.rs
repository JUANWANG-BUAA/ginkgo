//! Anonymous career-calendar read. No account, cookie reuse or writes.
use crate::{
    auth::session::Session,
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
use ginkgo_domain::features::career::{CareerEvent, CareerEvents};
use std::time::{SystemTime, UNIX_EPOCH};

const BASE: &str = "https://career.buaa.edu.cn";

fn shanghai_timestamp() -> String {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    chrono::DateTime::from_timestamp(now.as_secs() as i64, 0)
        .unwrap_or_default()
        .with_timezone(&chrono_tz::Asia::Shanghai)
        .format("%Y-%m-%dT%H:%M:%S%:z")
        .to_string()
}

pub fn validate_month(month: &str) -> Result<(), AppError> {
    let bytes = month.as_bytes();
    if bytes.len() != 7
        || !bytes[..4].iter().all(u8::is_ascii_digit)
        || bytes[4] != b'-'
        || !bytes[5..].iter().all(u8::is_ascii_digit)
        || month[5..]
            .parse::<u8>()
            .is_ok_and(|value| !(1..=12).contains(&value))
    {
        return Err(AppError::invalid());
    }
    Ok(())
}

fn absolute_url(value: &str) -> String {
    if value.starts_with('/') {
        format!("{BASE}{value}")
    } else {
        value.to_owned()
    }
}

pub async fn load<T: HttpTransport + Sync>(
    session: &Session<T>,
    month: &str,
) -> Result<CareerEvents, AppError> {
    validate_month(month)?;
    let preference = session.route();
    let response = session
        .send_anonymous(
            HttpRequest::get(format!(
                "{BASE}/f/recruitmentFair/ajax_calendar_list?time={month}"
            ))
            .header("Accept", "application/json")
            .header("User-Agent", "Ginkgo/1.0"),
            preference,
        )
        .await?;
    let final_host = url::Url::parse(&response.final_url)
        .ok()
        .and_then(|url| url.host_str().map(str::to_owned));
    if response.status != 200 || final_host.as_deref() != Some("career.buaa.edu.cn") {
        return Err(AppError::with_detail(
            ErrorCode::ServiceUnavailable,
            format!("career_http_{}", response.status),
        ));
    }
    let value: serde_json::Value =
        serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    if value.get("state").and_then(serde_json::Value::as_i64) != Some(1) {
        return Err(AppError::changed());
    }
    let rows = value
        .get("data")
        .and_then(serde_json::Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut events = Vec::new();
    let mut ids = std::collections::BTreeSet::new();
    for row in rows {
        let id = row["id"].as_str().unwrap_or("").trim().to_owned();
        let title = row["title"].as_str().unwrap_or("").trim().to_owned();
        if id.is_empty() || title.is_empty() || !ids.insert(id.clone()) {
            return Err(AppError::changed());
        }
        events.push(CareerEvent {
            campus: row["campus"].as_str().unwrap_or("").trim().to_owned(),
            place: row["field"].as_str().unwrap_or("").trim().to_owned(),
            begins_at: row["startTime"].as_str().unwrap_or("").trim().to_owned(),
            ends_at: row["endTime"].as_str().unwrap_or("").trim().to_owned(),
            fair_type: row["fairTypeName"].as_str().unwrap_or("").trim().to_owned(),
            status: row["status"].as_str().unwrap_or("").trim().to_owned(),
            url: absolute_url(row["url"].as_str().unwrap_or("").trim()),
            id,
            title,
        });
    }
    Ok(CareerEvents {
        month: month.to_owned(),
        events,
        fetched_at: shanghai_timestamp(),
    })
}

#[cfg(test)]
mod tests {
    use super::validate_month;

    #[test]
    fn month_query_is_strict() {
        assert!(validate_month("2026-10").is_ok());
        assert!(validate_month("2026-13").is_err());
        assert!(validate_month("2026-10 ").is_err());
    }
}
