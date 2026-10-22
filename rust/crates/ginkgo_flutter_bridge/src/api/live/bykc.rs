//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_bykc(force_refresh)).await,
        Err(error) => Err(error),
    };
    let result = result.and_then(|outcome| {
        Ok(ginkgo_core::application::DataOutcome {
            data: ginkgo_core::application::project_catalog(outcome.data)?,
            failure: outcome.failure,
        })
    });
    read_only_response(result)
}

pub(super) fn load_demo_bykc() -> ReadOnlyResponse {
    read_only_value(
        ginkgo_runtime::demo::demo_campus::load_demo_bykc()
            .and_then(ginkgo_core::application::project_catalog),
    )
}

pub(super) async fn load_bykc_chosen(force_refresh: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_bykc_chosen(force_refresh)).await,
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) async fn load_bykc_statistics(force_refresh: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_bykc_statistics(force_refresh)).await,
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) fn load_demo_bykc_chosen() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_bykc_chosen())
}

pub(super) fn load_demo_bykc_statistics() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_bykc_statistics())
}
