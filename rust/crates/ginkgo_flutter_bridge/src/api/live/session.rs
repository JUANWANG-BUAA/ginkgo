//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn login(
    account: String,
    password: String,
    captcha: Option<String>,
    remember: bool,
) -> SessionResponse {
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    match with_session_write(|| service.sign_in(&account, &password, captcha.as_deref(), remember))
        .await
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
    match with_session_write(|| async {
        if SERVICE.get().is_none() {
            match ginkgo_runtime::has_saved_accounts() {
                Ok(false) => return Ok(signed_out()),
                Ok(true) => {}
                Err(error) => return Err(error),
            }
        }
        let service = service()?;
        Ok(match service.restore().await {
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
        })
    })
    .await
    {
        Ok(response) => response,
        Err(error) => failure_response(error),
    }
}

pub(super) async fn sign_out() -> SessionResponse {
    // Two steps, deliberately split. The exclusive gate guards only the
    // in-memory revocation; the saved-password purge touches platform storage
    // (JNI + blocking `commit()`) and runs after the gate is released, so a
    // slow Keystore can never queue other commands behind a logout.
    let revoked = with_session_write(|| async {
        let Some(Ok(service)) = SERVICE.get() else {
            return Ok(false);
        };
        service.sign_out().await;
        Ok(true)
    })
    .await;
    let Ok(true) = revoked else {
        // A gate timeout still reports signed-out: identity and cookies are
        // cleared by `sign_out` before it returns, and the local flag below
        // keeps the next start on the login page.
        return signed_out();
    };
    if let Some(Ok(service)) = SERVICE.get() {
        service.purge_credentials().await;
    }
    signed_out()
}

pub(super) async fn set_route(route: RouteChoice) -> SessionResponse {
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    let preference = match route {
        RouteChoice::Automatic => ginkgo_core::application::RoutePreference::Automatic,
        RouteChoice::Direct => ginkgo_core::application::RoutePreference::Direct,
        RouteChoice::WebVpn => ginkgo_core::application::RoutePreference::WebVpn,
    };
    match with_session_write(|| async {
        service.set_route(preference);
        Ok(status_response(service.status()))
    })
    .await
    {
        Ok(response) => response,
        Err(error) => failure_response(error),
    }
}

pub(super) async fn clear_cache() -> bool {
    with_session_write(|| async {
        Ok(service()
            .map(|service| {
                service.clear_snapshots();
                true
            })
            .unwrap_or(false))
    })
    .await
    // A gate timeout must not report a cleared cache that was not cleared.
    .unwrap_or(false)
}
pub(super) fn verify_credential_storage(account: String, secret: String) -> bool {
    ginkgo_runtime::verify_credential_storage(&account, &secret)
}
