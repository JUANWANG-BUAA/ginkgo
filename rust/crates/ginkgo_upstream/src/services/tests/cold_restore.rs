//! Cold restore over a strict, local UC transcript. A saved password is present
//! to detect accidental fallthrough to CAS when the alternate proof fails.
use super::*;
use crate::auth::session::{RouteMode, Session};
use crate::{
    auth::{session::SessionCookies, vault::MemoryVault, PersistedSession, UC_STATUS_URL},
    foundation::{
        cookie::CookieJar,
        http::{HttpRequest, HttpResponse, TransportError},
        webvpn,
    },
    test_support::TranscriptTransport,
};

const ACCOUNT: &str = "sy2501001";
const ROUTES: [(RouteMode, RouteMode); 2] = [
    (RouteMode::Direct, RouteMode::WebVpn),
    (RouteMode::WebVpn, RouteMode::Direct),
];
type Step = (HttpRequest, Result<HttpResponse, TransportError>);

fn wire(route: RouteMode) -> String {
    match route {
        RouteMode::Direct => UC_STATUS_URL.into(),
        RouteMode::WebVpn => webvpn::wrap(UC_STATUS_URL).unwrap(),
        RouteMode::Automatic => unreachable!(),
    }
}

fn cookie(route: RouteMode) -> &'static str {
    match route {
        RouteMode::Direct => "UC=direct",
        RouteMode::WebVpn => "UC=vpn",
        RouteMode::Automatic => unreachable!(),
    }
}

fn status(route: RouteMode) -> HttpRequest {
    HttpRequest::get(wire(route))
        .header(
            "Accept",
            "application/json, text/javascript, */*; q=0.01, application/json",
        )
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Cookie", cookie(route))
}

fn profile(account: &str) -> String {
    format!(r#"{{"code":0,"data":{{"schoolid":"{account}","name":"UC fixture"}}}}"#)
}

fn setup(
    original: RouteMode,
    both_jars: bool,
    preference: RoutePreference,
    steps: Vec<Step>,
) -> (
    SchoolClient<TranscriptTransport, MemoryVault>,
    PersistedSession,
) {
    let vault = MemoryVault::with(
        ACCOUNT,
        Credentials {
            username: ACCOUNT.into(),
            password: "synthetic-only".into(),
            captcha_text: None,
        },
    );
    let jar = |route| {
        let mut jar = CookieJar::new();
        if both_jars || route == original {
            jar.store(
                &wire(route),
                &format!("{}; Path=/; Secure", cookie(route)),
                CookieJar::now_ms(),
            );
        }
        jar
    };
    let mut saved = PersistedSession::new(
        ACCOUNT.into(),
        "cached, not verified".into(),
        original,
        SessionCookies {
            direct: jar(RouteMode::Direct),
            webvpn: jar(RouteMode::WebVpn),
        },
    );
    saved.saved_at_ms -= 60_000;
    vault.save_session(&saved).unwrap();
    let client = SchoolClient::new(Session::new(TranscriptTransport::new(steps)), vault);
    client.set_route(preference);
    (client, saved)
}

#[tokio::test]
async fn cold_automatic_restore_commits_only_same_account_uc_and_preserves_start_time() {
    for (original, target) in ROUTES {
        let steps = vec![
            (status(original), Err(TransportError::Unreachable)),
            (
                status(target),
                Ok(HttpResponse::new(200, wire(target), profile(ACCOUNT))
                    .with_set_cookie("UC=verified; Path=/; Secure")),
            ),
        ];
        let (client, before) = setup(original, true, RoutePreference::Automatic, steps);
        assert_eq!(client.verified_route(), None);
        let outcome = client.restore().await.unwrap();
        assert!(
            matches!(outcome, SessionOutcome::SignedIn { profile, remembered: true }
            if profile.school_id == ACCOUNT && profile.name == "UC fixture")
        );
        let after = client.vault.load_session().unwrap().unwrap();
        assert_eq!(client.status().account.as_deref(), Some(ACCOUNT));
        assert_eq!(client.status().route, RoutePreference::Automatic);
        assert_eq!(
            client.verified_route(),
            Some(if target == RouteMode::Direct {
                RoutePreference::Direct
            } else {
                RoutePreference::WebVpn
            })
        );
        assert_eq!(client.session.route(), target);
        assert_eq!(after.route, target);
        assert_eq!(after.saved_at_ms, before.saved_at_ms);
        assert_eq!(after.account, ACCOUNT);
        assert_eq!(after.profile_name, "UC fixture");
        assert_eq!(
            serde_json::to_value(&after.cookies).unwrap(),
            serde_json::to_value(client.session.cookie_snapshot()).unwrap()
        );
        let (mut committed, untouched, before_untouched) = if target == RouteMode::WebVpn {
            (
                after.cookies.webvpn,
                after.cookies.direct,
                before.cookies.direct,
            )
        } else {
            (
                after.cookies.direct,
                after.cookies.webvpn,
                before.cookies.webvpn,
            )
        };
        assert_eq!(
            committed
                .header_for(&wire(target), CookieJar::now_ms())
                .as_deref(),
            Some("UC=verified")
        );
        assert_eq!(
            serde_json::to_value(untouched).unwrap(),
            serde_json::to_value(before_untouched).unwrap()
        );
        assert!(client.session_credentials().is_none());
        client.session.transport().assert_finished();
    }
}

#[tokio::test]
async fn cold_automatic_restore_rejects_unverified_alternate_without_modifying_either_jar() {
    for (original, target) in ROUTES {
        for response in [
            Ok(HttpResponse::new(200, wire(target), profile("sy2501002"))),
            Ok(HttpResponse::new(
                200,
                wire(target),
                r#"{"code":10600,"data":null}"#,
            )),
            Ok(HttpResponse::new(503, wire(target), "temporary")),
            Ok(HttpResponse::new(200, wire(target), "changed")),
            Err(TransportError::Unreachable),
        ] {
            let steps = vec![
                (status(original), Err(TransportError::Unreachable)),
                (
                    status(target),
                    response.map(|r| {
                        r.with_set_cookie("UC=; Path=/; Max-Age=0; Secure")
                            .with_set_cookie("OTHER=unverified; Path=/; Secure")
                    }),
                ),
            ];
            let (client, before) = setup(original, true, RoutePreference::Automatic, steps);
            assert_eq!(
                client.restore().await.unwrap_err().code,
                ErrorCode::NetworkUnreachable
            );
            assert_eq!(client.session.route(), original);
            assert_eq!(client.status().account, None);
            assert_eq!(client.status().profile, None);
            assert_eq!(client.verified_route(), None);
            assert_eq!(
                serde_json::to_value(client.session.cookie_snapshot()).unwrap(),
                serde_json::to_value(&before.cookies).unwrap()
            );
            assert_eq!(
                serde_json::to_value(client.vault.load_session().unwrap().unwrap()).unwrap(),
                serde_json::to_value(before).unwrap()
            );
            assert_eq!(client.vault.names(), vec![ACCOUNT]);
            assert!(client.session_credentials().is_none());
            client.session.transport().assert_finished();
        }
    }
}

#[tokio::test]
async fn cold_restore_skips_alternate_for_explicit_route_missing_target_cookies_or_service_errors()
{
    for (original, _) in ROUTES {
        let explicit = if original == RouteMode::Direct {
            RoutePreference::Direct
        } else {
            RoutePreference::WebVpn
        };
        for (preference, both, response, expected) in [
            (
                explicit,
                true,
                Err(TransportError::Unreachable),
                ErrorCode::NetworkUnreachable,
            ),
            (
                RoutePreference::Automatic,
                false,
                Err(TransportError::Unreachable),
                ErrorCode::NetworkUnreachable,
            ),
            (
                RoutePreference::Automatic,
                true,
                Ok(HttpResponse::new(503, wire(original), "temporary")),
                ErrorCode::ServiceUnavailable,
            ),
            (
                RoutePreference::Automatic,
                true,
                Ok(HttpResponse::new(483, wire(original), "denied")),
                ErrorCode::AccessPolicyDenied,
            ),
        ] {
            let (client, _) = setup(
                original,
                both,
                preference,
                vec![(status(original), response)],
            );
            assert_eq!(client.restore().await.unwrap_err().code, expected);
            assert_eq!(client.verified_route(), None);
            client.session.transport().assert_finished();
        }
    }
}

#[tokio::test]
async fn signed_in_switch_changes_preference_only_after_same_owner_probe() {
    for (original, target) in ROUTES {
        let explicit = |r| {
            if r == RouteMode::Direct {
                RoutePreference::Direct
            } else {
                RoutePreference::WebVpn
            }
        };
        for succeeds in [false, true] {
            let steps = vec![
                (
                    status(original),
                    Ok(HttpResponse::new(200, wire(original), profile(ACCOUNT))),
                ),
                (
                    status(target),
                    Ok(HttpResponse::new(
                        200,
                        wire(target),
                        profile(if succeeds { ACCOUNT } else { "sy2501002" }),
                    )
                    .with_set_cookie("UC=rotated; Path=/; Secure")),
                ),
            ];
            let (client, saved) = setup(original, true, RoutePreference::Automatic, steps);
            client.restore().await.unwrap();
            client
                .switch_verified_route(explicit(original))
                .await
                .unwrap();
            assert_eq!(client.status().route, explicit(original));
            client
                .switch_verified_route(RoutePreference::Automatic)
                .await
                .unwrap();
            assert_eq!(client.status().route, RoutePreference::Automatic);
            assert_eq!(client.verified_route(), Some(explicit(original)));
            client.identity.lock().library_token = Some("fixture".into());
            client.remember_session_credentials(&Credentials {
                username: ACCOUNT.into(),
                password: "synthetic-only".into(),
                captcha_text: None,
            });
            let before = client.vault.load_session().unwrap().unwrap();
            let result = client.switch_verified_route(explicit(target)).await;
            let after = client.vault.load_session().unwrap().unwrap();
            assert_eq!(after.account, ACCOUNT);
            assert_eq!(after.saved_at_ms, saved.saved_at_ms);
            assert_eq!(client.status().account.as_deref(), Some(ACCOUNT));
            assert_eq!(client.session_credentials().unwrap().username, ACCOUNT);
            if succeeds {
                result.unwrap();
                assert_eq!(client.session.route(), target);
                assert_eq!(client.status().route, explicit(target));
                assert_eq!(client.verified_route(), Some(explicit(target)));
                assert_eq!(after.route, target);
                assert!(client.identity.lock().library_token.is_none());
            } else {
                assert!(result.is_err());
                assert_eq!(client.session.route(), original);
                assert_eq!(client.status().route, RoutePreference::Automatic);
                assert_eq!(client.verified_route(), Some(explicit(original)));
                assert_eq!(
                    client.identity.lock().library_token.as_deref(),
                    Some("fixture")
                );
                assert_eq!(
                    serde_json::to_value(client.session.cookie_snapshot()).unwrap(),
                    serde_json::to_value(&before.cookies).unwrap()
                );
                assert_eq!(
                    serde_json::to_value(after).unwrap(),
                    serde_json::to_value(before).unwrap()
                );
            }
            client.session.transport().assert_finished();
        }
    }
}

struct HoldAlternate {
    transcript: TranscriptTransport,
    started: tokio::sync::Notify,
    resume: tokio::sync::Notify,
}

impl HttpTransport for HoldAlternate {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        let hold = request.url == wire(RouteMode::WebVpn);
        let response = self.transcript.send(request).await;
        if hold {
            self.started.notify_one();
            self.resume.notified().await;
        }
        response
    }
}

#[tokio::test]
async fn signout_during_alternate_uc_rejects_late_identity_cookie_and_vault_writes() {
    for cold in [false, true] {
        let original = RouteMode::Direct;
        let target = RouteMode::WebVpn;
        let (seed, _) = setup(original, true, RoutePreference::Automatic, vec![]);
        let session = Session::new(HoldAlternate {
            transcript: TranscriptTransport::new(vec![
                (
                    status(original),
                    if cold {
                        Err(TransportError::Unreachable)
                    } else {
                        Ok(HttpResponse::new(200, wire(original), profile(ACCOUNT)))
                    },
                ),
                (
                    status(target),
                    Ok(HttpResponse::new(200, wire(target), profile(ACCOUNT))
                        .with_set_cookie("LATE=unverified; Path=/; Secure")),
                ),
            ]),
            started: Default::default(),
            resume: Default::default(),
        });
        let client = SchoolClient::new(session, seed.vault.as_ref().clone());
        client.set_route(RoutePreference::Automatic);
        if !cold {
            client.restore().await.unwrap();
        }
        let probe = async {
            if cold {
                client.restore().await.map(|_| ())
            } else {
                client.switch_verified_route(RoutePreference::WebVpn).await
            }
        };
        let logout = async {
            client.session.transport().started.notified().await;
            client.sign_out().await;
            client.purge_credentials().await;
            client.session.transport().resume.notify_one();
        };
        let (outcome, ()) = tokio::time::timeout(std::time::Duration::from_secs(3), async {
            tokio::join!(probe, logout)
        })
        .await
        .unwrap();
        assert!(outcome.is_err());
        assert_eq!(client.verified_route(), None);
        assert!(!client.status().signed_in());
        assert!(client.vault.load_session().unwrap().is_none());
        assert!(client.vault.names().is_empty());
        assert!(!client.session.direct_cookie_present());
        assert!(!client.session.webvpn_cookie_present());
        client.session.transport().transcript.assert_finished();
    }
}

#[tokio::test]
async fn changing_preference_on_current_route_disables_and_enables_business_fallback() {
    let direct = RouteMode::Direct;
    let vpn = RouteMode::WebVpn;
    let business = "https://iclass.buaa.edu.cn:8346/app/entry";
    let gateway = webvpn::wrap(business).unwrap();
    let steps = vec![
        (
            status(direct),
            Ok(HttpResponse::new(200, wire(direct), profile(ACCOUNT))),
        ),
        (HttpRequest::get(business), Err(TransportError::Unreachable)),
        (HttpRequest::get(business), Err(TransportError::Unreachable)),
        (
            status(vpn),
            Ok(HttpResponse::new(200, wire(vpn), profile(ACCOUNT))),
        ),
        (
            HttpRequest::get(&gateway).header("Cookie", cookie(vpn)),
            Ok(HttpResponse::new(200, &gateway, "business")),
        ),
    ];
    let (client, _) = setup(direct, true, RoutePreference::Automatic, steps);
    client.restore().await.unwrap();
    client
        .switch_verified_route(RoutePreference::Direct)
        .await
        .unwrap();
    assert_eq!(
        client
            .session
            .send_with_fallback(HttpRequest::get(business))
            .await
            .unwrap_err()
            .code,
        ErrorCode::NetworkUnreachable
    );
    client
        .switch_verified_route(RoutePreference::Automatic)
        .await
        .unwrap();
    assert_eq!(
        client
            .session
            .send_with_fallback(HttpRequest::get(business))
            .await
            .unwrap()
            .body,
        "business"
    );
    assert_eq!(client.verified_route(), Some(RoutePreference::WebVpn));
    client.session.transport().assert_finished();
}

#[tokio::test]
async fn cold_restore_never_sends_an_anonymous_alternate_probe() {
    for (original, target) in ROUTES {
        for unusable in [
            "STALE=old; Path=/; Secure; Max-Age=1",
            "MODULE=scoped; Path=/elsewhere; Secure",
        ] {
            let (client, mut record) = setup(
                original,
                false,
                RoutePreference::Automatic,
                vec![(status(original), Err(TransportError::Unreachable))],
            );
            let jar = match target {
                RouteMode::Direct => &mut record.cookies.direct,
                RouteMode::WebVpn => &mut record.cookies.webvpn,
                RouteMode::Automatic => unreachable!(),
            };
            jar.store(&wire(target), unusable, CookieJar::now_ms() - 10_000);
            client.vault.save_session(&record).unwrap();
            assert_eq!(
                client.restore().await.unwrap_err().code,
                ErrorCode::NetworkUnreachable
            );
            assert_eq!(
                serde_json::to_value(client.session.cookie_snapshot()).unwrap(),
                serde_json::to_value(record.cookies).unwrap()
            );
            assert_eq!(client.verified_route(), None);
            client.session.transport().assert_finished();
        }
    }
}

#[tokio::test]
async fn warm_restore_network_failure_does_not_trigger_cold_alternate_probe() {
    let route = RouteMode::Direct;
    let (client, _) = setup(
        route,
        true,
        RoutePreference::Automatic,
        vec![
            (
                status(route),
                Ok(HttpResponse::new(200, wire(route), profile(ACCOUNT))),
            ),
            (status(route), Err(TransportError::Unreachable)),
        ],
    );
    client.restore().await.unwrap();
    assert_eq!(
        client.restore().await.unwrap_err().code,
        ErrorCode::NetworkUnreachable
    );
    assert_eq!(client.verified_route(), Some(RoutePreference::Direct));
    client.session.transport().assert_finished();
}

#[tokio::test]
async fn concurrent_target_cookie_rotation_wins_over_staged_proof() {
    let (seed, _) = setup(RouteMode::Direct, true, RoutePreference::Automatic, vec![]);
    let target = RouteMode::WebVpn;
    let other_url = "https://uc.buaa.edu.cn/other";
    let other_wire = webvpn::wrap(other_url).unwrap();
    let session = Session::new(HoldAlternate {
        transcript: TranscriptTransport::new(vec![
            (
                status(RouteMode::Direct),
                Ok(HttpResponse::new(
                    200,
                    wire(RouteMode::Direct),
                    profile(ACCOUNT),
                )),
            ),
            (
                status(target),
                Ok(HttpResponse::new(200, wire(target), profile(ACCOUNT))
                    .with_set_cookie("UC=late; Path=/; Secure")),
            ),
            (
                HttpRequest::get(&other_wire).header("Cookie", cookie(target)),
                Ok(HttpResponse::new(200, &other_wire, "other")
                    .with_set_cookie("UC=newer; Path=/; Secure")),
            ),
        ]),
        started: Default::default(),
        resume: Default::default(),
    });
    let client = SchoolClient::new(session, seed.vault.as_ref().clone());
    client.set_route(RoutePreference::Automatic);
    client.restore().await.unwrap();
    let rotate = async {
        client.session.transport().started.notified().await;
        client
            .session
            .routed(target)
            .send(HttpRequest::get(other_url))
            .await
            .unwrap();
        client.session.transport().resume.notify_one();
    };
    let (result, ()) = tokio::time::timeout(std::time::Duration::from_secs(3), async {
        tokio::join!(
            client.switch_verified_route(RoutePreference::WebVpn),
            rotate
        )
    })
    .await
    .unwrap();
    assert!(result.is_err());
    assert_eq!(client.verified_route(), Some(RoutePreference::Direct));
    assert_eq!(client.status().route, RoutePreference::Automatic);
    let mut record = client.vault.load_session().unwrap().unwrap();
    assert_eq!(record.route, RouteMode::Direct);
    assert_eq!(
        record
            .cookies
            .webvpn
            .header_for(&wire(target), CookieJar::now_ms())
            .as_deref(),
        Some("UC=newer")
    );
    client.session.transport().transcript.assert_finished();
}

#[tokio::test]
async fn cancelling_switch_during_blocking_save_keeps_purge_behind_worker() {
    use std::{
        future::{poll_fn, Future},
        sync::{mpsc, Arc, Mutex},
        task::Poll,
        time::Duration,
    };

    let original = RouteMode::Direct;
    let target = RouteMode::WebVpn;
    let steps = vec![
        (
            status(original),
            Ok(HttpResponse::new(200, wire(original), profile(ACCOUNT))),
        ),
        (
            status(target),
            Ok(HttpResponse::new(200, wire(target), profile(ACCOUNT))),
        ),
    ];
    let (client, saved) = setup(original, true, RoutePreference::Automatic, steps);
    client.restore().await.unwrap();
    let started = Arc::new(tokio::sync::Notify::new());
    let entered = Arc::clone(&started);
    let (release, receiver) = mpsc::channel();
    let receiver = Mutex::new(Some(receiver));
    let vault = Arc::clone(&client.vault);
    client.session.set_cookie_persistor(move |cookies| {
        let receiver = receiver
            .lock()
            .unwrap()
            .take()
            .expect("only one verified route save");
        let mut writing = saved.clone();
        writing.cookies = cookies;
        writing.route = target;
        let vault = Arc::clone(&vault);
        let entered = Arc::clone(&entered);
        Some(Box::pin(async move {
            tokio::task::spawn_blocking(move || {
                entered.notify_one();
                receiver.recv_timeout(Duration::from_secs(3)).unwrap();
                vault.save_session(&writing).unwrap();
            })
            .await
            .unwrap();
        }))
    });
    // Dropping the switch future here models a bridge deadline. The actual
    // worker is still blocked, so cancellation cannot release its save gate.
    tokio::select! {
        result = client.switch_verified_route(RoutePreference::WebVpn) => panic!("switch returned before vault write: {result:?}"),
        () = started.notified() => (),
    }
    client.sign_out().await;
    let mut drain = Box::pin(client.session.drain_cookie_writes());
    assert!(poll_fn(|cx| Poll::Ready(drain.as_mut().poll(cx).is_pending())).await);
    drop(drain);
    let mut purge = Box::pin(client.purge_credentials());
    assert!(poll_fn(|cx| Poll::Ready(purge.as_mut().poll(cx).is_pending())).await);
    release.send(()).unwrap();
    tokio::time::timeout(Duration::from_secs(3), purge)
        .await
        .unwrap();
    assert!(client.vault.load_session().unwrap().is_none());
    assert!(client.vault.names().is_empty());
    assert_eq!(client.verified_route(), None);
    client.session.transport().assert_finished();
}
