#[tokio::test]
async fn history_session_observe_cold_boot() {
    let transport = Probe::new(Scenario::ColdBoot);
    let vault = MemoryVault::default();
    let client = SchoolClient::new(Session::new(transport.clone()), vault.clone());
    let login = client.sign_in("sy2501001", "synthetic", None, false).await;
    assert!(
        matches!(login, Ok(SessionOutcome::SignedIn { .. })),
        "synthetic login failed: {} requests={:?}",
        describe(&login),
        transport.requests()
    );
    let record = vault.load_session().unwrap().unwrap();
    let saved_route = record.route;
    let login_route = client.session.route();
    let restore_transport = Probe::new(Scenario::ColdBoot);
    let restored = SchoolClient::new(Session::new(restore_transport.clone()), vault);
    let result = restored.restore().await;
    println!("OBS cold_boot login={} active_route={:?} saved_route={:?} restored={} restore_requests={:?} record_remaining={}", describe(&login), login_route, saved_route, describe(&result), restore_transport.requests(), restored.vault.load_session().unwrap().is_some());
    assert!(
        matches!(result, Ok(SessionOutcome::SignedIn { .. })),
        "cold restore lost synthetic valid session"
    );
}

#[tokio::test]
async fn history_session_observe_cold_boot_remembered() {
    let transport = Probe::new(Scenario::ColdBoot);
    let vault = MemoryVault::default();
    let client = SchoolClient::new(Session::new(transport), vault.clone());
    let login = client.sign_in("sy2501001", "synthetic", None, true).await;
    assert!(matches!(login, Ok(SessionOutcome::SignedIn { .. })));
    let restore_transport = Probe::new(Scenario::ColdBoot);
    let restored = SchoolClient::new(Session::new(restore_transport.clone()), vault);
    let result = restored.restore().await;
    let requests = restore_transport.requests();
    println!(
        "OBS cold_boot_remembered restored={} restore_requests={:?}",
        describe(&result),
        requests
    );
    assert!(matches!(result, Ok(SessionOutcome::SignedIn { .. })));
    assert!(
        !requests.iter().any(|s| s.starts_with("CAS_POST:")),
        "restoring a valid synthetic session submitted the password again"
    );
}
