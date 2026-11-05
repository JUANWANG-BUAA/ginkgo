//! A password-blind, memory-only copy for background reminder reads.
use crate::{
    auth::{session::Session, vault::MemoryVault, CredentialVault, PersistedSession},
    foundation::{cookie::CookieJar, http::HttpTransport},
    services::session_service::SchoolClient,
    AppError,
};
use md5::{Digest, Md5};

/// Opaque local ownership key, not encryption or an authentication proof.
pub fn owner_key(account: &str) -> String {
    format!("{:x}", Md5::digest(format!("{account}:background")))
}

pub fn from_snapshot<T: HttpTransport + Send + Sync>(
    transport: T,
    snapshot: PersistedSession,
    expected_owner: &str,
) -> Result<SchoolClient<T, MemoryVault>, AppError> {
    if owner_key(&snapshot.account) != expected_owner
        || !snapshot.is_usable_for(snapshot.route, CookieJar::now_ms())
    {
        return Err(AppError::session_expired());
    }
    // Never attach the platform vault: recovery can neither enumerate/read a
    // password nor overwrite/delete the foreground session's encrypted record.
    let vault = MemoryVault::default();
    vault.save_session(&snapshot)?;
    Ok(SchoolClient::new(Session::new(transport), vault))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        auth::{session::RouteMode, CredentialSource},
        foundation::http::{HttpRequest, HttpResponse, TransportError},
    };
    use ginkgo_domain::ports::SessionSource;

    struct NoNetwork;
    impl HttpTransport for NoNetwork {
        async fn send(&self, _: HttpRequest) -> Result<HttpResponse, TransportError> {
            panic!("invalid background snapshot must not send requests")
        }
    }

    #[test]
    fn missing_or_other_owner_is_rejected_before_http() {
        let saved = PersistedSession::new(
            "sy2501001".into(),
            "synthetic".into(),
            RouteMode::WebVpn,
            crate::auth::session::SessionCookies {
                direct: CookieJar::default(),
                webvpn: CookieJar::default(),
            },
        );
        assert!(from_snapshot(NoNetwork, saved.clone(), &owner_key("sy2501002")).is_err());
        assert!(from_snapshot(NoNetwork, saved, &owner_key("sy2501001")).is_err());
    }

    #[tokio::test]
    async fn empty_background_vault_cannot_start_password_recovery() {
        let vault = MemoryVault::default();
        assert!(vault.accounts().unwrap().is_empty());
        assert!(vault.load("sy2501001").unwrap().is_none());
        let service = SchoolClient::new(Session::new(NoNetwork), vault);
        assert!(matches!(
            service.restore().await.unwrap(),
            ginkgo_domain::ports::SessionOutcome::SignedOut
        ));
    }

    #[tokio::test]
    async fn background_restore_is_one_exact_cookie_get_without_any_password() {
        use crate::{
            auth::{session::SessionCookies, UC_STATUS_URL},
            test_support::TranscriptTransport,
        };
        for route in [RouteMode::Direct, RouteMode::WebVpn] {
            for body in [
                r#"{"code":0,"data":{"schoolid":"sy2501001","name":"synthetic"}}"#,
                r#"{"code":10600,"data":null}"#,
                r#"{"code":0,"data":{"schoolid":"sy2501002","name":"other"}}"#,
            ] {
                let mut cookies = CookieJar::new();
                let target = if route == RouteMode::WebVpn {
                    crate::foundation::webvpn::wrap(UC_STATUS_URL).unwrap()
                } else {
                    UC_STATUS_URL.to_string()
                };
                cookies.store(&target, "uc=synthetic; Path=/; Secure", CookieJar::now_ms());
                let saved = PersistedSession::new(
                    "sy2501001".into(),
                    "synthetic".into(),
                    route,
                    if route == RouteMode::Direct {
                        SessionCookies {
                            direct: cookies,
                            webvpn: CookieJar::new(),
                        }
                    } else {
                        SessionCookies {
                            direct: CookieJar::new(),
                            webvpn: cookies,
                        }
                    },
                );
                let expected = HttpRequest::get(&target)
                    .header(
                        "Accept",
                        "application/json, text/javascript, */*; q=0.01, application/json",
                    )
                    .header("X-Requested-With", "XMLHttpRequest")
                    .header("Cookie", "uc=synthetic");
                let transport = TranscriptTransport::new(vec![(
                    expected,
                    Ok(HttpResponse::new(200, &target, body)),
                )]);
                let client =
                    from_snapshot(transport.clone(), saved, &owner_key("sy2501001")).unwrap();
                let result = client.restore().await.unwrap();
                assert_eq!(
                    matches!(
                        result,
                        ginkgo_domain::ports::SessionOutcome::SignedIn { .. }
                    ),
                    body.contains("sy2501001")
                );
                transport.assert_finished();
            }
        }
    }
}
