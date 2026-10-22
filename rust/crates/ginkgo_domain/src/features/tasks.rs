//! Local-only tasks. Linking homework never submits or changes school data.
use crate::AppError;
use chrono::{DateTime, NaiveDate, TimeZone, Utc};
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;

/// Opaque, provider-qualified identity, scoped by the task document's account.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum TaskSource {
    Homework { assignment_id: String },
}

impl TaskSource {
    pub fn homework(assignment_id: &str) -> Result<Self, AppError> {
        let source = Self::Homework {
            assignment_id: assignment_id.into(),
        };
        source.validate()?;
        Ok(source)
    }

    fn validate(&self) -> Result<(), AppError> {
        match self {
            Self::Homework { assignment_id } => {
                if assignment_id.trim().is_empty() {
                    return Err(AppError::invalid());
                }
            }
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Task {
    pub id: String,
    pub title: String,
    /// Empty means no deadline; a calendar date remains a date, not a precise deadline.
    /// Precise deadlines are RFC3339 instants with an explicit offset.
    pub due: String,
    pub completed: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source: Option<TaskSource>,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Document {
    pub version: u32,
    pub tasks: Vec<Task>,
}
pub fn validate(title: &str, due: &str) -> Result<(), AppError> {
    if title.trim().is_empty() || title.chars().count() > 500 || deadline(due).is_err() {
        return Err(AppError::invalid());
    }
    Ok(())
}
/// Parse deadlines for validation and ordering, without rewriting the stored value.
/// A date-only task sorts at the end of that school calendar day, but retains
/// its legacy all-day semantics. This ordering key must not be used as an alarm.
fn deadline(due: &str) -> Result<Option<DateTime<Utc>>, AppError> {
    if due.is_empty() {
        return Ok(None);
    }
    let bytes = due.as_bytes();
    let date_shape = bytes.len() >= 10
        && bytes[..10].iter().enumerate().all(|(i, byte)| {
            if i == 4 || i == 7 {
                *byte == b'-'
            } else {
                byte.is_ascii_digit()
            }
        });
    if !date_shape {
        return Err(AppError::invalid());
    }
    if bytes.len() == 10 {
        let date = NaiveDate::parse_from_str(due, "%Y-%m-%d").map_err(|_| AppError::invalid())?;
        let end_of_day = date
            .and_hms_nano_opt(23, 59, 59, 999_999_999)
            .ok_or_else(AppError::invalid)?;
        return chrono_tz::Asia::Shanghai
            .from_local_datetime(&end_of_day)
            .single()
            .map(|instant| Some(instant.with_timezone(&Utc)))
            .ok_or_else(AppError::invalid);
    }
    // Shared mobile/desktop RFC3339 subset: uppercase separators, mandatory
    // seconds (no leap seconds), and at most nanosecond precision. Chrono alone
    // also accepts lowercase and silently truncates longer fractional seconds.
    if bytes.len() < 20
        || bytes[10] != b'T'
        || !bytes[11..19].iter().enumerate().all(|(i, byte)| {
            if i == 2 || i == 5 {
                *byte == b':'
            } else {
                byte.is_ascii_digit()
            }
        })
        || &bytes[17..19] > b"59".as_slice()
    {
        return Err(AppError::invalid());
    }
    let mut offset_start = 19;
    if bytes[offset_start] == b'.' {
        offset_start += 1;
        let fraction_start = offset_start;
        while bytes.get(offset_start).is_some_and(u8::is_ascii_digit) {
            offset_start += 1;
        }
        if !(1..=9).contains(&(offset_start - fraction_start)) {
            return Err(AppError::invalid());
        }
    }
    let offset = &bytes[offset_start..];
    let valid_offset = offset == b"Z"
        || (offset.len() == 6
            && matches!(offset[0], b'+' | b'-')
            && offset[3] == b':'
            && [offset[1], offset[2], offset[4], offset[5]]
                .iter()
                .all(u8::is_ascii_digit)
            && &offset[1..3] <= b"23".as_slice()
            && &offset[4..6] <= b"59".as_slice());
    if !valid_offset {
        return Err(AppError::invalid());
    }
    DateTime::parse_from_rfc3339(due)
        .map(|instant| Some(instant.with_timezone(&Utc)))
        .map_err(|_| AppError::invalid())
}

/// Compare validated deadlines chronologically, with missing deadlines last.
/// This does not change a date-only task's all-day meaning.
pub fn compare_due(left: &str, right: &str) -> Ordering {
    match (
        deadline(left).ok().flatten(),
        deadline(right).ok().flatten(),
    ) {
        (Some(left), Some(right)) => left.cmp(&right),
        (Some(_), None) => Ordering::Less,
        (None, Some(_)) => Ordering::Greater,
        (None, None) => Ordering::Equal,
    }
}

pub fn parse(value: serde_json::Value) -> Result<Vec<Task>, AppError> {
    let document: Document = serde_json::from_value(value).map_err(|_| AppError::changed())?;
    validate_document(document)
}

/// Decode persisted bytes directly so duplicate object fields are rejected,
/// rather than being silently collapsed by a generic JSON value first.
pub fn parse_bytes(bytes: &[u8]) -> Result<Vec<Task>, AppError> {
    let document: Document = serde_json::from_slice(bytes).map_err(|_| AppError::changed())?;
    validate_document(document)
}

fn validate_document(document: Document) -> Result<Vec<Task>, AppError> {
    if !matches!(document.version, 1 | 2) {
        return Err(AppError::changed());
    }
    let mut ids = std::collections::HashSet::new();
    let mut sources = std::collections::HashSet::new();
    for task in &document.tasks {
        validate(&task.title, &task.due).map_err(|_| AppError::changed())?;
        if task.id.trim().is_empty() || !ids.insert(&task.id) {
            return Err(AppError::changed());
        }
        if let Some(source) = &task.source {
            source.validate().map_err(|_| AppError::changed())?;
            if !sources.insert(source) {
                return Err(AppError::changed());
            }
        }
    }
    Ok(document.tasks)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn deadlines_accept_missing_strict_calendar_dates_and_rfc3339() {
        for due in [
            "",
            "2024-02-29",
            "2026-10-22T23:30:00+08:00",
            "2026-10-22T15:30:00.123Z",
        ] {
            assert_eq!(validate("作业", due), Ok(()), "{due}");
        }
        for due in [
            "2026-02-29",
            "2026-2-03",
            "2026-10-22T24:00:00Z",
            "2026-10-22T18:00:00",
            " 2026-10-22",
            " ",
        ] {
            assert_eq!(validate("作业", due), Err(AppError::invalid()), "{due}");
        }
    }

    #[test]
    fn precise_deadlines_match_the_cross_platform_rfc3339_subset() {
        for due in [
            "2026-10-22t12:00:00Z",
            "2026-10-22T12:00:00z",
            "2026-10-22T12:00Z",
            "2026-10-22T12:00:60Z",
            "2026-10-22T12:00:00.Z",
            "2026-10-22T12:00:00.1234567890Z",
            "2026-10-22T12:00:00+24:00",
            "2026-10-22T12:00:00+08:60",
        ] {
            assert_eq!(validate("作业", due), Err(AppError::invalid()), "{due}");
        }
        for due in [
            "2026-10-22T12:00:00.1Z",
            "2026-10-22T12:00:59.123456789+23:59",
            "2026-10-22T12:00:00-23:59",
        ] {
            assert_eq!(validate("作业", due), Ok(()), "{due}");
        }
    }

    #[test]
    fn due_comparison_uses_instants_and_school_calendar_day_end() {
        assert_eq!(
            compare_due("2026-10-22T12:00:00+08:00", "2026-10-22T04:00:00Z"),
            Ordering::Equal
        );
        assert_eq!(
            compare_due("2026-10-22", "2026-10-22T15:59:59.999999999Z"),
            Ordering::Equal
        );
        assert_eq!(
            compare_due("2026-10-22", "2026-10-22T16:00:00Z"),
            Ordering::Less
        );
        assert_eq!(compare_due("2026-10-22", ""), Ordering::Less);
        assert_eq!(compare_due("", ""), Ordering::Equal);
    }

    #[test]
    fn source_is_optional_but_strict_and_unique_within_a_document() {
        let task = json!({"id":"a", "title":"作业", "due":"", "completed":false, "source":{"kind":"homework", "assignment_id":"spoc:123"}});
        assert!(parse(json!({"version":2, "tasks":[task.clone()]})).is_ok());
        let mut duplicate = task.clone();
        duplicate["id"] = json!("b");
        assert_eq!(
            parse(json!({"version":2, "tasks":[task, duplicate]})),
            Err(AppError::changed())
        );
        let legacy = json!({"id":"old", "title":"旧待办", "due":"2026-10-21", "completed":false});
        assert!(parse(json!({"version":1, "tasks":[legacy]})).is_ok());
    }
}
