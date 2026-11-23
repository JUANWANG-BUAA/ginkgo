//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn checkin_load_progress() -> CheckinLoadProgressResponse {
    match service() {
        Ok(service) => CheckinLoadProgressResponse {
            data: Some(checkin_progress_dto(service.checkin_load_progress())),
            failure: None,
        },
        Err(error) => CheckinLoadProgressResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

/// `elapsed_ms` is a `u128` locally; a read that outlives signed milliseconds
/// is not a real case, so the bridge narrows it instead of widening the DTO.
fn checkin_progress_dto(
    progress: ginkgo_core::application::CheckInLoadProgress,
) -> CheckinLoadProgressDto {
    CheckinLoadProgressDto {
        phase: progress.phase,
        elapsed_ms: progress
            .elapsed_ms
            .map(|value| i64::try_from(value).unwrap_or(i64::MAX)),
    }
}

pub(super) async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {
    let result = match service() {
        Ok(service) => {
            with_module_read(ModuleAccess::CheckIn, || {
                service.load_checkin_on_date(Some(date), force_refresh)
            })
            .await
        }
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => checkin_response(outcome),
        Err(error) => checkin_failure(error.code.clone().into(), error.detail),
    }
}

pub(super) async fn prepare_checkin_qr(
    course_id: String,
    revalidate_course: bool,
) -> CheckInQrResponse {
    let result = match service() {
        Ok(service) => {
            with_module_read(ModuleAccess::CheckIn, || {
                service.prepare_checkin_qr(&course_id, revalidate_course)
            })
            .await
        }
        Err(error) => Err(error),
    };
    match result {
        Ok(ticket) => CheckInQrResponse {
            course_id: ticket.course_id,
            fetched_at: Some(ticket.fetched_at),
            refresh_seconds: i32::from(ticket.refresh_seconds),
            matrix_size: i32::from(ticket.matrix_size),
            modules: ticket.modules,
            demo: false,
            failure: None,
            failure_detail: None,
        },
        Err(error) => {
            let (failure, failure_detail) = mapping::failure(&error);
            CheckInQrResponse {
                course_id,
                fetched_at: None,
                refresh_seconds: 0,
                matrix_size: 0,
                modules: vec![],
                demo: false,
                failure,
                failure_detail,
            }
        }
    }
}

#[cfg(test)]
mod progress_tests {
    use super::*;

    #[test]
    fn progress_narrows_u128_milliseconds_without_fabricating_a_value() {
        use ginkgo_core::application::CheckInLoadProgress;
        let running = checkin_progress_dto(CheckInLoadProgress {
            phase: "courses".into(),
            elapsed_ms: Some(2_500),
            stages: Vec::new(),
        });
        assert_eq!(running.phase, "courses");
        assert_eq!(running.elapsed_ms, Some(2_500));

        // No timer started yet: the elapsed value stays absent, not zero.
        let idle = checkin_progress_dto(CheckInLoadProgress {
            phase: "idle".into(),
            elapsed_ms: None,
            stages: Vec::new(),
        });
        assert_eq!(idle.elapsed_ms, None);
    }
}
