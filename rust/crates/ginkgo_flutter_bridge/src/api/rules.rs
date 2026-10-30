//! Pure school-rule commands. They never touch the session or the network:
//! the domain owns the rules, and the Dart side only presents the outcome.
use ginkgo_core::features::{checkin, homework};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HomeworkDeadlineStatus {
    Active,
    Overdue,
    Undated,
    Invalid,
}

impl From<homework::HomeworkDeadlineStatus> for HomeworkDeadlineStatus {
    fn from(status: homework::HomeworkDeadlineStatus) -> Self {
        match status {
            homework::HomeworkDeadlineStatus::Active => Self::Active,
            homework::HomeworkDeadlineStatus::Overdue => Self::Overdue,
            homework::HomeworkDeadlineStatus::Undated => Self::Undated,
            homework::HomeworkDeadlineStatus::Invalid => Self::Invalid,
        }
    }
}

/// Classify a school deadline against the Beijing wall clock.
///
/// The domain rule is the only implementation. `now_millis` is an absolute
/// instant; a date-only deadline means the end of that school day.
#[flutter_rust_bridge::frb(sync)]
pub fn classify_homework_deadline(
    due_at: Option<String>,
    now_millis: i64,
) -> HomeworkDeadlineStatus {
    let Some(now) = chrono::DateTime::<chrono::Utc>::from_timestamp_millis(now_millis) else {
        return HomeworkDeadlineStatus::Invalid;
    };
    homework::classify_deadline(
        due_at.as_deref(),
        now.with_timezone(&chrono_tz::Asia::Shanghai),
    )
    .into()
}

/// Whether a check-in session accepts a sign-in at `now_millis`.
///
/// The same domain rule guards the write in the upstream, so the button the
/// page offers and the submission the school accepts cannot disagree.
#[flutter_rust_bridge::frb(sync)]
pub fn checkin_sign_in_window(
    date: String,
    begins_at: String,
    ends_at: String,
    now_millis: i64,
) -> bool {
    let Some(now) = chrono::DateTime::<chrono::Utc>::from_timestamp_millis(now_millis) else {
        return false;
    };
    checkin::sign_in_window(&date, &begins_at, &ends_at, &now.to_rfc3339())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_deadline_and_window_rules_match_the_shared_table() {
        let now = chrono::DateTime::parse_from_rfc3339("2026-10-20T16:00:00Z")
            .unwrap()
            .timestamp_millis();
        assert_eq!(
            classify_homework_deadline(Some("2026-10-20".into()), now),
            HomeworkDeadlineStatus::Overdue
        );
        assert_eq!(
            classify_homework_deadline(Some("2026-10-20".into()), now - 1),
            HomeworkDeadlineStatus::Active
        );
        assert_eq!(
            classify_homework_deadline(None, now),
            HomeworkDeadlineStatus::Undated
        );
        assert_eq!(
            classify_homework_deadline(Some("not-a-date".into()), now),
            HomeworkDeadlineStatus::Invalid
        );
        // 08:30 on the queried day sits inside the window; the same instant
        // on the previous day is before it opens.
        assert!(checkin_sign_in_window(
            "2026-10-20".into(),
            "08:00".into(),
            "09:00".into(),
            chrono::DateTime::parse_from_rfc3339("2026-10-20T00:30:00Z")
                .unwrap()
                .timestamp_millis()
        ));
        assert!(!checkin_sign_in_window(
            "2026-10-20".into(),
            "08:00".into(),
            "09:00".into(),
            now - 24 * 3_600_000
        ));
        assert!(!checkin_sign_in_window(
            "2026-10-20".into(),
            "08:00".into(),
            "09:00".into(),
            now
        ));
    }
}
