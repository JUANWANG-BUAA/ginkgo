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
