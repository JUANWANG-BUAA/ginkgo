//! Pure local planning command, independent from session/network initialization.
use ginkgo_core::features::reminders::{
    self, CheckInReminderInput, CourseReminderInput, HomeworkReminderInput, TaskReminderInput,
};

pub struct CourseReminderSeed {
    pub id: String,
    pub week_start: String,
    pub day: i32,
    pub starts_at: String,
    pub ends_at: String,
}

pub struct TaskReminderSeed {
    pub id: String,
    pub due: String,
    pub completed: bool,
}

pub struct PlannedReminder {
    pub key: String,
    pub group: String,
    pub at_millis: i64,
    pub expires_millis: i64,
}

pub struct ReminderPlanResponse {
    pub plans: Vec<PlannedReminder>,
    pub skipped: u32,
    pub unsupported: bool,
}

/// Data-only plans. Calling this never requests notification permissions or sends notifications.
#[flutter_rust_bridge::frb(sync)]
pub fn plan_course_task_reminders(
    courses: Vec<CourseReminderSeed>,
    tasks: Vec<TaskReminderSeed>,
    now_millis: i64,
) -> ReminderPlanResponse {
    // Bound FFI processing. Oversized requests fail closed rather than truncate unnoticed.
    if courses.len() > 500 || tasks.len() > 2000 {
        return ReminderPlanResponse {
            plans: vec![],
            skipped: 0,
            unsupported: true,
        };
    }
    let courses = courses
        .into_iter()
        .map(|v| CourseReminderInput {
            id: v.id,
            week_start: v.week_start,
            day: v.day,
            starts_at: v.starts_at,
            ends_at: v.ends_at,
        })
        .collect::<Vec<_>>();
    let tasks = tasks
        .into_iter()
        .map(|v| TaskReminderInput {
            id: v.id,
            due: v.due,
            completed: v.completed,
        })
        .collect::<Vec<_>>();
    let result = reminders::plan_local_reminders(&courses, &tasks, now_millis);
    ReminderPlanResponse {
        plans: result
            .plans
            .into_iter()
            .map(|v| PlannedReminder {
                key: v.key,
                group: v.group,
                at_millis: v.at_millis,
                expires_millis: v.expires_millis,
            })
            .collect(),
        skipped: result.skipped,
        unsupported: false,
    }
}

pub struct CheckInReminderSeed {
    pub id: String,
    pub date: String,
    pub begins_at: String,
    pub ends_at: String,
    pub not_signed: bool,
    pub conflicting: bool,
    pub sign_in_allowed: Option<bool>,
    pub merged_record_count: u32,
}

pub struct HomeworkReminderSeed {
    pub id: String,
    pub due_at: String,
    pub pending: bool,
}

/// Data-only plans for check-in and assignment deadlines. The rule lives in the
/// domain; this command only moves the inputs across the bridge.
#[flutter_rust_bridge::frb(sync)]
pub fn plan_checkin_homework_reminders(
    checkin: Vec<CheckInReminderSeed>,
    homework: Vec<HomeworkReminderSeed>,
    now_millis: i64,
) -> ReminderPlanResponse {
    // Bound FFI processing. Oversized requests fail closed rather than truncate unnoticed.
    if checkin.len() > 500 || homework.len() > 2000 {
        return ReminderPlanResponse {
            plans: vec![],
            skipped: 0,
            unsupported: true,
        };
    }
    let checkin = checkin
        .into_iter()
        .map(|v| CheckInReminderInput {
            id: v.id,
            date: v.date,
            begins_at: v.begins_at,
            ends_at: v.ends_at,
            not_signed: v.not_signed,
            conflicting: v.conflicting,
            sign_in_allowed: v.sign_in_allowed,
            merged_record_count: v.merged_record_count as usize,
        })
        .collect::<Vec<_>>();
    let homework = homework
        .into_iter()
        .map(|v| HomeworkReminderInput {
            id: v.id,
            due_at: v.due_at,
            pending: v.pending,
        })
        .collect::<Vec<_>>();
    let result = reminders::plan_checkin_homework_reminders(&checkin, &homework, now_millis);
    ReminderPlanResponse {
        plans: result
            .plans
            .into_iter()
            .map(|v| PlannedReminder {
                key: v.key,
                group: v.group,
                at_millis: v.at_millis,
                expires_millis: v.expires_millis,
            })
            .collect(),
        skipped: result.skipped,
        unsupported: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn empty_and_bounded_request_are_explicit() {
        let result = plan_course_task_reminders(vec![], vec![], 0);
        assert!(result.plans.is_empty());
        assert!(!result.unsupported);
        let result = plan_course_task_reminders(
            (0..501)
                .map(|_| CourseReminderSeed {
                    id: "synthetic".into(),
                    week_start: "2026-10-26".into(),
                    day: 1,
                    starts_at: "08:00".into(),
                    ends_at: "09:00".into(),
                })
                .collect(),
            vec![],
            0,
        );
        assert!(result.unsupported);
    }
}
