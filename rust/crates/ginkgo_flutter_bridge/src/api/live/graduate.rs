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
