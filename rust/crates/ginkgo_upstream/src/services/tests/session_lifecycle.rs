//! One real SchoolClient lifecycle over strict, entirely local transcripts.
//! This composes login, three nonempty module reads, cookie persistence and
//! cold restoration; it does not claim to execute Flutter or Android networking.
use super::session_protocol::{library_request, login_steps, status_request, wire};
use super::*;
use crate::{
    adapters::{checkin_http as checkin, library_http as library, schedule_http as schedule},
    auth::session::{RouteMode, Session},
    foundation::{http::HttpTransport, webvpn},
    test_support::TranscriptTransport,
};

type Step = (HttpRequest, Result<HttpResponse, TransportError>);
const DAY: &str = "2026-10-20";
const AJAX: &str = "application/json, text/javascript, */*; q=0.01, application/json";
const HOME: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/index.html";

#[derive(Clone)]
struct LifecycleTransport([TranscriptTransport; 4]);

fn partition(request: &HttpRequest) -> usize {
    let original = webvpn::unwrap(&request.url);
    if original.contains("byxt.buaa.edu.cn") {
        1
    } else if original.contains("iclass.buaa.edu.cn") {
        2
    } else if original.contains("booking.lib.buaa.edu.cn") {
        3
    } else {
        0
    }
}

impl LifecycleTransport {
    fn new(steps: Vec<Step>) -> Self {
        let mut groups: [Vec<Step>; 4] = std::array::from_fn(|_| Vec::new());
        for step in steps {
            groups[partition(&step.0)].push(step);
        }
        Self(groups.map(TranscriptTransport::new))
    }

    fn assert_finished(&self) {
        for transport in &self.0 {
            transport.assert_finished();
        }
    }

    fn requests(&self) -> Vec<HttpRequest> {
        self.0
            .iter()
            .flat_map(TranscriptTransport::requests)
            .collect()
    }
}

impl HttpTransport for LifecycleTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        // Modules may interleave. Each school's request sequence, headers,
        // cookies and bodies must still match before it receives a response.
        self.0[partition(&request)].send(request).await
    }
}

fn cookie(route: RouteMode, rotated: bool, module: Option<&str>) -> Option<String> {
    let uc = if rotated { "rotated" } else { "synthetic" };
    let base = (route == RouteMode::WebVpn)
        .then(|| format!("wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; UC={uc}"));
    match (base, module) {
        // UBAA preserves insertion order; newly issued module cookies come last.
        (Some(base), Some(module)) => Some(format!("{base}; {module}")),
        (base, None) => base,
        (None, Some(module)) => Some(module.into()),
    }
}

fn existing_module_cookie(route: RouteMode, module: &str) -> Option<String> {
    if route == RouteMode::WebVpn {
        // The previous module read issued this cookie before rotating UC.
        Some(format!(
            "wengine_vpn_ticket=synthetic; CASTGC=TGT-synthetic; {module}; UC=rotated"
        ))
    } else {
        Some(module.into())
    }
}

fn attach(mut request: HttpRequest, cookie: Option<String>) -> HttpRequest {
    if let Some(cookie) = cookie {
        request = request.header("Cookie", &cookie);
    }
    request
}

fn module_cookie(route: RouteMode, origin: &str, path: &str, name: &str) -> String {
    let routed = url::Url::parse(&wire(&format!("{origin}{path}"), route)).unwrap();
    format!("{name}; Path={}; Secure", routed.path())
}

fn reads(route: RouteMode, restored: bool) -> Vec<Step> {
    let library_day =
        crate::foundation::school_time::beijing_day(&super::super::cache::now_shanghai())
            .unwrap()
            .local_date;
    let request = |url: &str| {
        HttpRequest::get(wire(url, route))
            .header("Accept", AJAX)
            .header("X-Requested-With", "XMLHttpRequest")
            .header("Referer", &wire(HOME, route))
    };
    let ug_cookie = cookie(route, restored, Some("BYXT=synthetic"));
    let mut steps = vec![
        (
            attach(
                HttpRequest::get(wire(schedule::PORTAL_URL, route))
                    .header("Accept", "application/json"),
                if restored {
                    existing_module_cookie(route, "BYXT=synthetic")
                } else {
                    cookie(route, false, None)
                },
            ),
            Ok(
                HttpResponse::new(200, wire(schedule::PORTAL_URL, route), r#"{"user":"ok"}"#)
                    .with_set_cookie(module_cookie(
                        route,
                        "https://byxt.buaa.edu.cn",
                        "/jwapp/",
                        "BYXT=synthetic",
                    )),
            ),
        ),
        (
            attach(request(schedule::TERMS_URL), ug_cookie.clone()),
            Ok(HttpResponse::new(
                200,
                wire(schedule::TERMS_URL, route),
                schedule_body("terms-normal-v1.json"),
            )),
        ),
        (
            attach(
                request(&format!("{}?termCode=2026-2027-1", schedule::WEEKS_URL)),
                ug_cookie.clone(),
            ),
            Ok(HttpResponse::new(
                200,
                wire(schedule::WEEKS_URL, route),
                schedule_body("weeks-normal-v1.json"),
            )),
        ),
        (
            attach(
                HttpRequest::post_form(
                    wire(schedule::COURSES_URL, route),
                    "termCode=2026-2027-1&type=week&week=3",
                )
                .header("Accept", AJAX)
                .header("X-Requested-With", "XMLHttpRequest")
                .header("Referer", &wire(HOME, route)),
                ug_cookie.clone(),
            ),
            Ok(HttpResponse::new(
                200,
                wire(schedule::COURSES_URL, route),
                schedule_body("courses-normal-v1.json"),
            )),
        ),
        (
            attach(
                HttpRequest::get(wire(
                    &format!("{}?termCode=2026-2027-1", schedule::EXAMS_URL),
                    route,
                ))
                .header("Accept", AJAX)
                .header("X-Requested-With", "XMLHttpRequest")
                .header(
                    "Referer",
                    &wire(
                        "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/home/index.html",
                        route,
                    ),
                ),
                ug_cookie,
            ),
            Ok(HttpResponse::new(
                200,
                wire(schedule::EXAMS_URL, route),
                schedule_body("exams-normal-v1.json"),
            )),
        ),
    ];
    let app_cookie = cookie(route, restored, Some("ICLASS=synthetic"));
    let app_url = format!(
        "{}?password=&phone=fixture-login&userLevel=1&verificationType=2&verificationUrl=",
        checkin::APP_LOGIN_URL
    );
    steps.extend([
        (
            attach(HttpRequest::get(wire(checkin::ENTRY_URL, route)).header("Accept", "application/json"), cookie(route, restored, None)),
            Ok(HttpResponse::new(302, wire(checkin::ENTRY_URL, route), "").with_header("Location", "/?loginName=fixture-login")),
        ),
        (
            attach(HttpRequest::get(wire(&app_url, route)).header("Accept", "application/json"), if restored { existing_module_cookie(route, "ICLASS=synthetic") } else { cookie(route, false, None) }),
            Ok(HttpResponse::new(200, wire(checkin::APP_LOGIN_URL, route), r#"{"STATUS":0,"result":{"id":"user-1","sessionId":"session-1"}}"#)
                .with_set_cookie(module_cookie(route, "https://iclass.buaa.edu.cn:8347", "/app/", "ICLASS=synthetic"))),
        ),
        (
            attach(HttpRequest::get(wire(&format!("{}?id=user-1&dateStr=20261020", checkin::COURSE_SCHEDULE_URL), route)).header("Accept", "application/json").header("sessionId", "session-1"), app_cookie),
            Ok(HttpResponse::new(200, wire(checkin::COURSE_SCHEDULE_URL, route), r#"{"STATUS":0,"result":[{"id":"course-1","courseName":"软件工程","classBeginTime":"08:00","classEndTime":"09:40","signStatus":0}]}"#)),
        ),
        (
            attach(library_request(library::LOGIN_START, route, None, None), if route == RouteMode::Direct { Some("CASTGC=TGT-synthetic".into()) } else { cookie(route, restored, None) }),
            Ok(HttpResponse::new(302, wire(library::LOGIN_START, route), "").with_header("Location", "https://booking.lib.buaa.edu.cn/v4/login/cas?cas=cas-1")),
        ),
        (
            attach(library_request(library::LOGIN_USER, route, None, Some(r#"{"cas":"cas-1"}"#)), if restored { existing_module_cookie(route, "LIB=synthetic") } else { cookie(route, false, None) }),
            Ok(HttpResponse::new(200, wire(library::LOGIN_USER, route), r#"{"code":0,"data":{"member":{"token":"jwt-1","name":"示例用户"}}}"#)
                .with_set_cookie(module_cookie(route, "https://booking.lib.buaa.edu.cn", "/v4/", "LIB=synthetic"))),
        ),
        (
            attach(library_request("https://booking.lib.buaa.edu.cn/v4/space/pcTopFor", route, Some("jwt-1"), Some(&format!(r#"{{"day":"{library_day}"}}"#))), cookie(route, restored, Some("LIB=synthetic"))),
            Ok(HttpResponse::new(200, wire("https://booking.lib.buaa.edu.cn/v4/space/pcTopFor", route), r#"{"code":1,"data":{"list":[{"id":"9","name":"示例图书馆","free_num":12,"total_num":100,"children":[]}]}}"#)),
        ),
        (
            status_request(route, Some(&if route == RouteMode::WebVpn { cookie(route, restored, None).unwrap() } else if restored { "UC=rotated".into() } else { "UC=synthetic".into() })),
            Ok(uc_ok("sy2501001", "fixture").with_set_cookie("UC=rotated; Path=/; Secure")),
        ),
    ]);
    steps
}

async fn read_modules(
    service: &SchoolClient<LifecycleTransport, MemoryVault>,
    route: RouteMode,
    failure: Option<(&str, ErrorCode)>,
) {
    let input = ScheduleQueryInput {
        term_id: Some("2026-2027-1".into()),
        week: Some(3),
        force_refresh: true,
    };
    let (schedule, checkin, library) = tokio::join!(
        service.load_schedule(&input),
        service.load_checkin_on_date(Some(DAY.into()), true),
        service.load_library_venues(true),
    );
    let schedule = schedule.unwrap();
    assert_eq!(schedule.data.courses.len(), 2);
    assert_eq!(schedule.data.exams.len(), 2);
    assert!(schedule.failure.is_none());
    if let Some(("checkin", code)) = &failure {
        assert_eq!(checkin.unwrap_err().code, *code);
    } else {
        let checkin = checkin.unwrap();
        assert_eq!(checkin.courses.len(), 1);
        assert_eq!(checkin.courses[0].course_name, "软件工程");
        assert!(checkin.failure.is_none());
    }
    if let Some(("library", code)) = &failure {
        assert_eq!(library.unwrap_err().code, *code);
    } else {
        let library = library.unwrap();
        assert_eq!(library.venues.len(), 1);
        assert!(library.failure.is_none());
    }
    assert_eq!(
        crate::auth::validate_session(&service.session)
            .await
            .unwrap()
            .school_id,
        "sy2501001"
    );
    assert!(service.status().signed_in());
    assert_eq!(service.session.route(), route);
}

#[tokio::test]
async fn session_protocol_login_modules_and_cold_restore_keep_one_school_identity() {
    for (route, preference) in [
        (RouteMode::Direct, RoutePreference::Direct),
        (RouteMode::Direct, RoutePreference::Automatic),
        (RouteMode::WebVpn, RoutePreference::WebVpn),
        (RouteMode::WebVpn, RoutePreference::Automatic),
    ] {
        for remember in [false, true] {
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
            steps.extend(reads(route, false));
            let transport = LifecycleTransport::new(steps);
            let vault = MemoryVault::default();
            let service = SchoolClient::new(Session::new(transport.clone()), vault.clone());
            service.apply_route_change(preference).await.unwrap();
            assert!(matches!(
                service
                    .sign_in("sy2501001", "pa+ss/word", None, remember)
                    .await
                    .unwrap(),
                SessionOutcome::SignedIn { .. }
            ));
            let started = vault.load_session().unwrap().unwrap().saved_at_ms;
            read_modules(&service, route, None).await;
            let record = vault.load_session().unwrap().unwrap();
            assert_eq!(record.route, route);
            assert_eq!(record.saved_at_ms, started);
            transport.assert_finished();
            assert_eq!(
                transport
                    .requests()
                    .iter()
                    .filter(|request| request.method == HttpMethod::Post
                        && request.url == wire(LOGIN_URL, route))
                    .count(),
                1
            );
            drop(service);

            let mut steps = vec![(
                status_request(
                    route,
                    Some(&if route == RouteMode::WebVpn {
                        cookie(route, true, None).unwrap()
                    } else {
                        "UC=rotated".into()
                    }),
                ),
                Ok(uc_ok("sy2501001", "fixture")),
            )];
            steps.extend(reads(route, true));
            let transport = LifecycleTransport::new(steps);
            let restored = SchoolClient::new(Session::new(transport.clone()), vault.clone());
            // Same startup sequence as SessionGate: set preference, then restore.
            restored.apply_route_change(preference).await.unwrap();
            assert!(
                matches!(restored.restore().await.unwrap(), SessionOutcome::SignedIn { remembered, .. } if remembered == remember)
            );
            assert!(restored.session_credentials().is_none());
            read_modules(&restored, route, None).await;
            assert_eq!(vault.load_session().unwrap().unwrap().saved_at_ms, started);
            assert_eq!(vault.load_session().unwrap().unwrap().route, route);
            assert!(transport
                .requests()
                .iter()
                .all(|request| request.url != wire(LOGIN_URL, route)));
            transport.assert_finished();
        }
    }
}

#[tokio::test]
async fn session_protocol_one_module_failure_does_not_expire_other_modules() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        for module in ["checkin", "library"] {
            for unavailable in [false, true] {
                let mut steps = login_steps(route, uc_ok("sy2501001", "fixture"));
                let mut business = reads(route, false);
                let target = if module == "checkin" {
                    "/app/course/get_stu_course_sched.action"
                } else {
                    "/v4/space/pcTopFor"
                };
                let (request, response) = business
                    .iter_mut()
                    .find(|(request, _)| {
                        url::Url::parse(&webvpn::unwrap(&request.url))
                            .unwrap()
                            .path()
                            == target
                    })
                    .unwrap();
                *response = if unavailable {
                    Ok(HttpResponse::new(503, &request.url, "temporary"))
                } else {
                    Err(TransportError::Unreachable)
                };
                steps.extend(business);
                let transport = LifecycleTransport::new(steps);
                let vault = MemoryVault::default();
                let service = SchoolClient::new(Session::new(transport.clone()), vault.clone());
                service.set_route(if route == RouteMode::Direct {
                    RoutePreference::Direct
                } else {
                    RoutePreference::WebVpn
                });
                service
                    .sign_in("sy2501001", "pa+ss/word", None, false)
                    .await
                    .unwrap();
                let code = if unavailable {
                    ErrorCode::ServiceUnavailable
                } else {
                    ErrorCode::NetworkUnreachable
                };
                read_modules(&service, route, Some((module, code))).await;
                assert_eq!(vault.load_session().unwrap().unwrap().route, route);
                assert_eq!(
                    transport
                        .requests()
                        .iter()
                        .filter(|request| request.method == HttpMethod::Post
                            && request.url == wire(LOGIN_URL, route))
                        .count(),
                    1
                );
                transport.assert_finished();
            }
        }
    }
}
