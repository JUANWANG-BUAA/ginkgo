//! Domain outcome to FFI value mapping.
use super::*;

pub(super) fn mutation_response(
    outcome: ginkgo_core::features::mutation::MutationOutcome,
) -> MutationResponse {
    use ginkgo_core::features::mutation::MutationState;
    MutationResponse {
        state: match outcome.state {
            MutationState::Accepted => "accepted",
            MutationState::Rejected => "rejected",
            MutationState::Uncertain => "uncertain",
            MutationState::NotSubmitted => "notSubmitted",
        }
        .into(),
        message: outcome.message,
    }
}

pub(super) fn grade_response(outcome: GradeOutcome) -> GradeResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    GradeResponse {
        term_id: outcome.term_id,
        summary: GradeSummary {
            course_count: outcome.summary.course_count,
            credit_total: outcome.summary.credit_total,
            weighted_average: outcome.summary.weighted_average,
            grade_point_average: outcome.summary.grade_point_average,
        },
        courses: outcome
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
        fetched_at: Some(outcome.fetched_at),
        failure,
        failure_detail,
    }
}

pub(super) fn grade_failure(failure: FailureCode, detail: Option<String>) -> GradeResponse {
    GradeResponse {
        term_id: String::new(),
        courses: vec![],
        summary: GradeSummary {
            course_count: 0,
            credit_total: 0.0,
            weighted_average: None,
            grade_point_average: None,
        },
        fetched_at: None,
        failure: Some(failure),
        failure_detail: detail,
    }
}

pub(super) fn checkin_response(outcome: CheckInOutcome) -> CheckInResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    CheckInResponse {
        date: outcome.date,
        courses: outcome
            .courses
            .into_iter()
            .map(|course| CheckInCourseDto {
                id: course.id,
                course_id: course.course_id,
                course_num: course.course_num,
                course_name: course.course_name,
                begins_at: course.begins_at,
                ends_at: course.ends_at,
                status: match course.status {
                    ginkgo_core::features::checkin::CheckInStatus::NotSigned => {
                        CheckInStatusDto::NotSigned
                    }
                    ginkgo_core::features::checkin::CheckInStatus::Signed => {
                        CheckInStatusDto::Signed
                    }
                    ginkgo_core::features::checkin::CheckInStatus::Unknown => {
                        CheckInStatusDto::Unknown
                    }
                },
                teacher_name: course.teacher_name,
                classroom_name: course.classroom_name,
                merged_record_count: course.merged_record_count as i32,
                conflicting: course.conflicting,
                sign_in_allowed: Some(course.sign_in_allowed),
            })
            .collect(),
        fetched_at: Some(outcome.fetched_at),
        from_cache: outcome.from_cache,
        stale: outcome.stale,
        failure,
        failure_detail,
    }
}

pub(super) fn checkin_failure(failure: FailureCode, detail: Option<String>) -> CheckInResponse {
    CheckInResponse {
        date: String::new(),
        courses: vec![],
        fetched_at: None,
        from_cache: false,
        stale: false,
        failure: Some(failure),
        failure_detail: detail,
    }
}

pub(super) fn today_response(outcome: TodayOutcome) -> TodayResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    TodayResponse {
        date: outcome.date,
        courses: outcome
            .courses
            .into_iter()
            .map(|course| TodayCourse {
                name: course.name,
                place: course.place,
                time: course.time,
                short_name: course.short_name,
            })
            .collect(),
        fetched_at: Some(outcome.fetched_at),
        failure,
        failure_detail,
    }
}

pub(super) fn schedule_response(outcome: ScheduleOutcome) -> ScheduleResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    ScheduleResponse {
        terms: outcome
            .data
            .terms
            .into_iter()
            .map(|term| ScheduleTerm {
                id: term.id,
                name: term.name,
                selected: term.selected,
            })
            .collect(),
        weeks: outcome
            .data
            .weeks
            .into_iter()
            .map(|week| ScheduleWeek {
                number: week.number,
                start_date: week.start_date.to_string(),
                end_date: week.end_date.to_string(),
                current: week.current,
            })
            .collect(),
        term_id: outcome.data.term_id,
        week_number: outcome.data.week_number,
        courses: outcome
            .data
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
        exams: outcome
            .data
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
        fetched_at: Some(outcome.fetched_at),
        failure,
        failure_detail,
    }
}

pub(super) fn schedule_failure(failure: FailureCode, detail: Option<String>) -> ScheduleResponse {
    ScheduleResponse {
        terms: vec![],
        weeks: vec![],
        term_id: String::new(),
        week_number: 0,
        courses: vec![],
        exams: vec![],
        fetched_at: None,
        failure: Some(failure),
        failure_detail: detail,
    }
}

pub(super) fn classroom_response(outcome: ClassroomOutcome) -> ClassroomResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    ClassroomResponse {
        buildings: outcome
            .result
            .buildings
            .into_iter()
            .map(|(name, rooms)| ClassroomBuilding {
                name,
                rooms: rooms
                    .into_iter()
                    .map(|room| ClassroomRow {
                        section_states: room
                            .section_states()
                            .into_iter()
                            .map(|(number, available)| SectionState { number, available })
                            .collect(),
                        id: room.room.id,
                        name: room.room.name,
                        floor: room.room.floorid,
                        sections: room.sections,
                        longest_run: room.longest_run as i32,
                    })
                    .collect(),
            })
            .collect(),
        room_count: outcome.result.summary.room_count as i32,
        building_count: outcome.result.summary.building_count as i32,
        free_slot_count: outcome.result.summary.free_slot_count as i32,
        fetched_at: Some(outcome.fetched_at),
        from_cache: outcome.from_cache,
        failure,
        failure_detail,
    }
}

pub(super) fn classroom_sort(sort: ClassroomSort) -> classroom_domain::Sort {
    match sort {
        ClassroomSort::Name => classroom_domain::Sort::Name,
        ClassroomSort::Availability => classroom_domain::Sort::Availability,
        ClassroomSort::Consecutive => classroom_domain::Sort::Consecutive,
    }
}

pub(super) fn outcome_response(
    service: &LiveService,
    outcome: SessionOutcome,
    remembered: bool,
) -> SessionResponse {
    match outcome {
        SessionOutcome::SignedIn { .. } => SessionResponse {
            remembered,
            ..status_response(service.status())
        },
        SessionOutcome::CaptchaRequired(CaptchaChallenge { id, image_url, .. }) => {
            SessionResponse {
                state: SessionState::CaptchaRequired,
                captcha_id: Some(id),
                captcha_image_url: Some(image_url),
                ..signed_out()
            }
        }
        SessionOutcome::SignedOut => signed_out(),
    }
}

pub(super) fn status_response(status: SessionStatus) -> SessionResponse {
    if let (Some(account), Some(profile)) = (status.account, status.profile) {
        SessionResponse {
            state: SessionState::SignedIn,
            account: Some(account),
            name: Some(profile.name),
            route: Some(match status.route {
                ginkgo_core::application::RoutePreference::Automatic => RouteChoice::Automatic,
                ginkgo_core::application::RoutePreference::Direct => RouteChoice::Direct,
                ginkgo_core::application::RoutePreference::WebVpn => RouteChoice::WebVpn,
            }),
            ..signed_out()
        }
    } else {
        signed_out()
    }
}

pub(super) fn failure_response(error: AppError) -> SessionResponse {
    let (failure, failure_detail) = failure(&error);
    SessionResponse {
        failure,
        failure_detail,
        ..signed_out()
    }
}

pub(super) fn signed_out() -> SessionResponse {
    SessionResponse {
        state: SessionState::SignedOut,
        account: None,
        name: None,
        captcha_id: None,
        captcha_image_url: None,
        remembered: false,
        route: None,
        failure: None,
        failure_detail: None,
    }
}

pub(super) fn failure(error: &AppError) -> (Option<FailureCode>, Option<String>) {
    (Some(error.code.clone().into()), error.detail.clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn mutation_states_map_one_to_one_and_uncertainty_never_reads_accepted() {
        use ginkgo_core::features::mutation::{MutationOutcome, MutationState};
        let cases = [
            (MutationState::Accepted, "accepted"),
            (MutationState::Rejected, "rejected"),
            (MutationState::Uncertain, "uncertain"),
            (MutationState::NotSubmitted, "notSubmitted"),
        ];
        for (state, expected) in cases {
            let response = mutation_response(MutationOutcome::new(state, "合成结果"));
            assert_eq!(response.state, expected);
            assert_eq!(response.message, "合成结果");
        }
        // The write-path red line: an unknown outcome must never present as a
        // confirmed submission, or the UI would resubmit it.
        let uncertain = mutation_response(MutationOutcome::uncertain());
        assert_eq!(uncertain.state, "uncertain");
        assert_ne!(uncertain.state, "accepted");
        assert_ne!(uncertain.state, "rejected");
        assert_ne!(uncertain.state, "notSubmitted");
    }

    #[test]
    fn checkin_status_maps_per_variant_and_copies_course_fields() {
        use ginkgo_core::application::CheckInOutcome;
        use ginkgo_core::features::checkin::{CheckInCourse, CheckInStatus};
        let course = |status: CheckInStatus| CheckInCourse {
            id: format!("course-{status:?}"),
            course_id: Some("CS101".into()),
            course_num: Some("01".into()),
            course_name: "操作系统".into(),
            begins_at: "08:00".into(),
            ends_at: "09:35".into(),
            status,
            teacher_name: Some("李文".into()),
            classroom_name: Some("主楼 B202".into()),
            merged_record_count: 3,
            conflicting: true,
            sign_in_allowed: true,
        };
        let cases = [
            (CheckInStatus::NotSigned, CheckInStatusDto::NotSigned),
            (CheckInStatus::Signed, CheckInStatusDto::Signed),
            (CheckInStatus::Unknown, CheckInStatusDto::Unknown),
        ];
        let outcome = CheckInOutcome {
            date: "2026-10-25".into(),
            courses: cases.iter().map(|(status, _)| course(*status)).collect(),
            fetched_at: "2026-10-25 08:00:00".into(),
            from_cache: true,
            stale: false,
            failure: None,
        };
        let response = checkin_response(outcome);
        assert_eq!(response.date, "2026-10-25");
        assert_eq!(response.fetched_at.as_deref(), Some("2026-10-25 08:00:00"));
        assert!(response.from_cache);
        assert!(!response.stale);
        assert!(response.failure.is_none());
        assert_eq!(response.courses.len(), 3);
        for ((_, expected), dto) in cases.iter().zip(&response.courses) {
            assert_eq!(
                std::mem::discriminant(&dto.status),
                std::mem::discriminant(expected)
            );
            assert_eq!(dto.merged_record_count, 3);
            assert_eq!(dto.sign_in_allowed, Some(true));
            assert!(dto.conflicting);
            assert_eq!(dto.course_name, "操作系统");
        }
    }

    #[test]
    fn schedule_response_copies_every_field_and_week_dates_render_iso() {
        use chrono::NaiveDate;
        use ginkgo_core::application::{ScheduleData, ScheduleOutcome};
        use ginkgo_core::features::schedule::{CourseMeeting, Exam, Term, Week};
        let outcome = ScheduleOutcome {
            data: ScheduleData {
                terms: vec![Term {
                    id: "2026-1".into(),
                    name: "2026-2027学年第一学期".into(),
                    selected: true,
                }],
                weeks: vec![Week {
                    number: 6,
                    start_date: NaiveDate::from_ymd_opt(2026, 10, 19).unwrap(),
                    end_date: NaiveDate::from_ymd_opt(2026, 10, 25).unwrap(),
                    current: true,
                }],
                term_id: "2026-1".into(),
                week_number: 6,
                courses: vec![CourseMeeting {
                    id: "meeting-1".into(),
                    name: "算法设计与分析".into(),
                    day: 1,
                    start_section: 1,
                    end_section: 2,
                    start_time: Some("08:00".into()),
                    end_time: Some("09:35".into()),
                    place: Some("新主楼 A101".into()),
                    teacher: Some("李文".into()),
                    color: Some("blue".into()),
                }],
                exams: vec![Exam {
                    id: "exam-1".into(),
                    course_name: "操作系统".into(),
                    course_no: Some("CS201".into()),
                    exam_time_description: Some("第17周".into()),
                    exam_date: Some("2027-01-08".into()),
                    start_time: Some("14:00".into()),
                    end_time: Some("16:00".into()),
                    exam_place: Some("主楼 B202".into()),
                    exam_seat_no: Some("12".into()),
                    week: Some(17),
                    exam_status: Some("正常".into()),
                    exam_type: Some("闭卷".into()),
                    task_id: Some("task-hidden".into()),
                }],
            },
            fetched_at: "2026-10-25 09:00:00".into(),
            from_cache: false,
            stale: false,
            failure: None,
        };
        let response = schedule_response(outcome);
        assert_eq!(response.term_id, "2026-1");
        assert_eq!(response.week_number, 6);
        assert_eq!(response.terms.len(), 1);
        let term = &response.terms[0];
        assert_eq!(term.id, "2026-1");
        assert!(term.selected);
        let week = &response.weeks[0];
        assert_eq!(week.number, 6);
        assert_eq!(week.start_date, "2026-10-19");
        assert_eq!(week.end_date, "2026-10-25");
        assert!(week.current);
        let course = &response.courses[0];
        assert_eq!(course.id, "meeting-1");
        assert_eq!(course.name, "算法设计与分析");
        assert_eq!(course.day, 1);
        assert_eq!(course.start_section, 1);
        assert_eq!(course.end_section, 2);
        assert_eq!(course.start_time.as_deref(), Some("08:00"));
        assert_eq!(course.end_time.as_deref(), Some("09:35"));
        assert_eq!(course.place.as_deref(), Some("新主楼 A101"));
        assert_eq!(course.teacher.as_deref(), Some("李文"));
        assert_eq!(course.color.as_deref(), Some("blue"));
        let exam = &response.exams[0];
        assert_eq!(exam.id, "exam-1");
        assert_eq!(exam.course_name, "操作系统");
        assert_eq!(exam.course_no.as_deref(), Some("CS201"));
        assert_eq!(exam.exam_time_description.as_deref(), Some("第17周"));
        assert_eq!(exam.exam_date.as_deref(), Some("2027-01-08"));
        assert_eq!(exam.start_time.as_deref(), Some("14:00"));
        assert_eq!(exam.end_time.as_deref(), Some("16:00"));
        assert_eq!(exam.exam_place.as_deref(), Some("主楼 B202"));
        assert_eq!(exam.exam_seat_no.as_deref(), Some("12"));
        assert_eq!(exam.week, Some(17));
        assert_eq!(exam.exam_status.as_deref(), Some("正常"));
        assert_eq!(exam.exam_type.as_deref(), Some("闭卷"));
    }

    #[test]
    fn classroom_sort_passes_each_variant_through() {
        use classroom_domain::Sort;
        assert!(matches!(classroom_sort(ClassroomSort::Name), Sort::Name));
        assert!(matches!(
            classroom_sort(ClassroomSort::Availability),
            Sort::Availability
        ));
        assert!(matches!(
            classroom_sort(ClassroomSort::Consecutive),
            Sort::Consecutive
        ));
    }

    #[test]
    fn every_domain_error_code_keeps_its_own_failure_code() {
        use ginkgo_core::ErrorCode;
        let codes = [
            ErrorCode::InvalidRequest,
            ErrorCode::ChangedResponse,
            ErrorCode::UnsupportedContract,
            ErrorCode::SessionExpired,
            ErrorCode::ServiceUnavailable,
            ErrorCode::CaptchaRequired,
            ErrorCode::InvalidCredentials,
            ErrorCode::PreLoginTip,
            ErrorCode::AccessPolicyDenied,
            ErrorCode::RedirectLimit,
            ErrorCode::UnsupportedPortal,
            ErrorCode::CredentialStore,
            ErrorCode::BusinessRejected,
            ErrorCode::NetworkUnreachable,
            ErrorCode::ModuleAuthRequired,
        ];
        let mut seen = std::collections::HashSet::new();
        for code in &codes {
            let failure = FailureCode::from(code.clone());
            // Collapsing two domain codes onto one FailureCode silently drops a
            // distinction the UI copy depends on. `NetworkUnreachable` exists
            // because offline readers were told the school was down instead.
            assert!(
                seen.insert(std::mem::discriminant(&failure)),
                "{code:?} shares its FailureCode with an earlier code"
            );
        }
        assert_eq!(seen.len(), codes.len());
    }
}
