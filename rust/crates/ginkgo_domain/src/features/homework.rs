use chrono::{DateTime, NaiveDate, NaiveDateTime, TimeZone};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HomeworkStatus {
    Pending,
    Submitted,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HomeworkDeadlineStatus {
    Active,
    Overdue,
    Undated,
    Invalid,
}

/// Parse a school deadline string into Asia/Shanghai wall instant.
/// Supports unzoned Beijing times (space or T separator, with or without seconds)
/// and zoned RFC3339/ISO-8601 strings.
pub fn parse_school_deadline(text: &str) -> Option<DateTime<chrono_tz::Tz>> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return None;
    }

    // Try RFC3339 first if there is a timezone indicator
    if trimmed.ends_with('Z') || trimmed.contains('+') || (trimmed.len() > 19 && trimmed[19..].contains('-')) {
        if let Ok(parsed) = DateTime::parse_from_rfc3339(trimmed) {
            return Some(parsed.with_timezone(&chrono_tz::Asia::Shanghai));
        }
    }

    // Unzoned school timestamp formats
    let formats = [
        "%Y-%m-%d %H:%M:%S%.f",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%dT%H:%M:%S%.f",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M",
    ];

    for fmt in formats {
        if let Ok(naive) = NaiveDateTime::parse_from_str(trimmed, fmt) {
            if let Some(instant) = chrono_tz::Asia::Shanghai.from_local_datetime(&naive).single() {
                return Some(instant);
            }
        }
    }

    None
}

/// Classify a homework deadline against Beijing wall clock time.
///
/// Follows the specification in docs/NEXT-STAGE-PLAN-2026-10-23.md:
/// - Undated: null or empty
/// - Date-only YYYY-MM-DD: deadline is the end of that day (next-day 00:00:00 is exclusive upper bound)
/// - Exact timestamp: overdue when beijing_now >= deadline
/// - Invalid: malformed or impossible calendar date/time (kept distinct, never coerced to today or overdue)
pub fn classify_deadline(
    due_at: Option<&str>,
    beijing_now: DateTime<chrono_tz::Tz>,
) -> HomeworkDeadlineStatus {
    let Some(raw) = due_at else {
        return HomeworkDeadlineStatus::Undated;
    };
    let text = raw.trim();
    if text.is_empty() {
        return HomeworkDeadlineStatus::Undated;
    }

    // Strict YYYY-MM-DD check
    if text.len() == 10
        && text.as_bytes()[4] == b'-'
        && text.as_bytes()[7] == b'-'
        && text.as_bytes()[..4].iter().all(u8::is_ascii_digit)
        && text.as_bytes()[5..7].iter().all(u8::is_ascii_digit)
        && text.as_bytes()[8..10].iter().all(u8::is_ascii_digit)
    {
        if let Ok(date) = NaiveDate::parse_from_str(text, "%Y-%m-%d") {
            if let Some(next_day) = date.succ_opt() {
                if let Some(next_midnight) = next_day.and_hms_opt(0, 0, 0) {
                    if let Some(threshold) =
                        chrono_tz::Asia::Shanghai.from_local_datetime(&next_midnight).single()
                    {
                        return if beijing_now < threshold {
                            HomeworkDeadlineStatus::Active
                        } else {
                            HomeworkDeadlineStatus::Overdue
                        };
                    }
                }
            }
        }
        return HomeworkDeadlineStatus::Invalid;
    }

    // Timestamp with hour and minute
    if let Some(threshold) = parse_school_deadline(text) {
        return if beijing_now < threshold {
            HomeworkDeadlineStatus::Active
        } else {
            HomeworkDeadlineStatus::Overdue
        };
    }

    HomeworkDeadlineStatus::Invalid
}

pub fn is_homework_overdue(
    due_at: Option<&str>,
    beijing_now: DateTime<chrono_tz::Tz>,
) -> bool {
    classify_deadline(due_at, beijing_now) == HomeworkDeadlineStatus::Overdue
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkItem {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub course_role: Option<String>,
    pub id: String,
    pub course_id: Option<String>,
    pub course_name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub teacher_name: Option<String>,
    pub title: String,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub status: HomeworkStatus,
    pub status_detail: Option<String>,
    pub score: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkPage {
    pub page_num: i32,
    pub pages: Option<i32>,
    pub has_next: Option<bool>,
    pub items: Vec<HomeworkItem>,
}

#[derive(Debug, Clone)]
pub struct HomeworkData {
    pub term_code: String,
    pub term_name: String,
    pub items: Vec<HomeworkItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkDetail {
    /// Validated browser destination supplied by the provider, independent of the UI.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_url: Option<String>,
    pub content: Option<String>,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub score: Option<String>,
    pub status: HomeworkStatus,
    pub status_detail: Option<String>,
    pub submitted_at: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{NaiveDate, TimeZone};

    fn beijing(y: i32, m: u32, d: u32, h: u32, min: u32, s: u32) -> DateTime<chrono_tz::Tz> {
        chrono_tz::Asia::Shanghai
            .from_local_datetime(&NaiveDate::from_ymd_opt(y, m, d).unwrap().and_hms_opt(h, min, s).unwrap())
            .single()
            .unwrap()
    }

    #[test]
    fn test_undated_and_empty() {
        let now = beijing(2026, 10, 23, 12, 0, 0);
        assert_eq!(classify_deadline(None, now), HomeworkDeadlineStatus::Undated);
        assert_eq!(classify_deadline(Some(""), now), HomeworkDeadlineStatus::Undated);
        assert_eq!(classify_deadline(Some("   "), now), HomeworkDeadlineStatus::Undated);
    }

    #[test]
    fn test_date_only_deadline_uses_next_day_midnight_as_exclusive_bound() {
        let deadline = Some("2026-10-23");
        // 2026-10-23 23:59:59 is still within the deadline day -> Active
        let before_midnight = beijing(2026, 10, 23, 23, 59, 59);
        assert_eq!(classify_deadline(deadline, before_midnight), HomeworkDeadlineStatus::Active);

        // 2026-10-24 00:00:00 hits the next day -> Overdue
        let at_midnight = beijing(2026, 10, 24, 0, 0, 0);
        assert_eq!(classify_deadline(deadline, at_midnight), HomeworkDeadlineStatus::Overdue);
    }

    #[test]
    fn test_exact_timestamp_boundary() {
        let deadline = Some("2026-10-23 18:00:00");
        // 17:59:59 is before -> Active
        let before = beijing(2026, 10, 23, 17, 59, 59);
        assert_eq!(classify_deadline(deadline, before), HomeworkDeadlineStatus::Active);

        // 18:00:00 is at deadline -> now >= deadline -> Overdue
        let at = beijing(2026, 10, 23, 18, 0, 0);
        assert_eq!(classify_deadline(deadline, at), HomeworkDeadlineStatus::Overdue);

        // 18:00:01 is past deadline -> Overdue
        let after = beijing(2026, 10, 23, 18, 0, 1);
        assert_eq!(classify_deadline(deadline, after), HomeworkDeadlineStatus::Overdue);
    }

    #[test]
    fn test_zoned_rfc3339_converts_to_beijing_time() {
        // 10:00:00 UTC == 18:00:00 Beijing time
        let utc_deadline = Some("2026-10-23T10:00:00Z");
        let bjt_deadline = Some("2026-10-23T18:00:00+08:00");

        let before = beijing(2026, 10, 23, 17, 59, 59);
        assert_eq!(classify_deadline(utc_deadline, before), HomeworkDeadlineStatus::Active);
        assert_eq!(classify_deadline(bjt_deadline, before), HomeworkDeadlineStatus::Active);

        let at = beijing(2026, 10, 23, 18, 0, 0);
        assert_eq!(classify_deadline(utc_deadline, at), HomeworkDeadlineStatus::Overdue);
        assert_eq!(classify_deadline(bjt_deadline, at), HomeworkDeadlineStatus::Overdue);
    }

    #[test]
    fn test_invalid_dates_rejected_and_never_treated_as_overdue() {
        let now = beijing(2026, 10, 23, 12, 0, 0);
        // Impossible calendar dates
        assert_eq!(classify_deadline(Some("2026-02-30"), now), HomeworkDeadlineStatus::Invalid);
        assert_eq!(classify_deadline(Some("2026-13-01"), now), HomeworkDeadlineStatus::Invalid);
        assert_eq!(classify_deadline(Some("2026-10-32"), now), HomeworkDeadlineStatus::Invalid);
        assert_eq!(classify_deadline(Some("garbage-string"), now), HomeworkDeadlineStatus::Invalid);
        assert_eq!(classify_deadline(Some("2026-10-23 25:00:00"), now), HomeworkDeadlineStatus::Invalid);

        assert!(!is_homework_overdue(Some("2026-02-30"), now));
        assert!(!is_homework_overdue(Some("garbage-string"), now));
    }
}
