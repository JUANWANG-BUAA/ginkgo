//! Feature implementation behind the stable live API.
use super::*;

pub(super) fn edit_tasks(
    root: String,
    demo: bool,
    action: String,
    id: Option<String>,
    title: Option<String>,
    due: Option<String>,
    completed: Option<bool>,
) -> ReadOnlyResponse {
    let Ok(_access) = SESSION_ACCESS.try_read() else {
        return ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(FailureCode::ServiceUnavailable),
        };
    };
    let result = if demo {
        ginkgo_core::application::tasks_service::edit(
            std::path::Path::new(&root),
            "ginkgo-isolated-demo",
            &action,
            id.as_deref(),
            title.as_deref(),
            due.as_deref(),
            completed,
        )
    } else {
        service().and_then(|s| {
            s.edit_tasks(
                std::path::Path::new(&root),
                &action,
                id.as_deref(),
                title.as_deref(),
                due.as_deref(),
                completed,
            )
        })
    };
    read_only_value(result)
}

pub(super) async fn load_notices(force_refresh: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => service.load_notices(force_refresh).await,
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) fn load_demo_notices() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_notices())
}

pub(super) async fn load_cgyy(
    kind: String,
    site_id: i64,
    date: String,
    force_refresh: bool,
) -> ReadOnlyResponse {
    use ginkgo_core::application::CgyyQuery;
    let query = match kind.as_str() {
        "venues" => CgyyQuery::Venues,
        "day" => CgyyQuery::Day { site_id, date },
        "orders" => CgyyQuery::Orders,
        _ => return read_only_value::<()>(Err(AppError::invalid())),
    };
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => service.load_cgyy(query, force_refresh).await,
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) fn load_demo_cgyy(kind: String) -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_cgyy(kind))
}

pub(super) async fn check_android_update(current: String) -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::check_update(&current).await)
}
