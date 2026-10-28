//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn checkin_load_progress() -> ReadOnlyResponse {
    match service() {
        Ok(service) => ReadOnlyResponse {
            payload: serde_json::to_string(&service.checkin_load_progress()).ok(),
            failure: None,
            stale: false,
        },
        Err(error) => ReadOnlyResponse {
            payload: None,
            failure: Some(error.code.into()),
            stale: false,
        },
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
