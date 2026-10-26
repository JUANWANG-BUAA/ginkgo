//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn login(
    account: String,
    password: String,
    captcha: Option<String>,
    remember: bool,
) -> SessionResponse {
    let _access = SESSION_ACCESS.write().await;
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    match bounded_session(service.sign_in(&account, &password, captcha.as_deref(), remember)).await
    {
        Ok(outcome) => {
            let remembered = matches!(
                &outcome,
                SessionOutcome::SignedIn {
                    remembered: true,
                    ..
                }
            );
            outcome_response(service, outcome, remembered)
        }
        Err(error) => failure_response(error),
    }
}

pub(super) async fn restore_session() -> SessionResponse {
    let _access = SESSION_ACCESS.write().await;
    if SERVICE.get().is_none() {
        match ginkgo_runtime::has_saved_accounts() {
            Ok(false) => return signed_out(),
            Ok(true) => {}
            Err(error) => return failure_response(error),
        }
    }

    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    match bounded_session(service.restore()).await {
        Ok(outcome) => {
            let remembered = matches!(
                &outcome,
                SessionOutcome::SignedIn {
                    remembered: true,
                    ..
                }
            );
            outcome_response(service, outcome, remembered)
        }
        Err(error) => failure_response(error),
    }
}

pub(super) async fn sign_out() -> SessionResponse {
    let _access = SESSION_ACCESS.write().await;
    let Some(Ok(service)) = SERVICE.get() else {
        return signed_out();
    };
    service.sign_out().await;
    signed_out()
}

pub(super) async fn set_route(route: RouteChoice) -> SessionResponse {
    let _access = SESSION_ACCESS.write().await;
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    let preference = match route {
        RouteChoice::Automatic => ginkgo_core::application::RoutePreference::Automatic,
        RouteChoice::Direct => ginkgo_core::application::RoutePreference::Direct,
        RouteChoice::WebVpn => ginkgo_core::application::RoutePreference::WebVpn,
    };
    service.set_route(preference);
    status_response(service.status())
}

pub(super) async fn clear_cache() -> bool {
    let _access = SESSION_ACCESS.write().await;
    match service() {
        Ok(service) => {
            service.clear_snapshots();
            true
        }
        Err(_) => false,
    }
}

pub(super) fn verify_credential_storage(account: String, secret: String) -> bool {
    ginkgo_runtime::verify_credential_storage(&account, &secret)
}
