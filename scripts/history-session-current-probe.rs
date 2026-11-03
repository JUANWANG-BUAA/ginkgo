#[tokio::test]
async fn reference_auth_wire_capture() {
    let mut observations = serde_json::Map::new();
    for (name, scenario, route) in [
        ("ticket", Scenario::Ticket, RoutePreference::Direct),
        ("uc_unavailable", Scenario::UcUnavailable, RoutePreference::Direct),
        ("webvpn", Scenario::Ticket, RoutePreference::WebVpn),
    ] {
        let transport = Probe::new(scenario);
        let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
        client.set_route(route);
        let result = client.sign_in("sy2501001", "synthetic", None, false).await;
        if name == "uc_unavailable" {
            assert!(result.is_err());
            assert!(!client.status().signed_in());
            assert!(client.vault.load_session().unwrap().is_none());
        } else {
            match result.unwrap() {
                SessionOutcome::SignedIn { profile, remembered } => {
                    assert_eq!(profile.school_id, "sy2501001");
                    assert_eq!(profile.name, "fixture");
                    assert!(!remembered);
                }
                other => panic!("unexpected authentication outcome: {other:?}"),
            }
            assert_eq!(client.status().account.as_deref(), Some("sy2501001"));
            assert!(client.vault.load("sy2501001").unwrap().is_none());
            assert!(client.vault.load_session().unwrap().is_some());
        }
        observations.insert(name.into(), serde_json::to_value(transport.raw_requests.lock().unwrap().clone()).unwrap());
    }
    std::fs::write(std::env::var("GINKGO_RUST_AUTH_WIRE").unwrap(), serde_json::to_vec_pretty(&observations).unwrap()).unwrap();
}

#[tokio::test]
async fn history_session_observe_checkin_direct_failure() {
    let transport = Probe::new(Scenario::Fallback);
    let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    let login = client.sign_in("sy2501001", "synthetic", None, false).await;
    assert!(matches!(login, Ok(SessionOutcome::SignedIn { .. })));
    let result = client
        .load_checkin_on_date(Some("2026-10-01".into()), true)
        .await;
    let error = match result {
        Err(error) => Some(error.code),
        Ok(outcome) => outcome.failure.map(|error| error.code),
    };
    let requests = transport.requests();
    let status = client.status();
    println!("OBS checkin_direct_failure error={error:?} status={status:?} requests={requests:?}");
    // This synthetic target UC explicitly confirms the same identity. The
    // gateway entry is then reached; its intentionally incomplete HTML fails
    // parsing rather than fabricating a successful business result.
    assert_eq!(error, Some(ErrorCode::ChangedResponse));
    assert!(requests
        .iter()
        .any(|s| s.starts_with("CHECKIN_ENTRY:direct:")));
    assert!(requests.iter().any(|s| s.starts_with("CHECKIN_ENTRY:vpn:")));
    assert!(requests.iter().any(|s| s.starts_with("UC_STATUS:vpn:")));
    assert_eq!(requests.iter().filter(|s| s.starts_with("CAS_POST:")).count(), 1);
}
