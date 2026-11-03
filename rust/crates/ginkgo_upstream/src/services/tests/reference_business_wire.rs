//! Golden requests captured by executing pinned UBAA, independent of Rust expectations.
use super::*;
use crate::foundation::{http::HttpTransport, webvpn};
use std::sync::{Arc, Mutex};

#[derive(Clone)]
struct WireProbe {
    responses: Value,
    operation: String,
    requests: Arc<Mutex<Vec<Value>>>,
}

impl HttpTransport for WireProbe {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        let original = webvpn::unwrap(&request.url);
        let parsed = url::Url::parse(&original).unwrap();
        self.requests.lock().unwrap().push(serde_json::json!({
            "method": match request.method { HttpMethod::Get => "GET", HttpMethod::Post => "POST" },
            "url": request.url,
            "headers": request.headers.iter().map(|(k, v)| (k.to_ascii_lowercase(), v.clone())).collect::<std::collections::BTreeMap<_, _>>(),
            "body": request.body.as_deref().unwrap_or("")
        }));
        let response = self.responses["responses"]
            .as_array()
            .unwrap()
            .iter()
            .find(|response| response["path"].as_str() == Some(parsed.path()))
            .unwrap_or_else(|| panic!("unknown synthetic request: {}", parsed.path()));
        let mut reply = HttpResponse::new(
            response["status"].as_u64().unwrap() as u16,
            &request.url,
            if self.operation == "checkin-nonempty"
                && parsed.path().ends_with("get_stu_course_sched.action")
            {
                self.responses["nonempty_checkin_body"].as_str().unwrap()
            } else if request.method == HttpMethod::Get && response["get_body"].is_string() {
                response["get_body"].as_str().unwrap()
            } else {
                response["body"].as_str().unwrap()
            },
        );
        let location = if self.operation == "classroom" {
            response
                .get("classroom_location")
                .unwrap_or(&response["location"])
        } else {
            &response["location"]
        };
        if let Some(location) = location.as_str() {
            reply = reply.with_header("Location", location);
        } else {
            reply = reply.with_header("Content-Type", "application/json");
        }
        Ok(reply)
    }
}

#[tokio::test]
async fn reference_business_wire_capture() {
    let responses: Value = serde_json::from_str(include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/data/ubaa-business-responses.json"
    )))
    .unwrap();
    let day = std::env::var("GINKGO_REFERENCE_DAY").unwrap_or_else(|_| {
        crate::foundation::school_time::beijing_day(&crate::services::cache::now_shanghai())
            .unwrap()
            .local_date
    });
    let expected: Value = serde_json::from_str(
        &include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/tests/data/ubaa-business-wire.json"
        ))
        .replace("$COMPACT_DAY", &day.replace('-', ""))
        .replace("$DAY", &day),
    )
    .unwrap();
    let mut cases = Vec::new();
    for (mode, preference) in [
        ("direct", RoutePreference::Direct),
        ("webvpn", RoutePreference::WebVpn),
    ] {
        for operation in [
            "terms",
            "checkin",
            "checkin-nonempty",
            "library",
            "grades",
            "classroom",
        ] {
            let transport = WireProbe {
                responses: responses.clone(),
                operation: operation.into(),
                requests: Arc::default(),
            };
            let service = SchoolClient::new(
                crate::auth::session::Session::new(transport.clone()),
                MemoryVault::default(),
            );
            service.set_route(preference);
            service.set_authenticated(
                "sy2501001".into(),
                UserProfile {
                    school_id: "sy2501001".into(),
                    name: "fixture".into(),
                },
            );
            let mut values = None;
            let result = match operation {
                "terms" => service.load_grade_terms().await.map(|terms| terms.len()),
                "checkin" | "checkin-nonempty" => service
                    .load_checkin_on_date(Some(day.clone()), true)
                    .await
                    .map(|outcome| {
                        if operation == "checkin-nonempty" { values = Some(outcome.courses.iter().map(|course| serde_json::json!({
                            "id":course.id,"name":course.course_name,"begin":course.begins_at,"end":course.ends_at,
                            "sign_status": match course.status { CheckInStatus::NotSigned => 0, CheckInStatus::Signed => 1, CheckInStatus::Unknown => -1 }
                        })).collect::<Vec<_>>()); }
                        outcome.courses.len()
                    }),
                "library" => service
                    .load_library_venues(true)
                    .await
                    .map(|outcome| outcome.venues.len()),
                "grades" => service.load_grades(Some("2025-2026-1"), true).await.map(|outcome| outcome.courses.len()),
                "classroom" => service.load_classrooms(&ClassroomQueryInput {
                    campus: 1, date: day.clone(), search: String::new(), section: 0,
                    minimum_free_sections: 0, minimum_consecutive_sections: 0, building: None,
                    sort: Sort::Name, force_refresh: true,
                }).await.map(|outcome| outcome.result.summary.room_count),
                _ => unreachable!(),
            };
            assert!(result.is_ok(), "{mode}-{operation}: {result:?}");
            let mut case = serde_json::json!({
                "id": format!("{mode}-{operation}"),
                "count": result.unwrap(),
                "requests": transport.requests.lock().unwrap().clone()
            });
            if let Some(values) = values {
                case["values"] = serde_json::json!(values);
            }
            cases.push(case);
        }
    }
    if let Ok(path) = std::env::var("GINKGO_RUST_WIRE") {
        std::fs::write(
            path,
            serde_json::to_vec_pretty(
                &serde_json::json!({"source": "synthetic", "day": day, "cases": cases}),
            )
            .unwrap(),
        )
        .unwrap();
    }
    assert_eq!(cases.len(), expected["cases"].as_array().unwrap().len());
    for (actual, expected) in cases.iter().zip(expected["cases"].as_array().unwrap()) {
        assert_eq!(actual["id"], expected["id"]);
        assert_eq!(actual["count"], expected["count"]);
        assert_eq!(actual.get("values"), expected.get("values"));
        let actual_requests = actual["requests"].as_array().unwrap();
        let expected_requests = expected["requests"].as_array().unwrap();
        assert_eq!(
            actual_requests.len(),
            expected_requests.len(),
            "{} request count",
            actual["id"]
        );
        for (index, (actual_request, expected_request)) in
            actual_requests.iter().zip(expected_requests).enumerate()
        {
            let mut expected_request = expected_request.clone();
            if actual["id"] == "webvpn-classroom" && index == 1 {
                assert_eq!(
                    expected_request["url"],
                    "https://app.buaa.edu.cn/site/classRoomQuery/index"
                );
                // The reference engine follows this absolute URL directly;
                // Ginkgo deliberately retains the authenticated VPN route.
                expected_request["url"] = webvpn::wrap(expected_request["url"].as_str().unwrap())
                    .unwrap()
                    .into();
            }
            assert_eq!(
                canonical_request(actual_request),
                canonical_request(&expected_request),
                "{} request {} differs from executed UBAA",
                actual["id"],
                index + 1
            );
        }
    }
    if let Ok(path) = std::env::var("GINKGO_RUST_WIRE") {
        std::fs::write(
            path,
            serde_json::to_vec_pretty(
                &serde_json::json!({"source": "synthetic", "day": day, "cases": cases}),
            )
            .unwrap(),
        )
        .unwrap();
    }
}

fn canonical_request(request: &Value) -> Value {
    let url = url::Url::parse(request["url"].as_str().unwrap()).unwrap();
    let mut query: Vec<_> = url
        .query_pairs()
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    query.sort();
    let mut headers = request["headers"].as_object().unwrap().clone();
    if let Some(cookie) = headers.get("cookie").and_then(Value::as_str) {
        let mut parts: Vec<_> = cookie.split(';').map(str::trim).collect();
        parts.sort();
        headers.insert("cookie".into(), serde_json::to_value(parts).unwrap());
    }
    let body = request["body"].as_str().unwrap();
    let content_type = headers
        .get("content-type")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let body = if content_type.contains("application/json") && !body.is_empty() {
        serde_json::from_str(body).unwrap()
    } else if content_type.contains("application/x-www-form-urlencoded") {
        let mut pairs: Vec<_> = url::form_urlencoded::parse(body.as_bytes())
            .map(|(k, v)| (k.into_owned(), v.into_owned()))
            .collect();
        pairs.sort();
        serde_json::to_value(pairs).unwrap()
    } else {
        Value::String(body.into())
    };
    serde_json::json!({"method": request["method"], "url": [&url[..url::Position::BeforePath], url.path(), url.fragment().unwrap_or_default()], "query": query, "headers": headers, "body": body})
}
