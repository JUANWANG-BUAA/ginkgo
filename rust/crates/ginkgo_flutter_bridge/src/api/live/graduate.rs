//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_graduate_part(report: bool, force_refresh: bool) -> ReadOnlyResponse {
    use ginkgo_core::application::GraduatePart;
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => {
            bounded_read(service.load_graduate_part(
                if report {
                    GraduatePart::Report
                } else {
                    GraduatePart::Status
                },
                force_refresh,
            ))
            .await
        }
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) fn load_demo_graduate_status() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::graduate_status())
}

pub(super) fn load_demo_graduate() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_graduate())
}

pub(super) async fn credit_map(expected: String, force: bool) -> ReadOnlyResponse {
    let _session = SESSION_ACCESS.read().await;
    let result = async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(&expected) {
            return Err(AppError::session_expired());
        }
        bounded_read(s.load_graduate_credit_map(force)).await
    }
    .await;
    match result {
        Ok(v) => ReadOnlyResponse {
            payload: serde_json::to_string(&v.data).ok(),
            stale: v.failure.is_some(),
            failure: v.failure.map(|e| e.code.into()),
        },
        Err(e) => ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(e.code.into()),
        },
    }
}
