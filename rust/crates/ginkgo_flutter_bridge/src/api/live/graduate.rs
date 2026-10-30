//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_graduate_part(report: bool, force_refresh: bool) -> GraduateResponse {
    use ginkgo_core::application::GraduatePart;
    let result = match service() {
        Ok(service) => {
            with_session_read(|| {
                service.load_graduate_part(
                    if report {
                        GraduatePart::Report
                    } else {
                        GraduatePart::Status
                    },
                    force_refresh,
                )
            })
            .await
        }
        Err(error) => Err(error),
    };
    graduate_response(result)
}

pub(super) fn load_demo_graduate_status() -> GraduateResponse {
    graduate_response(
        ginkgo_runtime::demo::demo_campus::graduate_status().map(|data| {
            ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            }
        }),
    )
}

pub(super) fn load_demo_graduate() -> GraduateResponse {
    graduate_response(
        ginkgo_runtime::demo::demo_campus::load_demo_graduate().map(|data| {
            ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            }
        }),
    )
}

fn graduate_response(
    result: Result<ginkgo_core::application::GraduateOutcome, AppError>,
) -> GraduateResponse {
    match result {
        Ok(outcome) => GraduateResponse {
            data: Some(AcademicDataDto {
                notice: outcome.data.notice,
                sections: outcome
                    .data
                    .sections
                    .into_iter()
                    .map(|section| GraduateSectionDto {
                        title: section.title,
                        progress: section.progress.map(|progress| GraduateProgressDto {
                            required: progress.required,
                            earned: progress.earned,
                            pending: progress.pending,
                        }),
                        rows: section
                            .rows
                            .into_iter()
                            .map(|row| GraduateRowDto {
                                title: row.title,
                                detail: row.detail,
                                is_course: row.is_course,
                                completed: row.completed,
                                credit: row.credit,
                                semester: row.semester,
                            })
                            .collect(),
                    })
                    .collect(),
            }),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => GraduateResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn credit_map(expected: String, force: bool) -> GraduateCreditMapResponse {
    let result = with_session_read(|| async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(&expected) {
            return Err(AppError::session_expired());
        }
        s.load_graduate_credit_map(force).await
    })
    .await;
    match result {
        Ok(outcome) => GraduateCreditMapResponse {
            data: Some(credit_map_dto(outcome.data)),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => GraduateCreditMapResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn credit_map_dto(
    map: ginkgo_core::application::graduate_credit_map::GraduateCreditMap,
) -> GraduateCreditMapDto {
    GraduateCreditMapDto {
        summary: map.summary.map(credit_node_dto),
        nodes: map.nodes.into_iter().map(credit_node_dto).collect(),
        notice: map.notice,
    }
}

fn credit_node_dto(
    node: ginkgo_core::application::graduate_credit_map::GraduateCreditNode,
) -> GraduateCreditNodeDto {
    GraduateCreditNodeDto {
        source_index: node.source_index,
        title: node.title,
        progress: node.progress.map(|metrics| GraduateCreditMetricsDto {
            state: match metrics.state {
                ginkgo_core::application::graduate_credit_map::GraduateCreditState::Unknown => {
                    GraduateCreditStateDto::Unknown
                }
                ginkgo_core::application::graduate_credit_map::GraduateCreditState::NoMinimum => {
                    GraduateCreditStateDto::NoMinimum
                }
                ginkgo_core::application::graduate_credit_map::GraduateCreditState::Incomplete => {
                    GraduateCreditStateDto::Incomplete
                }
                ginkgo_core::application::graduate_credit_map::GraduateCreditState::RequirementMet => {
                    GraduateCreditStateDto::RequirementMet
                }
            },
            required: metrics.required,
            earned: metrics.earned,
            pending: metrics.pending,
            remaining: metrics.remaining,
            ratio: metrics.ratio,
        }),
        rows: node
            .rows
            .into_iter()
            .map(|row| GraduateCreditRowDto {
                title: row.title,
                detail: row.detail,
                is_course: row.is_course,
                completed: row.completed,
                credit: row.credit,
                semester: row.semester,
            })
            .collect(),
    }
}
