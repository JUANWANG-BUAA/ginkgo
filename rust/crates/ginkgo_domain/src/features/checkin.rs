#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CheckInStatus {
    NotSigned,
    Signed,
    /// Upstream returned a value outside the documented 0/1 pair.
    Unknown,
}

impl CheckInStatus {
    pub fn name(self) -> &'static str {
        match self {
            Self::NotSigned => "notSigned",
            Self::Signed => "signed",
            Self::Unknown => "unknown",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckInCourse {
    pub id: String,
    pub course_id: Option<String>,
    pub course_num: Option<String>,
    pub course_name: String,
    pub begins_at: String,
    pub ends_at: String,
    pub status: CheckInStatus,
    pub teacher_name: Option<String>,
    pub classroom_name: Option<String>,
    pub merged_record_count: usize,
    pub conflicting: bool,
    pub sign_in_allowed: bool,
}

/// Product rule: opens ten minutes before class, closes at its end. Parse
/// school wall times explicitly; malformed/other-day data must fail closed.
pub fn sign_in_window(date: &str, begin: &str, end: &str, now: &str) -> bool {
    use chrono::{DateTime, Duration, NaiveDateTime, TimeZone};
    fn instant(date: &str, raw: &str) -> Option<DateTime<chrono::FixedOffset>> {
        if let Ok(value) = DateTime::parse_from_rfc3339(raw) {
            return Some(value);
        }
        let text = if raw.len() <= 8 {
            format!("{date} {raw}")
        } else {
            raw.to_owned()
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
        .map(|value| value.fixed_offset())
    }
    let Some((start, finish, now)) = instant(date, begin)
        .zip(instant(date, end))
        .zip(DateTime::parse_from_rfc3339(now).ok())
        .map(|((a, b), c)| (a, b, c))
    else {
        return false;
    };
    now.with_timezone(&chrono_tz::Asia::Shanghai)
        .format("%Y-%m-%d")
        .to_string()
        == date
        && start
            .with_timezone(&chrono_tz::Asia::Shanghai)
            .format("%Y-%m-%d")
            .to_string()
            == date
        && finish > start
        && now >= start - Duration::minutes(10)
        && now < finish
}

#[cfg(test)]
mod window_tests {
    use super::sign_in_window;
    #[test]
    fn boundaries_and_time_zones() {
        let open = |now| sign_in_window("2026-10-20", "08:00", "09:00", now);
        assert!(!open("2026-10-20T07:49:59+08:00"));
        assert!(open("2026-10-20T07:50:00+08:00"));
        assert!(open("2026-10-20T00:00:00Z"));
        assert!(!open("2026-10-20T09:00:00+08:00"));
        assert!(!open("2026-10-19T08:00:00+08:00"));
        assert!(!sign_in_window(
            "2026-10-20",
            "?",
            "09:00",
            "2026-10-20T08:00:00+08:00"
        ));
    }
}
