//! Local reminder planning. No scheduling, school I/O or inferred lesson times.
use chrono::{DateTime, Datelike, Duration, NaiveDate, NaiveTime, TimeZone, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CourseReminderInput {
    pub id: String,
    /// First day of the queried week, not the phone's current week.
    pub week_start: String,
    pub day: i32,
    pub starts_at: String,
    pub ends_at: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TaskReminderInput {
    pub id: String,
    /// Only a validated precise RFC3339 instant is eligible; date-only is not an alarm.
    pub due: String,
    pub completed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalReminderPlan {
    pub key: String,
    pub group: String,
    pub at_millis: i64,
    pub expires_millis: i64,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReminderPlanningResult {
    pub plans: Vec<LocalReminderPlan>,
    pub skipped: u32,
}

/// Course: ten minutes before an explicitly timed lesson, expires at lesson start.
/// Personal task: 24 hours before its precise deadline, expires at that deadline.
/// Discovering inside the window gives one catch-up plan, never a synthetic deadline.
/// Exact duplicate occurrences coalesce. Conflicting plans for the same occurrence
/// are omitted rather than choosing the first; separate timed meetings stay separate.
pub fn plan_local_reminders(
    courses: &[CourseReminderInput],
    tasks: &[TaskReminderInput],
    now_millis: i64,
) -> ReminderPlanningResult {
    let Some(now) = DateTime::<Utc>::from_timestamp_millis(now_millis) else {
        return ReminderPlanningResult {
            plans: vec![],
            skipped: (courses.len() + tasks.len()).try_into().unwrap_or(u32::MAX),
        };
    };
    let mut result = ReminderPlanningResult::default();
    let mut plans = BTreeMap::<String, Option<LocalReminderPlan>>::new();
    for input in courses {
        let plan = course_plan(input, now);
        insert(&mut plans, plan, &mut result.skipped);
    }
    for input in tasks {
        if input.completed {
            continue;
        }
        insert(&mut plans, task_plan(input, now), &mut result.skipped);
    }
    result.plans = plans.into_values().flatten().collect();
    result.plans.sort_by(|a, b| {
        a.at_millis
            .cmp(&b.at_millis)
            .then_with(|| a.key.cmp(&b.key))
    });
    result
}

fn insert(
    plans: &mut BTreeMap<String, Option<LocalReminderPlan>>,
    candidate: Option<LocalReminderPlan>,
    skipped: &mut u32,
) {
    let Some(candidate) = candidate else {
        *skipped = skipped.saturating_add(1);
        return;
    };
    let identity = candidate.key.clone();
    match plans.entry(identity) {
        std::collections::btree_map::Entry::Vacant(entry) => {
            entry.insert(Some(candidate));
        }
        std::collections::btree_map::Entry::Occupied(mut entry) => {
            if entry.get().as_ref() != Some(&candidate) {
                entry.insert(None);
                *skipped = skipped.saturating_add(1);
            }
        }
    }
}

fn valid_id(id: &str) -> bool {
    !id.trim().is_empty() && id.len() <= 256 && !id.chars().any(char::is_control)
}

fn time(raw: &str) -> Option<NaiveTime> {
    // Do not let flexible parsing invent missing components.
    let format = match raw.len() {
        5 => "%H:%M",
        8 => "%H:%M:%S",
        _ => return None,
    };
    let value = NaiveTime::parse_from_str(raw, format).ok()?;
    // Reject flexible widths and leap seconds; a school wall time is exact.
    (value.format(format).to_string() == raw && !raw.ends_with(":60")).then_some(value)
}

fn course_plan(input: &CourseReminderInput, now: DateTime<Utc>) -> Option<LocalReminderPlan> {
    if !valid_id(&input.id) || !(1..=7).contains(&input.day) || input.week_start.len() != 10 {
        return None;
    }
    let week = NaiveDate::parse_from_str(&input.week_start, "%Y-%m-%d").ok()?;
    if week.weekday().number_from_monday() != 1 {
        return None;
    }
    let day = week.checked_add_signed(Duration::days(i64::from(input.day - 1)))?;
    let start = chrono_tz::Asia::Shanghai
        .from_local_datetime(&day.and_time(time(&input.starts_at)?))
        .single()?
        .with_timezone(&Utc);
    let end = chrono_tz::Asia::Shanghai
        .from_local_datetime(&day.and_time(time(&input.ends_at)?))
        .single()?
        .with_timezone(&Utc);
    if end <= start || start <= now {
        return None;
    }
    Some(LocalReminderPlan {
        // Length-prefixed identity prevents delimiters in upstream ids colliding.
        key: format!(
            "course:{}:{}:{day}:{}",
            input.id.len(),
            input.id,
            start.timestamp_millis()
        ),
        group: "course".into(),
        at_millis: start
            .checked_sub_signed(Duration::minutes(10))?
            .timestamp_millis(),
        expires_millis: start.timestamp_millis(),
    })
}

fn task_plan(input: &TaskReminderInput, now: DateTime<Utc>) -> Option<LocalReminderPlan> {
    if !valid_id(&input.id)
        || input.due.len() <= 10
        || super::tasks::validate("task", &input.due).is_err()
    {
        return None;
    }
    let due = DateTime::parse_from_rfc3339(&input.due)
        .ok()?
        .with_timezone(&Utc);
    if due <= now {
        return None;
    }
    Some(LocalReminderPlan {
        key: format!(
            "task:{}:{}:{}:24",
            input.id.len(),
            input.id,
            due.timestamp_millis()
        ),
        group: "task".into(),
        at_millis: due
            .checked_sub_signed(Duration::hours(24))?
            .timestamp_millis(),
        expires_millis: due.timestamp_millis(),
    })
}

/// A check-in session that may still need a reminder.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CheckInReminderInput {
    pub id: String,
    /// The queried school day, not the phone's current day.
    pub date: String,
    pub begins_at: String,
    pub ends_at: String,
    /// True only when the session is exactly "not signed". An unknown status
    /// is not signable, so it never schedules a reminder.
    pub not_signed: bool,
    pub conflicting: bool,
    /// Explicit false covers merged sessions with conflicting records.
    pub sign_in_allowed: Option<bool>,
    pub merged_record_count: usize,
}

/// A school assignment that may still need a deadline reminder.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HomeworkReminderInput {
    pub id: String,
    /// The school deadline string. An unparsable deadline plans nothing.
    pub due_at: String,
    pub pending: bool,
}

/// Plan the check-in and assignment reminders.
///
/// Check-in: ten minutes before a signable session on the queried day, expiring
/// at its end. A signed, conflicting or merged session plans nothing.
///
/// Assignment: 24 and 48 hours before a pending deadline, expiring at it.
/// Discovering inside the last 24 hours yields only the 24-hour plan, never a
/// second historical stage.
///
/// Duplicate sessions collapse by id, and identical plans coalesce. Both rules
/// live here, in the domain, so the Dart side only presents the outcome.
pub fn plan_checkin_homework_reminders(
    checkin: &[CheckInReminderInput],
    homework: &[HomeworkReminderInput],
    now_millis: i64,
) -> ReminderPlanningResult {
    let Some(now) = DateTime::<Utc>::from_timestamp_millis(now_millis) else {
        return ReminderPlanningResult {
            plans: vec![],
            skipped: (checkin.len() + homework.len())
                .try_into()
                .unwrap_or(u32::MAX),
        };
    };
    let mut result = ReminderPlanningResult::default();
    let mut plans = BTreeMap::<String, Option<LocalReminderPlan>>::new();
    let mut seen = std::collections::BTreeSet::new();
    for input in checkin {
        // The same session can appear twice when the school repeats it.
        if !seen.insert(input.id.clone()) {
            continue;
        }
        insert(&mut plans, checkin_plan(input, now), &mut result.skipped);
    }
    for input in homework {
        let candidates = homework_plans(input, now);
        if candidates.is_empty() {
            result.skipped = result.skipped.saturating_add(1);
            continue;
        }
        for candidate in candidates {
            insert(&mut plans, Some(candidate), &mut result.skipped);
        }
    }
    result.plans = plans.into_values().flatten().collect();
    result.plans.sort_by(|a, b| {
        a.at_millis
            .cmp(&b.at_millis)
            .then_with(|| a.key.cmp(&b.key))
    });
    result
}

fn checkin_plan(input: &CheckInReminderInput, now: DateTime<Utc>) -> Option<LocalReminderPlan> {
    if !valid_id(&input.id) || !input.not_signed || input.conflicting {
        return None;
    }
    // A merged session is only signable when the school says so.
    let allowed = input
        .sign_in_allowed
        .unwrap_or(input.merged_record_count == 1);
    if !allowed {
        return None;
    }
    let start =
        super::super::foundation::school_time::school_instant(Some(&input.date), &input.begins_at)?;
    let end =
        super::super::foundation::school_time::school_instant(Some(&input.date), &input.ends_at)?;
    if end <= start || start <= now {
        return None;
    }
    // The session belongs to the queried day; a stale day never reminds.
    if start
        .with_timezone(&chrono_tz::Asia::Shanghai)
        .format("%Y-%m-%d")
        .to_string()
        != input.date
    {
        return None;
    }
    Some(LocalReminderPlan {
        // Length-prefixed identity prevents delimiters in upstream ids colliding.
        key: format!(
            "checkin:{}:{}:{}:{}",
            input.date,
            input.id.len(),
            input.id,
            start.timestamp_millis()
        ),
        group: "checkin".into(),
        at_millis: start
            .checked_sub_signed(Duration::minutes(10))?
            .timestamp_millis(),
        expires_millis: end.timestamp_millis(),
    })
}

fn homework_plans(input: &HomeworkReminderInput, now: DateTime<Utc>) -> Vec<LocalReminderPlan> {
    if !valid_id(&input.id) || !input.pending {
        return vec![];
    }
    let Some(due) = super::super::foundation::school_time::school_instant(None, &input.due_at)
    else {
        return vec![];
    };
    if due <= now {
        return vec![];
    }
    let mut plans = vec![];
    for hours in [48, 24] {
        let at = match due.checked_sub_signed(Duration::hours(hours)) {
            Some(value) => value,
            None => continue,
        };
        // Inside the last 24 hours only the close-in plan is new; the 48-hour
        // stage would fire for a moment that has already passed.
        if hours == 48 {
            let inner = due.checked_sub_signed(Duration::hours(24));
            if let Some(inner) = inner {
                if now >= inner {
                    continue;
                }
            }
        }
        plans.push(LocalReminderPlan {
            key: format!(
                "homework:{}:{}:{}:{}",
                input.id.len(),
                input.id,
                due.timestamp_millis(),
                hours
            ),
            group: "homework".into(),
            at_millis: at.timestamp_millis(),
            expires_millis: due.timestamp_millis(),
        });
    }
    plans
}

#[cfg(test)]
mod tests {
    use super::*;
    fn now() -> i64 {
        DateTime::parse_from_rfc3339("2026-10-26T07:50:00+08:00")
            .unwrap()
            .timestamp_millis()
    }
    fn course() -> CourseReminderInput {
        CourseReminderInput {
            id: "synthetic".into(),
            week_start: "2026-10-26".into(),
            day: 1,
            starts_at: "08:00".into(),
            ends_at: "09:40".into(),
        }
    }
    fn task(due: &str) -> TaskReminderInput {
        TaskReminderInput {
            id: "synthetic".into(),
            due: due.into(),
            completed: false,
        }
    }
    #[test]
    fn course_uses_queried_monday_and_beijing_not_device_zone() {
        let result = plan_local_reminders(&[course()], &[], now());
        assert_eq!(result.plans[0].at_millis, now());
        assert_eq!(result.plans[0].expires_millis, now() + 600_000);
        assert!(plan_local_reminders(&[course()], &[], now() + 600_000)
            .plans
            .is_empty());
        let mut value = course();
        value.day = 7;
        assert_eq!(
            plan_local_reminders(&[value], &[], now()).plans[0].at_millis,
            now() + 6 * 86_400_000
        );
    }
    #[test]
    fn unknown_or_invalid_course_times_do_not_infer_section_times() {
        for (day, start, end, week) in [
            (0, "08:00", "09:00", "2026-10-26"),
            (1, "", "09:00", "2026-10-26"),
            (1, "08:00", "07:00", "2026-10-26"),
            (1, "08:00", "09:00", "2026-10-27"),
            (1, "25:00", "26:00", "2026-10-26"),
        ] {
            let mut value = course();
            value.day = day;
            value.starts_at = start.into();
            value.ends_at = end.into();
            value.week_start = week.into();
            assert_eq!(plan_local_reminders(&[value], &[], now()).skipped, 1);
        }
    }
    #[test]
    fn task_only_precise_deadlines_no_all_day_or_completed_or_expired() {
        let values = vec![
            task("2026-10-27T07:50:00+08:00"),
            task("2026-10-27"),
            task(""),
            task("2026-10-26T07:50:00+08:00"),
            TaskReminderInput {
                completed: true,
                ..task("2026-10-27T08:00:00+08:00")
            },
        ];
        let result = plan_local_reminders(&[], &values, now());
        assert_eq!(result.plans.len(), 1);
        assert_eq!(result.plans[0].at_millis, now());
        assert_eq!(result.skipped, 3);
    }
    fn checkin() -> CheckInReminderInput {
        CheckInReminderInput {
            id: "synthetic".into(),
            date: "2026-10-26".into(),
            begins_at: "08:00".into(),
            ends_at: "09:00".into(),
            not_signed: true,
            conflicting: false,
            sign_in_allowed: None,
            merged_record_count: 1,
        }
    }
    fn homework(due: &str) -> HomeworkReminderInput {
        HomeworkReminderInput {
            id: "synthetic".into(),
            due_at: due.into(),
            pending: true,
        }
    }
    #[test]
    fn a_signable_session_reminds_ten_minutes_before_its_start() {
        let result = plan_checkin_homework_reminders(&[checkin()], &[], now());
        assert_eq!(result.plans.len(), 1);
        assert_eq!(result.plans[0].group, "checkin");
        // 08:00 minus ten minutes is the current instant.
        assert_eq!(result.plans[0].at_millis, now());
        assert_eq!(result.plans[0].expires_millis, now() + 70 * 60_000);
    }
    #[test]
    fn signed_conflicting_or_merged_sessions_never_remind() {
        let mut signed = checkin();
        signed.not_signed = false;
        let mut conflicting = checkin();
        conflicting.conflicting = true;
        let mut merged = checkin();
        merged.merged_record_count = 2;
        let mut merged_allowed = merged.clone();
        merged_allowed.sign_in_allowed = Some(true);
        for input in [signed, conflicting, merged] {
            let result = plan_checkin_homework_reminders(&[input], &[], now());
            assert!(result.plans.is_empty());
            assert_eq!(result.skipped, 1);
        }
        let result = plan_checkin_homework_reminders(&[merged_allowed], &[], now());
        assert_eq!(result.plans.len(), 1);
    }
    #[test]
    fn a_session_of_another_day_or_a_duplicate_session_never_reminds_twice() {
        // The session falls on another day than the queried one.
        let mut other_day = checkin();
        other_day.begins_at = "2026-10-27 08:00".into();
        other_day.ends_at = "2026-10-27 09:00".into();
        let result = plan_checkin_homework_reminders(&[other_day], &[], now());
        assert!(result.plans.is_empty());
        let result = plan_checkin_homework_reminders(&[checkin(), checkin()], &[], now());
        assert_eq!(result.plans.len(), 1);
    }
    #[test]
    fn a_pending_assignment_reminds_at_48_and_24_hours_but_only_once_when_close() {
        let far = homework("2026-10-30T08:00:00+08:00");
        let result = plan_checkin_homework_reminders(&[], &[far], now());
        assert_eq!(result.plans.len(), 2);
        assert!(result.plans[0].key.ends_with(":48"));
        assert!(result.plans[1].key.ends_with(":24"));
        // Inside the last 24 hours only the close-in plan is new.
        let close = homework("2026-10-27T06:00:00+08:00");
        let result = plan_checkin_homework_reminders(&[], &[close], now());
        assert_eq!(result.plans.len(), 1);
        assert!(result.plans[0].key.ends_with(":24"));
    }
    #[test]
    fn a_submitted_unparsable_or_passed_assignment_never_reminds() {
        let mut submitted = homework("2026-10-30T08:00:00+08:00");
        submitted.pending = false;
        let values = [
            submitted,
            homework("2026-10-30"),
            homework("not-a-date"),
            homework("2026-10-26T07:50:00+08:00"),
        ];
        let result = plan_checkin_homework_reminders(&[], &values, now());
        assert!(result.plans.is_empty());
        assert_eq!(result.skipped, 4);
    }
    #[test]
    fn catch_up_has_one_stable_identity_and_success_empty_is_empty() {
        let values = [
            task("2026-10-27T00:00:00Z"),
            task("2026-10-27T08:00:00+08:00"),
        ];
        let first = plan_local_reminders(&[], &values, now());
        assert_eq!(first.plans.len(), 1);
        assert_eq!(
            first.plans,
            plan_local_reminders(&[], &values, now() + 60_000).plans
        );
        assert_eq!(
            plan_local_reminders(&[], &[], now()),
            ReminderPlanningResult::default()
        );
    }
}
