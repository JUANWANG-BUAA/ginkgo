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

/// Serialization failures are typed failures, never an empty successful response.
pub(super) fn read_only_response<T: serde::Serialize>(
    result: Result<ginkgo_core::application::DataOutcome<T>, AppError>,
) -> ReadOnlyResponse {
    let result = result.and_then(|outcome| {
        let payload = serde_json::to_string(&outcome.data).map_err(|_| AppError::changed())?;
        Ok(ReadOnlyResponse {
            payload: Some(payload),
            stale: outcome.failure.is_some(),
            failure: outcome.failure.map(|error| error.code.into()),
        })
    });
    result.unwrap_or_else(|error| ReadOnlyResponse {
        payload: None,
        stale: false,
        failure: Some(error.code.into()),
    })
}

pub(super) fn read_only_value<T: serde::Serialize>(
    result: Result<T, AppError>,
) -> ReadOnlyResponse {
    read_only_response(result.map(|data| ginkgo_core::application::DataOutcome {
        data,
        failure: None,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use ginkgo_core::application::DataOutcome;
    use serde::{Serialize, Serializer};

    struct InvalidPayload;
    impl Serialize for InvalidPayload {
        fn serialize<S: Serializer>(&self, _: S) -> Result<S::Ok, S::Error> {
            Err(serde::ser::Error::custom("synthetic serialization failure"))
        }
    }

    #[test]
    fn serialization_failure_is_not_reported_as_an_empty_success() {
        let response = read_only_response(Ok(DataOutcome {
            data: InvalidPayload,
            failure: None,
        }));
        assert!(response.payload.is_none());
        assert!(matches!(
            response.failure,
            Some(FailureCode::ChangedResponse)
        ));
    }

    #[test]
    fn fallback_value_and_refresh_failure_cross_the_boundary_together() {
        let response = read_only_response(Ok(DataOutcome {
            data: vec![7],
            failure: Some(AppError::session_expired()),
        }));
        assert_eq!(response.payload.as_deref(), Some("[7]"));
        assert!(response.stale);
        assert!(matches!(
            response.failure,
            Some(FailureCode::SessionExpired)
        ));
    }
}
