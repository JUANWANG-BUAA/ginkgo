//! Synthetic wire transcripts, independently anchored to API §1 and the
//! pinned UBAA parser vectors. No real transport or account is constructed.
use super::*;
use crate::{
    auth::session::{RouteMode, Session},
    foundation::webvpn,
    test_support::TranscriptTransport,
};

const ACCEPT: &str = "application/json, text/javascript, */*; q=0.01";
const CALLBACK: &str = "https://uc.buaa.edu.cn/api/callback?ticket=ST-synthetic";
const HOME: &str = "https://uc.buaa.edu.cn/home";
const FORM: &str = "execution=abc%2Bdef%2Fghi%3D&username=sy2501001&password=pa%2Bss%2Fword&submit=%E7%99%BB%E5%BD%95&_eventId=submit&type=username_password";

pub(super) fn wire(url: &str, route: RouteMode) -> String {
    if route == RouteMode::WebVpn {
        webvpn::wrap(url).unwrap()
    } else {
        url.into()
    }
}

pub(super) fn status_request(route: RouteMode, cookie: Option<&str>) -> HttpRequest {
    with_cookie(
        HttpRequest::get(wire(UC_STATUS_URL, route))
            .header(
                "Accept",
                "application/json, text/javascript, */*; q=0.01, application/json",
            )
            .header("X-Requested-With", "XMLHttpRequest"),
        cookie,
    )
}

fn with_cookie(request: HttpRequest, cookie: Option<&str>) -> HttpRequest {
    match cookie {
        Some(cookie) => request.header("Cookie", cookie),
        None => request,
    }
}

// These transcripts encode the pinned Kotlin branches directly. They are
// source-derived expectations, not a new independently captured Kotlin run.
#[tokio::test]
async fn session_protocol_ubaa_initial_redirect_goes_straight_to_uc_even_without_location() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        for location in [
            None,
            Some("/login"),
            Some("https://uc.buaa.edu.cn/error?exception.message=unused"),
        ] {
            let response = HttpResponse::new(302, wire(LOGIN_URL, route), "")
                .with_set_cookie("CASTGC=synthetic; Path=/; Secure");
            let response = match location {
                Some(location) => response.with_header("Location", location),
                None => response,
            };
            let cookie = (route == RouteMode::WebVpn).then_some("CASTGC=synthetic");
            let transport = TranscriptTransport::new(vec![
                (
                    HttpRequest::get(wire(LOGIN_URL, route)).header("Accept", "application/json"),
                    Ok(response),
                ),
                (
                    with_cookie(
                        HttpRequest::get(wire(UC_ACTIVATION_URL, route))
                            .header("Accept", "application/json"),
                        cookie,
                    ),
                    Ok(HttpResponse::new(
                        200,
                        wire(UC_ACTIVATION_URL, route),
                        "landing",
                    )),
                ),
                (
                    status_request(route, cookie),
                    Ok(uc_ok("sy2501001", "fixture")),
                ),
            ]);
            let service =
                SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
            service.set_route(if route == RouteMode::WebVpn {
                RoutePreference::WebVpn
            } else {
                RoutePreference::Direct
            });
            assert!(matches!(
                service
                    .sign_in("sy2501001", "pa+ss/word", None, false)
                    .await
                    .unwrap(),
                SessionOutcome::SignedIn { .. }
            ));
            transport.assert_finished();
        }
    }
}

#[tokio::test]
async fn session_protocol_ubaa_cas_terminal_status_does_not_preempt_uc_identity() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        for status in [200, 204, 302, 403, 404, 483, 500, 503] {
            for valid in [false, true] {
                let cookie = (route == RouteMode::WebVpn).then_some("CASTGC=synthetic");
                let identity = if valid {
                    uc_ok("sy2501001", "fixture")
                } else {
                    uc_expired()
                };
                let transport = TranscriptTransport::new(vec![
                    (
                        HttpRequest::get(wire(LOGIN_URL, route))
                            .header("Accept", "application/json"),
                        Ok(HttpResponse::new(200, wire(LOGIN_URL, route), FORM_PAGE)),
                    ),
                    (
                        HttpRequest::post_form(wire(LOGIN_URL, route), FORM)
                            .header("Accept", "application/json")
                            .header(
                                "Content-Type",
                                "application/x-www-form-urlencoded; charset=UTF-8",
                            ),
                        Ok(HttpResponse::new(status, wire(LOGIN_URL, route), "landing")
                            .with_set_cookie("CASTGC=synthetic; Path=/; Secure")),
                    ),
                    (
                        with_cookie(
                            HttpRequest::get(wire(UC_ACTIVATION_URL, route))
                                .header("Accept", "application/json"),
                            cookie,
                        ),
                        Ok(HttpResponse::new(
                            200,
                            wire(UC_ACTIVATION_URL, route),
                            "activated",
                        )),
                    ),
                    (status_request(route, cookie), Ok(identity)),
                ]);
                let service =
                    SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
                service.set_route(if route == RouteMode::WebVpn {
                    RoutePreference::WebVpn
                } else {
                    RoutePreference::Direct
                });
                let result = service
                    .sign_in("sy2501001", "pa+ss/word", None, false)
                    .await;
                if valid {
                    assert!(matches!(result.unwrap(), SessionOutcome::SignedIn { .. }));
                } else {
                    assert_eq!(result.unwrap_err().code, ErrorCode::SessionExpired);
                    assert!(!service.status().signed_in());
                }
                transport.assert_finished();
            }
        }
    }
}

type Step = (HttpRequest, Result<HttpResponse, TransportError>);

pub(super) fn login_steps(route: RouteMode, status: HttpResponse) -> Vec<Step> {
    let cookie = if route == RouteMode::WebVpn {
        Some("wengine_vpn_ticket=synthetic; UC=synthetic")
    } else {
        Some("UC=synthetic")
    };
    let cas_cookie = if route == RouteMode::WebVpn {
        Some("wengine_vpn_ticket=synthetic")
    } else {
        None
    };
    let first = HttpResponse::new(200, wire(LOGIN_URL, route), FORM_PAGE);
    let first = if route == RouteMode::WebVpn {
        first.with_set_cookie("wengine_vpn_ticket=synthetic; Path=/; Secure")
    } else {
        first
    };
    vec![
        (
            HttpRequest::get(wire(LOGIN_URL, route)).header("Accept", "application/json"),
            Ok(first),
        ),
        (
            with_cookie(
                HttpRequest::post_form(wire(LOGIN_URL, route), FORM)
                    .header("Accept", "application/json")
                    .header(
                        "Content-Type",
                        "application/x-www-form-urlencoded; charset=UTF-8",
                    ),
                cas_cookie,
            ),
            Ok(HttpResponse::new(302, wire(LOGIN_URL, route), "")
                .with_header("Location", &wire(CALLBACK, route))
                .with_set_cookie("CASTGC=TGT-synthetic; Path=/; Secure")),
        ),
        // A different host must consume ST before UC activation can run.
        (
            with_cookie(
                HttpRequest::get(wire(CALLBACK, route)).header("Accept", "application/json"),
                if route == RouteMode::WebVpn {
                    Some("wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic")
                } else {
                    None
                },
            ),
            Ok(HttpResponse::new(302, wire(CALLBACK, route), "")
                .with_header("Location", "/home")
                .with_set_cookie("UC=synthetic; Path=/; Secure")),
        ),
        (
            with_cookie(
                HttpRequest::get(wire(HOME, route)).header("Accept", "application/json"),
                if route == RouteMode::WebVpn {
                    Some("wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; UC=synthetic")
                } else {
                    cookie
                },
            ),
            Ok(HttpResponse::new(200, wire(HOME, route), "service")),
        ),
        (
            with_cookie(
                HttpRequest::get(wire(UC_ACTIVATION_URL, route))
                    .header("Accept", "application/json"),
                if route == RouteMode::WebVpn {
                    Some("wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; UC=synthetic")
                } else {
                    cookie
                },
            ),
            Ok(HttpResponse::new(
                200,
                wire(UC_ACTIVATION_URL, route),
                "activated",
            )),
        ),
        (
            status_request(
                route,
                if route == RouteMode::WebVpn {
                    Some("wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; UC=synthetic")
                } else {
                    cookie
                },
            ),
            Ok(status),
        ),
    ]
}

#[tokio::test]
async fn session_protocol_consumes_service_ticket_and_persists_actual_route() {
    for (route, preference) in [
        (RouteMode::Direct, RoutePreference::Automatic),
        (RouteMode::WebVpn, RoutePreference::WebVpn),
        (RouteMode::WebVpn, RoutePreference::Automatic),
    ] {
        let mut steps = login_steps(route, uc_ok("sy2501001", "fixture"));
        if route == RouteMode::WebVpn && preference == RoutePreference::Automatic {
            steps.insert(
                0,
                (
                    HttpRequest::get(LOGIN_URL).header("Accept", "application/json"),
                    Err(TransportError::Unreachable),
                ),
            );
        }
        let transport = TranscriptTransport::new(steps);
        let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
        // Automatic remains a preference; WebVPN here models a selected route.
        service.set_route(preference);
        assert!(matches!(
            service
                .sign_in("sy2501001", "pa+ss/word", None, false)
                .await
                .unwrap(),
            SessionOutcome::SignedIn { .. }
        ));
        let record = service.vault.load_session().unwrap().unwrap();
        assert_eq!(record.route, route);
        assert_eq!(record.schema_version, 2);
        assert_eq!(service.session.route(), route);
        assert!(service.vault.load("sy2501001").unwrap().is_none());
        transport.assert_finished();

        // A fresh process restores the authenticated mode before its only GET.
        let restore_transport = TranscriptTransport::new(vec![(
            status_request(
                route,
                if route == RouteMode::WebVpn {
                    Some("wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; UC=synthetic")
                } else {
                    Some("UC=synthetic")
                },
            ),
            Ok(uc_ok("sy2501001", "fixture")),
        )]);
        let restored = SchoolClient::new(
            Session::new(restore_transport.clone()),
            MemoryVault::default(),
        );
        restored.vault.save_session(&record).unwrap();
        assert!(matches!(
            restored.restore().await.unwrap(),
            SessionOutcome::SignedIn { .. }
        ));
        assert_eq!(restored.session.route(), route);
        restore_transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_never_fabricates_identity_when_uc_fails_after_cas() {
    for status in [
        HttpResponse::new(503, UC_STATUS_URL, "temporary"),
        uc_expired(),
        HttpResponse::new(200, UC_STATUS_URL, "unexpected html"),
    ] {
        let transport = TranscriptTransport::new(login_steps(RouteMode::Direct, status));
        let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
        assert!(service
            .sign_in("sy2501001", "pa+ss/word", None, false)
            .await
            .is_err());
        assert!(!service.status().signed_in());
        assert!(service.vault.load_session().unwrap().is_none());
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.method == HttpMethod::Post)
                .count(),
            1
        );
        transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_valid_cookies_do_not_depend_on_optional_password_storage() {
    struct PasswordReadFailure {
        record: Option<PersistedSession>,
    }
    impl CredentialSource for PasswordReadFailure {
        fn load(&self, _: &str) -> Result<Option<Credentials>, crate::AppError> {
            Err(crate::AppError::credential_store())
        }
    }
    impl CredentialVault for PasswordReadFailure {
        fn save(&self, _: &str, _: &Credentials) -> Result<(), crate::AppError> {
            panic!("a verified cookie session must not save a password")
        }
        fn delete(&self, _: &str) -> Result<(), crate::AppError> {
            panic!("a password read failure must not delete a credential")
        }
        fn accounts(&self) -> Result<Vec<String>, crate::AppError> {
            panic!("a verified cookie session must not enumerate saved accounts")
        }
        fn load_session(&self) -> Result<Option<PersistedSession>, crate::AppError> {
            Ok(self.record.clone())
        }
    }
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        let login_transport =
            TranscriptTransport::new(login_steps(route, uc_ok("sy2501001", "fixture")));
        let signed_in = SchoolClient::new(
            Session::new(login_transport.clone()),
            MemoryVault::default(),
        );
        signed_in.set_route(if route == RouteMode::Direct {
            RoutePreference::Direct
        } else {
            RoutePreference::WebVpn
        });
        signed_in
            .sign_in("sy2501001", "pa+ss/word", None, false)
            .await
            .unwrap();
        login_transport.assert_finished();
        let record = signed_in.vault.load_session().unwrap().unwrap();
        let cookie = if route == RouteMode::WebVpn {
            "wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; UC=synthetic"
        } else {
            "UC=synthetic"
        };
        for (cold, unavailable) in [(true, false), (false, false), (false, true)] {
            let response = if unavailable {
                HttpResponse::new(503, UC_STATUS_URL, "temporary")
            } else {
                uc_ok("sy2501001", "fixture")
            };
            let transport =
                TranscriptTransport::new(vec![(status_request(route, Some(cookie)), Ok(response))]);
            let restored = SchoolClient::new(
                Session::new(transport.clone()),
                PasswordReadFailure {
                    record: cold.then(|| record.clone()),
                },
            );
            if !cold {
                restored.session.set_route(route);
                restored.session.restore_cookies(record.cookies.clone());
                restored.set_authenticated(
                    record.account.clone(),
                    UserProfile {
                        school_id: record.account.clone(),
                        name: record.profile_name.clone(),
                    },
                );
            }
            let outcome = restored.restore().await;
            assert!(
                matches!(
                    outcome,
                    Ok(SessionOutcome::SignedIn {
                        remembered: false,
                        ..
                    })
                ),
                "route={route:?} cold={cold} unavailable={unavailable}: {outcome:?}"
            );
            assert!(restored.status().signed_in());
            assert_eq!(restored.session.route(), route);
            transport.assert_finished();
        }
    }
}

#[tokio::test]
async fn session_protocol_module_failure_rechecks_uc_without_password_or_logout() {
    for (response, code) in [
        (uc_ok("sy2501001", "fixture"), ErrorCode::ModuleAuthRequired),
        (
            HttpResponse::new(503, UC_STATUS_URL, "temporary"),
            ErrorCode::ServiceUnavailable,
        ),
        (
            HttpResponse::new(200, UC_STATUS_URL, "drift"),
            ErrorCode::ChangedResponse,
        ),
        (
            HttpResponse::new(200, UC_STATUS_URL, r#"{"code":99999,"data":null}"#),
            ErrorCode::ChangedResponse,
        ),
        (
            HttpResponse::new(200, UC_STATUS_URL, r#"{"code":0,"data":null}"#),
            ErrorCode::ChangedResponse,
        ),
        (
            HttpResponse::new(200, UC_STATUS_URL, r#"{"code":10600}"#),
            ErrorCode::ChangedResponse,
        ),
        (
            HttpResponse::new(
                200,
                UC_STATUS_URL,
                r#"{"code":0,"data":{"schoolid":"sy2501001","name":""}}"#,
            ),
            ErrorCode::ChangedResponse,
        ),
    ] {
        let transport = TranscriptTransport::new(vec![(
            status_request(RouteMode::Direct, None),
            Ok(response),
        )]);
        let service = SchoolClient::new(Session::new(transport.clone()), seeded("sy2501001"));
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "fixture".into(),
            },
        );
        assert_eq!(service.silent_login().await.unwrap_err().code, code);
        assert!(service.status().signed_in());
        assert_eq!(service.session.route(), RouteMode::Direct);
        // Repeated modules share the failure cooldown, with no extra UC/POST.
        assert!(service.silent_login().await.is_err());
        transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_business_network_failure_preserves_cookie_route_and_identity() {
    let mut steps = login_steps(RouteMode::Direct, uc_ok("sy2501001", "fixture"));
    let business = "https://iclass.buaa.edu.cn:8346/app/course/get_stu_course_sign_info.action";
    steps.push((HttpRequest::get(business), Err(TransportError::Unreachable)));
    // Check that an unrelated UC read still uses the original cookie jar.
    steps.push((
        status_request(RouteMode::Direct, Some("UC=synthetic")),
        Ok(uc_ok("sy2501001", "fixture")),
    ));
    let transport = TranscriptTransport::new(steps);
    let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    service.set_route(RoutePreference::Direct);
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .unwrap();
    assert_eq!(
        service
            .session
            .send_with_fallback(HttpRequest::get(business))
            .await
            .unwrap_err()
            .code,
        ErrorCode::NetworkUnreachable
    );
    assert_eq!(service.session.route(), RouteMode::Direct);
    assert!(service.status().signed_in());
    assert_eq!(
        crate::auth::validate_session(&service.session)
            .await
            .unwrap()
            .school_id,
        "sy2501001"
    );
    transport.assert_finished();
}

#[tokio::test]
async fn session_protocol_captcha_refetches_like_ubaa_and_posts_original_execution_once() {
    let route = RouteMode::WebVpn;
    let captcha_page = FORM_PAGE.to_owned()
        + "<script>config.captcha = { type: 'char', id: 'cap-synthetic' };</script>";
    let body = "username=sy2501001&password=pa%2Bss%2Fword&captcha=a%2Bb%2F%E4%B8%AD&captchaResponse=a%2Bb%2F%E4%B8%AD&execution=abc%2Bdef%2Fghi%3D&_eventId=submit&submit=%E7%99%BB%E5%BD%95&type=username_password";
    let transport = TranscriptTransport::new(vec![
        (
            HttpRequest::get(LOGIN_URL).header("Accept", "application/json"),
            Err(TransportError::Unreachable),
        ),
        (
            HttpRequest::get(wire(LOGIN_URL, route)).header("Accept", "application/json"),
            Ok(
                HttpResponse::new(200, wire(LOGIN_URL, route), &captcha_page)
                    .with_set_cookie("wengine_vpn_ticket=synthetic; Path=/; Secure"),
            ),
        ),
        (
            HttpRequest::get(wire(LOGIN_URL, route))
                .header("Accept", "application/json")
                .header("Cookie", "wengine_vpn_ticket=synthetic"),
            Ok(HttpResponse::new(
                200,
                wire(LOGIN_URL, route),
                captcha_page.replace("abc+def/ghi=", "new-execution"),
            )
            .with_set_cookie("renewed=synthetic; Path=/; Secure")),
        ),
        (
            HttpRequest::post_form(wire(LOGIN_URL, route), body)
                .header("Accept", "application/json")
                .header(
                    "Content-Type",
                    "application/x-www-form-urlencoded; charset=UTF-8",
                )
                .header("Cookie", "wengine_vpn_ticket=synthetic; renewed=synthetic"),
            Err(TransportError::Unavailable),
        ),
    ]);
    let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    assert!(matches!(
        service
            .sign_in("sy2501001", "pa+ss/word", None, false)
            .await
            .unwrap(),
        SessionOutcome::CaptchaRequired(_)
    ));
    assert!(service
        .sign_in("sy2501001", "pa+ss/word", Some("a+b/中"), false)
        .await
        .is_err());
    assert!(service
        .sign_in("sy2501001", "pa+ss/word", Some("a+b/中"), false)
        .await
        .is_err());
    assert_eq!(service.session.route(), route);
    assert!(!service.status().signed_in());
    transport.assert_finished();
}

#[tokio::test]
async fn session_protocol_ubaa_captcha_get_post_callback_and_uc_success() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        let captcha_page = FORM_PAGE.to_owned()
            + "<script>config.captcha = { type: 'char', id: 'cap-synthetic' };</script>";
        let mut steps = login_steps(route, uc_ok("sy2501001", "fixture"));
        let mut first = HttpResponse::new(200, wire(LOGIN_URL, route), captcha_page);
        let cookie = if route == RouteMode::WebVpn {
            first = first.with_set_cookie("wengine_vpn_ticket=synthetic; Path=/; Secure");
            Some("wengine_vpn_ticket=synthetic")
        } else {
            None
        };
        steps[0].1 = Ok(first);
        steps[1].0.body = Some("username=sy2501001&password=pa%2Bss%2Fword&captcha=1234&captchaResponse=1234&execution=abc%2Bdef%2Fghi%3D&_eventId=submit&submit=%E7%99%BB%E5%BD%95&type=username_password".into());
        steps.insert(
            1,
            (
                with_cookie(
                    HttpRequest::get(wire(LOGIN_URL, route)).header("Accept", "application/json"),
                    cookie,
                ),
                Ok(HttpResponse::new(
                    200,
                    wire(LOGIN_URL, route),
                    FORM_PAGE.replace("abc+def/ghi=", "new-execution"),
                )),
            ),
        );
        let transport = TranscriptTransport::new(steps);
        let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
        service.set_route(if route == RouteMode::WebVpn {
            RoutePreference::WebVpn
        } else {
            RoutePreference::Direct
        });
        assert!(matches!(
            service
                .sign_in("sy2501001", "pa+ss/word", None, false)
                .await
                .unwrap(),
            SessionOutcome::CaptchaRequired(_)
        ));
        let result = service
            .sign_in("sy2501001", "pa+ss/word", Some("1234"), false)
            .await
            .unwrap();
        let SessionOutcome::SignedIn { profile, .. } = result else {
            panic!("a complete UC identity is required");
        };
        assert_eq!(profile.school_id, "sy2501001");
        assert_eq!(service.session.route(), route);
        transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_checkin_rebuilds_module_without_school_password() {
    use crate::adapters::checkin_http::{APP_LOGIN_URL, COURSE_SCHEDULE_URL, ENTRY_URL};
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        let mut steps = Vec::new();
        for (id, result) in [
            ("old", r#"{"STATUS":9}"#),
            ("new", r#"{"STATUS":0,"result":[]}"#),
        ] {
            steps.extend([
                (HttpRequest::get(wire(ENTRY_URL, route)).header("Accept", "application/json"), Ok(HttpResponse::new(302, wire(ENTRY_URL, route), "").with_header("Location", "/?loginName=synthetic%2Bname"))),
                (HttpRequest::get(wire(&format!("{APP_LOGIN_URL}?password=&phone=synthetic%2Bname&userLevel=1&verificationType=2&verificationUrl="), route)).header("Accept", "application/json"),
                 Ok(HttpResponse::new(200, wire(APP_LOGIN_URL, route), format!(r#"{{"STATUS":0,"result":{{"id":"1001","sessionId":"{id}"}}}}"#)))),
                (HttpRequest::get(wire(&format!("{COURSE_SCHEDULE_URL}?id=1001&dateStr=20261020"), route)).header("Accept", "application/json").header("sessionId", id),
                 Ok(HttpResponse::new(200, wire(COURSE_SCHEDULE_URL, route), result))),
            ]);
        }
        let transport = TranscriptTransport::new(steps);
        let service = SchoolClient::new(Session::new(transport.clone()), seeded("sy2501001"));
        service.session.set_route(route);
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "fixture".into(),
            },
        );
        // A cold read reports the first rejection; the next explicit refresh
        // rebuilds only the iclass app session, with no CAS password POST.
        assert!(service
            .load_checkin_on_date(Some("2026-10-20".into()), true)
            .await
            .is_err());
        let result = service
            .load_checkin_on_date(Some("2026-10-20".into()), true)
            .await
            .unwrap();
        assert!(result.courses.is_empty());
        assert!(service.status().signed_in());
        assert_eq!(service.session.route(), route);
        assert!(transport
            .requests()
            .iter()
            .all(|r| r.method == HttpMethod::Get));
        transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_failed_undergraduate_probe_reaches_real_gsmis_and_remembers_source() {
    use crate::adapters::{graduate_schedule_http as grad, schedule_http as ug};
    for probe in [
        Err(TransportError::Unreachable),
        Ok(HttpResponse::new(503, ug::PORTAL_URL, "temporary")),
        Ok(HttpResponse::new(200, ug::PORTAL_URL, "unconfirmed html")),
        Ok(HttpResponse::new(200, LOGIN_URL, FORM_PAGE)),
    ] {
        let mut steps = vec![(
            HttpRequest::get(ug::PORTAL_URL).header("Accept", "application/json"),
            probe,
        )];
        for _ in 0..2 {
            steps.extend([
                (
                    HttpRequest::get(grad::ENTRY_URL),
                    Ok(HttpResponse::new(200, grad::ENTRY_URL, "app")),
                ),
                (
                    HttpRequest::post_form(grad::TERMS_URL, "")
                        .header("Accept", ACCEPT)
                        .header("X-Requested-With", "XMLHttpRequest")
                        .header("Referer", grad::ENTRY_URL),
                    Ok(HttpResponse::new(
                        200,
                        grad::TERMS_URL,
                        schedule_body("graduate-terms-v1.json"),
                    )),
                ),
                (
                    HttpRequest::post_form(grad::SCHEDULE_URL, "ZC=&XNXQDM=20261&XH=&XQDM=")
                        .header("Accept", ACCEPT)
                        .header("X-Requested-With", "XMLHttpRequest")
                        .header("Referer", grad::ENTRY_URL),
                    Ok(HttpResponse::new(
                        200,
                        grad::SCHEDULE_URL,
                        schedule_body("graduate-schedule-v1.json"),
                    )),
                ),
            ]);
        }
        let transport = TranscriptTransport::new(steps);
        let service = SchoolClient::new(Session::new(transport.clone()), seeded("sy2501001"));
        service.set_route(RoutePreference::Direct);
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "fixture".into(),
            },
        );
        for _ in 0..2 {
            let result = service
                .load_schedule(&ScheduleQueryInput {
                    term_id: None,
                    week: Some(7),
                    force_refresh: true,
                })
                .await
                .unwrap();
            assert_eq!(result.data.term_id, "20261");
            assert_eq!(result.data.courses.len(), 2);
        }
        assert!(service.status().signed_in());
        transport.assert_finished();
    }
}

pub(super) fn library_request(
    url: &str,
    route: RouteMode,
    token: Option<&str>,
    body: Option<&str>,
) -> HttpRequest {
    let request = HttpRequest::new(if body.is_some() { HttpMethod::Post } else { HttpMethod::Get }, wire(url, route))
        .header("Accept", "application/json, text/plain, */*, application/json")
        .header("X-Requested-With", "XMLHttpRequest")
        .header("Origin", &wire("https://booking.lib.buaa.edu.cn", route))
        .header("Referer", &wire("https://booking.lib.buaa.edu.cn", route))
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36");
    let mut request = match token {
        Some(token) => request.header("Authorization", &format!("bearer{token}")),
        None => request,
    };
    if let Some(body) = body {
        request = request.header("Content-Type", "application/json");
        request.body = Some(body.into());
    }
    request
}

#[tokio::test]
async fn session_protocol_library_token_rebuild_preserves_school_identity_and_headers() {
    use crate::adapters::library_http::{LOGIN_START, LOGIN_USER};
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        let day = crate::foundation::school_time::beijing_day(&super::super::cache::now_shanghai())
            .unwrap()
            .local_date;
        let venues = "https://booking.lib.buaa.edu.cn/v4/space/pcTopFor";
        let mut steps = Vec::new();
        for (token, result) in [
            (
                "old",
                r#"{"code":0,"message":"登录失效，请重新登录"}"#.to_string(),
            ),
            ("new", library_body("space/pcTopFor").body),
        ] {
            steps.extend([
                (
                    library_request(LOGIN_START, route, None, None),
                    Ok(
                        HttpResponse::new(302, wire(LOGIN_START, route), "").with_header(
                            "Location",
                            "https://booking.lib.buaa.edu.cn/#cas=synthetic%2Bcas",
                        ),
                    ),
                ),
                (
                    library_request(LOGIN_USER, route, None, Some(r#"{"cas":"synthetic+cas"}"#)),
                    Ok(HttpResponse::new(
                        200,
                        wire(LOGIN_USER, route),
                        format!(r#"{{"code":0,"data":{{"member":{{"token":"{token}"}}}}}}"#),
                    )),
                ),
                (
                    library_request(
                        venues,
                        route,
                        Some(token),
                        Some(&format!(r#"{{"day":"{day}"}}"#)),
                    ),
                    Ok(HttpResponse::new(200, wire(venues, route), result)),
                ),
            ]);
        }
        let transport = TranscriptTransport::new(steps);
        let service = SchoolClient::new(Session::new(transport.clone()), seeded("sy2501001"));
        service.session.set_route(route);
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "fixture".into(),
            },
        );
        assert_eq!(
            service
                .load_library_venues(true)
                .await
                .unwrap()
                .venues
                .len(),
            2
        );
        assert!(service.status().signed_in());
        assert_eq!(service.session.route(), route);
        assert!(transport
            .requests()
            .iter()
            .all(|r| !r.url.starts_with(LOGIN_URL) || r.method == HttpMethod::Get));
        transport.assert_finished();
    }
}
