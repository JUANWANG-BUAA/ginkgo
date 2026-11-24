//! Account-bound read-only teaching evaluation status bridge.
use super::*;

pub(super) async fn load(
    expected_account: String,
    force_refresh: bool,
) -> TeachingEvaluationResponse {
    let result = with_session_read(|| async {
        let s = service()?;
        if expected_account.is_empty()
            || !s
                .status()
                .account
                .as_deref()
                .is_some_and(|a| a.eq_ignore_ascii_case(expected_account.as_str()))
        {
            return Err(AppError::session_expired());
        }
        s.load_teaching_evaluation(force_refresh).await
    })
    .await;
    evaluation_response(result)
}

fn evaluation_response(
    result: Result<ginkgo_core::application::TeachingEvaluationOutcome, AppError>,
) -> TeachingEvaluationResponse {
    use ginkgo_core::features::evaluation::EvaluationCourseStatus;
    match result {
        Ok(outcome) => TeachingEvaluationResponse {
            data: Some(TeachingEvaluationDto {
                task_id: outcome.data.task_id,
                task_name: outcome.data.task_name,
                term: outcome.data.term,
                courses: outcome
                    .data
                    .courses
                    .into_iter()
                    .map(|c| EvaluationCourseDto {
                        id: c.id,
                        course_name: c.course_name,
                        teacher_name: c.teacher_name,
                        questionnaire_name: c.questionnaire_name,
                        category: c.category,
                        status: match c.status {
                            EvaluationCourseStatus::Pending => EvaluationCourseStatusDto::Pending,
                            EvaluationCourseStatus::Completed => {
                                EvaluationCourseStatusDto::Completed
                            }
                            EvaluationCourseStatus::Unknown => EvaluationCourseStatusDto::Unknown,
                        },
                    })
                    .collect(),
                fetched_at: outcome.fetched_at,
                from_cache: outcome.from_cache,
                stale: outcome.stale,
            }),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => TeachingEvaluationResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ginkgo_core::{
        application::TeachingEvaluationOutcome,
        features::evaluation::{
            EvaluationCourseItem, EvaluationCourseStatus, TeachingEvaluationReport,
        },
    };

    #[test]
    fn evaluation_response_preserves_stale_snapshot_and_empty_task_state() {
        let stale = evaluation_response(Ok(TeachingEvaluationOutcome {
            data: TeachingEvaluationReport {
                task_id: Some("RW1".into()),
                task_name: Some("2026秋季评教".into()),
                term: Some("2026-20271".into()),
                courses: vec![EvaluationCourseItem {
                    id: "C1".into(),
                    course_name: "高等数学".into(),
                    teacher_name: Some("李文".into()),
                    questionnaire_name: Some("理论课".into()),
                    category: None,
                    status: EvaluationCourseStatus::Completed,
                }],
            },
            fetched_at: "2026-11-23T12:00:00+08:00".into(),
            from_cache: true,
            stale: true,
            failure: Some(AppError::unavailable()),
        }));
        assert!(matches!(
            stale.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
        let dto = stale.data.expect("stale dto");
        assert!(dto.stale);
        assert!(matches!(
            dto.courses[0].status,
            EvaluationCourseStatusDto::Completed
        ));
    }
}
