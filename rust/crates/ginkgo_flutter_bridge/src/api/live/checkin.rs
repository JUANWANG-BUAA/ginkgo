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

pub(super) async fn submit_checkin(course_id: String) -> MutationResponse {
    let Ok(_write) = CHECKIN_WRITE.try_lock() else {
        return MutationResponse {
            state: "notSubmitted".into(),
            message: "签到正在处理，请勿重复提交".into(),
        };
    };
    match service() {
        Ok(service) => {
            match with_module_submit(ModuleAccess::CheckIn, || service.submit_checkin(&course_id))
                .await
            {
                Some(outcome) => mutation_response(outcome),
                None => MutationResponse {
                    state: "uncertain".into(),
                    message: "提交超时，结果待核实；请刷新确认，勿重复提交".into(),
                },
            }
        }
        Err(_) => MutationResponse {
            state: "notSubmitted".into(),
            message: "本地服务不可用，未提交签到".into(),
        },
    }
}

static CHECKIN_WRITE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

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
