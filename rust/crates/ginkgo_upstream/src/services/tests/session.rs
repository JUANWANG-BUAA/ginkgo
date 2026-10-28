use super::*;

#[test]
fn a_poisoned_identity_is_kept_and_the_recovery_is_observable() {
    let (service, _) = build_service(vec![], MemoryVault::default());
    let panic = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut identity = service.identity.lock();
        identity.authenticated = Some(crate::services::session_service::AuthenticatedIdentity {
            account: "sy2501001".into(),
            profile: UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        });
        panic!("synthetic interrupted identity update");
    }));
    assert!(panic.is_err());
    // The panic must not sign the user out: the value under the lock is kept
    // and later reads keep working instead of panicking.
    assert!(service.status().signed_in());
    assert_eq!(service.status().account.as_deref(), Some("sy2501001"));
    assert_eq!(
        service.current_account().expect("kept account"),
        "sy2501001"
    );
    // The recovery stays observable instead of being a silent reset.
    assert_eq!(service.identity.poison_count(), 1);
    assert!(service.lock_poison_events() >= 1);
}

#[test]
fn a_poisoned_snapshot_is_kept_and_can_be_populated_again() {
    let (service, _) = build_service(vec![], MemoryVault::default());
    let panic = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut cache = service.snapshots.checkin.lock();
        cache.insert("2026-10-21".into(), vec![]);
        panic!("synthetic interrupted cache update");
    }));
    assert!(panic.is_err());
    // The interrupted snapshot survives the panic instead of being dropped.
    assert!(service
        .snapshots
        .checkin
        .lock()
        .any(&"2026-10-21".into())
        .is_some());
    assert_eq!(service.snapshots.checkin.poison_count(), 1);
    // An explicit cache clear still empties it.
    service.clear_snapshots();
    assert!(service
        .snapshots
        .checkin
        .lock()
        .any(&"2026-10-21".into())
        .is_none());
    service
        .snapshots
        .checkin
        .lock()
        .insert("2026-10-21".into(), vec![]);
    assert!(service
        .snapshots
        .checkin
        .lock()
        .any(&"2026-10-21".into())
        .is_some());
}

#[test]
fn readers_observe_complete_identity_snapshots_during_account_changes() {
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        Barrier,
    };
    let (service, _) = build_service(vec![], MemoryVault::default());
    let ready = Barrier::new(2);
    let done = AtomicBool::new(false);
    std::thread::scope(|scope| {
        scope.spawn(|| {
            ready.wait();
            for index in 0..10_000 {
                let account = format!("synthetic-{index}");
                service.set_authenticated(
                    account.clone(),
                    UserProfile {
                        school_id: account,
                        name: "synthetic".into(),
                    },
                );
                if index % 3 == 0 {
                    service.set_route(if index % 2 == 0 {
                        RoutePreference::Direct
                    } else {
                        RoutePreference::WebVpn
                    });
                }
            }
            done.store(true, Ordering::Release);
        });
        ready.wait();
        loop {
            let status = service.status();
            match (status.account, status.profile) {
                (Some(account), Some(profile)) => assert_eq!(account, profile.school_id),
                (None, None) => {}
                _ => panic!("account and profile must be published together"),
            }
            if done.load(Ordering::Acquire) {
                break;
            }
        }
    });
}

#[test]
fn replacing_or_clearing_identity_drops_every_business_credential() {
    use crate::services::session_service::{AuthenticatedIdentity, Identity};
    let (service, _) = build_service(vec![], MemoryVault::default());
    for clear_by_route in [false, true] {
        *service.identity.lock() = Identity {
            authenticated: Some(AuthenticatedIdentity {
                account: "synthetic-old".into(),
                profile: UserProfile {
                    school_id: "synthetic-old".into(),
                    name: "synthetic".into(),
                },
            }),
            pending_login: None,
            iclass: Some(crate::codecs::checkin::IClassSession {
                user_id: "synthetic".into(),
                session_id: "synthetic".into(),
            }),
            library_token: Some("synthetic".into()),
            cgyy_token: Some("synthetic".into()),
            ..Identity::default()
        };
        if clear_by_route {
            service.set_route(RoutePreference::Direct);
        } else {
            service.set_authenticated(
                "synthetic-new".into(),
                UserProfile {
                    school_id: "synthetic-new".into(),
                    name: "synthetic".into(),
                },
            );
        }
        let identity = service.identity.lock();
        assert!(identity.iclass.is_none());
        assert!(identity.library_token.is_none());
        assert!(identity.cgyy_token.is_none());
        assert!(identity.pending_login.is_none());
        assert_eq!(identity.authenticated.is_none(), clear_by_route);
    }
}

#[tokio::test]
async fn an_existing_session_for_another_account_is_never_published_under_the_entered_username() {
    // CAS still holds a valid session for sy2501000 while the user submits
    // sy2501001: the profile of the cookie owner must not be bound to the
    // entered account, and the foreign cookies must be dropped.
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://uc.buaa.edu.cn/api/login?target=x")
            .with_set_cookie("CASTGC=TGT-foreign; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://uc.buaa.edu.cn/api/login?target=x",
            "<html>home</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok("sy2501000", "someone else"),
    ]);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport),
        MemoryVault::default(),
    );
    let error = service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect_err("cookie session belongs to another account");
    assert_eq!(error.code, ErrorCode::SessionExpired);
    assert_eq!(error.detail.as_deref(), Some("identity_mismatch"));
    assert!(!service.status().signed_in());
    assert!(!service.session.direct_cookie_present());
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn restore_never_rebinds_a_foreign_cookie_session_to_a_saved_account() {
    // The vault holds sy2501001 but the device still carries sy2501000's
    // valid CAS cookies; restore must fail instead of signing in.
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://uc.buaa.edu.cn/api/login?target=x")
            .with_set_cookie("CASTGC=TGT-foreign; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://uc.buaa.edu.cn/api/login?target=x",
            "<html>home</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok("sy2501000", "someone else"),
    ]);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport),
        seeded("sy2501001"),
    );
    let error = service.restore().await.expect_err("foreign session");
    assert_eq!(error.detail.as_deref(), Some("identity_mismatch"));
    assert!(!service.status().signed_in());
    assert!(service.session.direct_cookie_present().eq(&false));
}

#[tokio::test]
async fn sign_in_returns_profile_and_stores_sanitized_credentials() {
    let (service, transport) =
        build_service(login_chain("sy2501001", "fixture"), MemoryVault::default());
    let outcome = service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    match outcome {
        SessionOutcome::SignedIn {
            profile,
            remembered,
        } => {
            assert_eq!(profile.school_id, "sy2501001");
            assert_eq!(profile.name, "fixture");
            assert!(remembered);
        }
        _ => panic!("expected signed in"),
    }
    let saved = service
        .vault
        .load("sy2501001")
        .expect("vault")
        .expect("saved");
    assert_eq!(saved.password, "pa+ss/word");
    assert_eq!(saved.captcha_text, None);
    assert_eq!(transport.request_count(), 5);
    assert_eq!(service.status().route, RoutePreference::Automatic);
}

#[tokio::test]
async fn sign_in_without_remember_removes_an_old_entry() {
    let (service, _) = build_service(login_chain("sy2501001", "fixture"), seeded("sy2501001"));
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .expect("signed in");
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn wrong_password_is_typed_and_not_persisted() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
    ]);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport),
        MemoryVault::default(),
    );
    assert_eq!(
        service
            .sign_in("sy2501001", "wrong", None, true)
            .await
            .expect_err("wrong")
            .code,
        ErrorCode::InvalidCredentials
    );
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn restore_reuses_a_saved_account_or_reports_a_captcha() {
    let (service, transport) =
        build_service(login_chain("sy2501001", "fixture"), seeded("sy2501001"));
    match service.restore().await.expect("restore") {
        SessionOutcome::SignedIn { profile, .. } => assert_eq!(profile.school_id, "sy2501001"),
        _ => panic!("expected signed in"),
    }
    assert_eq!(transport.request_count(), 5);

    let captcha_page = FORM_PAGE.replace(
        "</form>",
        "<script>config.captcha = { type: 'slider', id: 'cap-1' };</script></form>",
    );
    let (service, _) = build_service(
        vec![HttpResponse::new(200, LOGIN_URL, captcha_page)],
        seeded("sy2501001"),
    );
    match service.restore().await.expect("captcha") {
        SessionOutcome::CaptchaRequired(challenge) => assert_eq!(challenge.id, "cap-1"),
        _ => panic!("expected captcha"),
    }
}

#[tokio::test]
async fn restore_without_a_saved_account_is_a_clean_signed_out_state() {
    let transport = MockTransport::default();
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    assert!(matches!(
        service.restore().await.expect("restore"),
        SessionOutcome::SignedOut
    ));
    assert_eq!(transport.request_count(), 0);
}

#[tokio::test]
async fn restore_deletes_an_entry_that_no_longer_authenticates() {
    let (service, _) = build_service(
        vec![
            HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
            HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
        ],
        seeded("sy2501001"),
    );
    assert!(matches!(
        service.restore().await.expect("restore"),
        SessionOutcome::SignedOut
    ));
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn sign_out_clears_identity_credentials_and_snapshots() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(200, "search", classroom_body()));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    service.load_classrooms(&input()).await.expect("classrooms");
    let requests = transport.request_count();
    service.sign_out().await;
    // Revocation is complete before the second step runs: no upstream request,
    // no identity, no cookies.
    assert_eq!(transport.request_count(), requests);
    assert_eq!(
        service.status(),
        SessionStatus {
            account: None,
            profile: None,
            route: RoutePreference::Automatic,
        }
    );
    assert_eq!(
        service.vault.names().len(),
        1,
        "revocation must not depend on platform storage latency"
    );
    // The saved password is purged by the separate, gate-free second step.
    service.purge_credentials().await;
    assert!(service.vault.names().is_empty());
    // Purging twice is harmless and never resurrects an account.
    service.purge_credentials().await;
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn in_memory_session_is_revalidated_before_restore_succeeds() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(uc_ok("sy2501001", "fixture"));
    let (service, _) = build_service(responses, seeded("sy2501001"));
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    match service.restore().await.expect("restore") {
        SessionOutcome::SignedIn { profile, .. } => assert_eq!(profile.name, "fixture"),
        _ => panic!("expected signed in"),
    }
}

#[test]
fn session_outcomes_are_constructible_for_the_bridge() {
    // Compile-time guard: the bridge maps this enum without exposing internals.
    let _ = LoginResult::SignedIn(UserProfile {
        school_id: "sy2501001".into(),
        name: "fixture".into(),
    });
    let _ = RoutePreference::WebVpn;
}

#[tokio::test]
async fn captcha_answer_reuses_the_original_login_page() {
    let captcha_page = FORM_PAGE.replace(
        "</form>",
        "<script>config.captcha = { type: 'local', id: 'cap-1' };</script></form>",
    );
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, captcha_page),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1")
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login?ticket=ST-1",
            "<html>ok</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok("sy2501001", "fixture"),
    ]);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    match service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("challenge")
    {
        SessionOutcome::CaptchaRequired(challenge) => assert_eq!(challenge.id, "cap-1"),
        _ => panic!("expected captcha"),
    }
    assert_eq!(transport.request_count(), 1);

    match service
        .sign_in("sy2501001", "pa+ss/word", Some("1234"), true)
        .await
        .expect("signed in")
    {
        SessionOutcome::SignedIn { profile, .. } => {
            assert_eq!(profile.school_id, "sy2501001")
        }
        _ => panic!("expected signed in"),
    }
    let requests = transport.requests();
    assert_eq!(requests[0].method, HttpMethod::Get);
    assert_eq!(requests[1].method, HttpMethod::Post);
    let body = requests[1].body.as_deref().expect("login body");
    assert!(body.contains("captcha=1234"));
    assert!(body.contains("execution=abc%2Bdef%2Fghi%3D"));
    let saved = service
        .vault
        .load("sy2501001")
        .expect("vault")
        .expect("saved");
    assert_eq!(saved.captcha_text, None);
}

#[tokio::test]
async fn sign_out_after_route_change_removes_saved_account() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "logout", ""));
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "fixture-password", None, true)
        .await
        .expect("login");
    service.set_route(RoutePreference::Direct);
    assert!(!service.status().signed_in());
    assert_eq!(service.vault.names().len(), 1);
    service.sign_out().await;
    service.purge_credentials().await;
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn concurrent_school_recovery_joins_one_login_chain() {
    use crate::foundation::http::HttpTransport;
    #[derive(Clone)]
    struct Yielding(MockTransport);
    impl HttpTransport for Yielding {
        async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
            tokio::task::yield_now().await;
            self.0.send(request).await
        }
    }
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend(login_chain("sy2501001", "fixture"));
    let transport = MockTransport::with_responses(responses);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(Yielding(transport.clone())),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .unwrap();
    let before = transport.request_count();
    let (a, b) = tokio::join!(service.silent_login(), service.silent_login());
    assert!(a.is_ok() && b.is_ok());
    assert_eq!(transport.request_count() - before, 5);
}

#[tokio::test]
async fn school_and_gateway_recovery_do_not_share_a_gate() {
    let (service, _) = recovery_failure_service();
    let _school = service.school_recovery_gate.lock().await;
    let gateway = tokio::time::timeout(
        std::time::Duration::from_millis(50),
        service.ensure_webvpn_session(),
    )
    .await;
    assert!(
        gateway.is_ok(),
        "gateway recovery must not wait for the independent school CAS chain"
    );
}

#[tokio::test]
async fn concurrent_expired_business_reads_share_a_failed_password_post() {
    use std::sync::atomic::Ordering;
    let (service, transport) = recovery_failure_service();
    let mut first = input();
    first.force_refresh = true;
    let mut second = first.clone();
    second.campus = 3;
    let (a, b) = tokio::join!(
        service.load_classrooms(&first),
        service.load_classrooms(&second)
    );
    assert_eq!(
        a.expect_err("first recovery failed").code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(
        b.expect_err("waiting recovery shares failure").code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 1);
    assert_eq!(
        service.current_account().expect("identity is retained"),
        "sy2501001"
    );
}

#[tokio::test]
async fn automatic_school_and_gateway_recovery_share_failure_until_explicit_login() {
    use std::sync::atomic::Ordering;
    let (service, transport) = recovery_failure_service();
    assert_eq!(
        service.silent_login().await.expect_err("CAS 500").code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(
        service
            .ensure_webvpn_session()
            .await
            .expect_err("gateway shares failure")
            .code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(
        service
            .silent_login()
            .await
            .expect_err("no automatic replay")
            .code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 1);

    // Explicit user login bypasses the automatic cooldown, but a 500 remains a
    // failure. Once the server recovers, a successful manual login clears it.
    assert!(service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .is_err());
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 2);
    transport.allow_login.store(true, Ordering::Relaxed);
    assert!(matches!(
        service
            .sign_in("sy2501001", "pa+ss/word", None, true)
            .await
            .expect("manual recovery"),
        SessionOutcome::SignedIn { .. }
    ));
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 3);
    service
        .silent_login()
        .await
        .expect("manual success cleared prior failure");
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 4);
}

#[tokio::test]
async fn automatic_login_failure_cooldown_expires_and_identity_changes_clear_it() {
    use std::{
        sync::atomic::Ordering,
        time::{Duration, Instant},
    };
    let (service, transport) = recovery_failure_service();
    let error = service.silent_login().await.expect_err("CAS 500");
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 1);
    // Advance only the stored monotonic timestamp: this test never sleeps.
    *service.automatic_login_failure.lock() =
        Some((Instant::now() - Duration::from_secs(61), error));
    assert_eq!(
        service
            .silent_login()
            .await
            .expect_err("one later attempt")
            .code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 2);
    service.set_route(RoutePreference::WebVpn);
    assert!(service.automatic_login_failure.lock().is_none());
    assert_eq!(
        service
            .silent_login()
            .await
            .expect_err("route invalidated identity")
            .code,
        ErrorCode::SessionExpired
    );
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 2);
}

#[tokio::test]
async fn failed_gateway_recovery_is_shared_with_school_recovery() {
    use std::sync::atomic::Ordering;
    let (service, transport) = recovery_failure_service();
    assert_eq!(
        service
            .ensure_webvpn_session()
            .await
            .expect_err("gateway CAS 500")
            .code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(
        service.session.route(),
        crate::auth::session::RouteMode::Automatic
    );
    let (school, gateway) = tokio::join!(service.silent_login(), service.ensure_webvpn_session());
    assert_eq!(
        school.expect_err("school shares failure").code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(
        gateway.expect_err("gateway shares failure").code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(transport.password_posts.load(Ordering::Relaxed), 1);
    assert!(transport
        .requests
        .lock()
        .expect("requests")
        .iter()
        .filter(|request| request.method == HttpMethod::Post)
        .all(|request| request.url.starts_with("https://d.buaa.edu.cn/")));
}

fn local_challenge_page(id: &str, kind: &str) -> HttpResponse {
    HttpResponse::new(
        200,
        LOGIN_URL,
        FORM_PAGE.replace(
            "</form>",
            &format!("<script>config.captcha = {{ type: '{kind}', id: '{id}' }};</script></form>"),
        ),
    )
}

#[tokio::test]
async fn login_challenge_unknown_type_cannot_submit_and_old_id_cannot_refresh() {
    let (service, transport) = build_service(
        vec![local_challenge_page("cap", "slider")],
        MemoryVault::default(),
    );
    service
        .sign_in("synthetic", "password", None, false)
        .await
        .unwrap();
    let challenge = service.login_challenge(Some("cap"), false).await.unwrap();
    assert!(!challenge.text_supported);
    assert!(challenge.image.is_empty());
    assert!(service.login_challenge(Some("wrong"), true).await.is_err());
    assert!(matches!(
        service
            .sign_in("synthetic", "password", Some("1234"), false)
            .await
            .unwrap(),
        SessionOutcome::CaptchaRequired(_)
    ));
    service.set_route(RoutePreference::WebVpn);
    assert!(service.login_challenge(Some("cap"), false).await.is_err());
    assert_eq!(transport.request_count(), 1);
}

#[tokio::test]
async fn login_challenge_cross_account_answer_never_posts() {
    let (service, transport) = build_service(
        vec![local_challenge_page("cap", "local")],
        MemoryVault::default(),
    );
    service
        .sign_in("synthetic-a", "password", None, false)
        .await
        .unwrap();
    assert!(service
        .sign_in("synthetic-b", "password", Some("1234"), false)
        .await
        .is_err());
    assert_eq!(transport.request_count(), 1);
    assert!(!service.status().signed_in());
}

#[tokio::test]
async fn login_challenge_refresh_replaces_pending_and_old_answer_image_is_rejected() {
    let (service, transport) = build_service(
        vec![
            local_challenge_page("cap-1", "slider"),
            local_challenge_page("cap-2", "slider"),
        ],
        MemoryVault::default(),
    );
    service
        .sign_in("synthetic", "password", None, false)
        .await
        .unwrap();
    assert!(service.login_challenge(None, true).await.is_err());
    let next = service.login_challenge(Some("cap-1"), true).await.unwrap();
    assert_eq!(next.challenge_id, "cap-2");
    assert!(service.login_challenge(Some("cap-1"), false).await.is_err());
    assert_eq!(transport.request_count(), 2);
    assert!(transport
        .requests()
        .iter()
        .all(|request| request.method == HttpMethod::Get));
}
