//! Synthetic use cases projected through the same public DTOs.
use super::*;

pub(super) fn load_rule_examples() -> RuleExamples {
    match application::demo_rules() {
        Ok((day, snapshot)) => RuleExamples {
            local_date: day.local_date,
            minutes_since_midnight: day.minutes_since_midnight as i32,
            time_zone: day.time_zone,
            cached_weeks: snapshot
                .term_courses
                .as_ref()
                .into_iter()
                .flat_map(|weeks| weeks.keys())
                .filter_map(|key| key.parse::<i32>().ok())
                .collect(),
            selected_week: snapshot.week_number,
            course_names: snapshot
                .courses
                .into_iter()
                .map(|course| course.name)
                .collect(),
            failure: None,
        },
        Err(error) => RuleExamples {
            local_date: String::new(),
            minutes_since_midnight: 0,
            time_zone: String::new(),
            cached_weeks: vec![],
            selected_week: 0,
            course_names: vec![],
            failure: Some(error.code.into()),
        },
    }
}

pub(super) fn load_demo_schedule() -> ScheduleResponse {
    match application::demo_schedule::load() {
        Ok(bundle) => ScheduleResponse {
            term_id: bundle
                .terms
                .iter()
                .find(|term| term.selected)
                .or_else(|| bundle.terms.first())
                .map(|term| term.id.clone())
                .unwrap_or_default(),
            terms: bundle
                .terms
                .into_iter()
                .map(|term| ScheduleTerm {
                    id: term.id,
                    name: term.name,
                    selected: term.selected,
                })
                .collect(),
            weeks: bundle
                .weeks
                .into_iter()
                .map(|week| ScheduleWeek {
                    number: week.number,
                    start_date: week.start_date.to_string(),
                    end_date: week.end_date.to_string(),
                    current: week.current,
                })
                .collect(),
            week_number: bundle.week_number,
            courses: bundle
                .courses
                .into_iter()
                .map(|course| ScheduleCourse {
                    id: course.id,
                    name: course.name,
                    day: course.day,
                    start_section: course.start_section,
                    end_section: course.end_section,
                    start_time: course.start_time,
                    end_time: course.end_time,
                    place: course.place,
                    teacher: course.teacher,
                    color: course.color,
                })
                .collect(),
            exams: bundle
                .exams
                .into_iter()
                .map(|exam| ScheduleExam {
                    id: exam.id,
                    course_name: exam.course_name,
                    course_no: exam.course_no,
                    exam_time_description: exam.exam_time_description,
                    exam_date: exam.exam_date,
                    start_time: exam.start_time,
                    end_time: exam.end_time,
                    exam_place: exam.exam_place,
                    exam_seat_no: exam.exam_seat_no,
                    week: exam.week,
                    exam_status: exam.exam_status,
                    exam_type: exam.exam_type,
                })
                .collect(),
            fetched_at: None,
            failure: None,
            failure_detail: None,
        },
        Err(error) => ScheduleResponse {
            terms: vec![],
            weeks: vec![],
            term_id: String::new(),
            week_number: 0,
            courses: vec![],
            exams: vec![],
            fetched_at: None,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) fn load_demo_grades() -> GradeResponse {
    match application::demo_grades::load() {
        Ok(bundle) => GradeResponse {
            term_id: bundle.term_id,
            summary: GradeSummary {
                course_count: bundle.summary.course_count,
                credit_total: bundle.summary.credit_total,
                weighted_average: bundle.summary.weighted_average,
                grade_point_average: bundle.summary.grade_point_average,
            },
            courses: bundle
                .courses
                .into_iter()
                .map(|course| GradeCourse {
                    id: course.id,
                    name: course.name,
                    code: course.code,
                    credit: course.credit,
                    score: course.score,
                    score_value: course.score_value,
                    score_type: course.score_type,
                    course_type: course.course_type,
                })
                .collect(),
            fetched_at: None,
            failure: None,
            failure_detail: None,
        },
        Err(error) => GradeResponse {
            term_id: String::new(),
            courses: vec![],
            summary: GradeSummary {
                course_count: 0,
                credit_total: 0.0,
                weighted_average: None,
                grade_point_average: None,
            },
            fetched_at: None,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) fn load_demo_today() -> TodayResponse {
    match application::demo_today::load() {
        Ok(bundle) => TodayResponse {
            date: bundle.date,
            courses: bundle
                .courses
                .into_iter()
                .map(|course| TodayCourse {
                    name: course.name,
                    place: course.place,
                    time: course.time,
                    short_name: course.short_name,
                })
                .collect(),
            fetched_at: None,
            failure: None,
            failure_detail: None,
        },
        Err(error) => TodayResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) fn load_demo_homework() -> HomeworkResponse {
    match application::demo_homework::load() {
        Ok(bundle) => HomeworkResponse {
            fetched_at: None,
            roles_complete: None,
            term_name: bundle.term_name,
            term_code: bundle.term_code,
            items: bundle
                .page
                .items
                .into_iter()
                .map(|item| HomeworkItem {
                    course_role: item.course_role,
                    id: item.id,
                    course_id: item.course_id,
                    course_name: item.course_name,
                    teacher_name: item.teacher_name,
                    title: item.title,
                    published_at: item.published_at,
                    due_at: item.due_at,
                    status: match item.status {
                        ginkgo_core::features::homework::HomeworkStatus::Pending => {
                            HomeworkStatus::Pending
                        }
                        ginkgo_core::features::homework::HomeworkStatus::Submitted => {
                            HomeworkStatus::Submitted
                        }
                        ginkgo_core::features::homework::HomeworkStatus::Unknown => {
                            HomeworkStatus::Unknown
                        }
                    },
                    status_detail: item.status_detail,
                    score: item.score,
                })
                .collect(),
            failure: None,
            failure_detail: None,
        },
        Err(error) => HomeworkResponse {
            fetched_at: None,
            roles_complete: None,
            term_name: String::new(),
            term_code: String::new(),
            items: vec![],
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) fn load_demo_checkin() -> CheckInResponse {
    match application::demo_checkin::load() {
        Ok(day) => CheckInResponse {
            date: day.date,
            courses: day.courses.into_iter().map(checkin_course).collect(),
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: None,
            failure_detail: None,
        },
        Err(error) => CheckInResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}
