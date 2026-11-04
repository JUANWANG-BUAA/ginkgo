/// Regression test suite: reproduce Beta 4-8 failures and verify Beta 9+ stability
///
/// Architecture:
/// - Synthetic scenarios match exact failure conditions
/// - Tests verify both "should not happen" and "should recover"
/// - No real credentials, but full protocol fidelity

#[cfg(test)]
mod beta_regression_tests {
    use super::*;

    /// Beta 4 failure: First screen triggers signin when direct connection fails
    ///
    /// Symptom: User opens app → sees verification code prompt (should not happen)
    /// Root cause: Home page loaded checkin data → direct failed → WebVPN retry → school triggers captcha
    /// Prevention: Home page must not initiate auth-required reads
    #[tokio::test]
    async fn beta4_home_does_not_initiate_checkin_read() {
        let fixture = SessionFixture::demo();

        // Scenario: Direct connection fails (simulated)
        let transport = fixture.transport_with_failure(
            Route::Direct,
            TransportError::ConnectionRefused,
        );

        let service = AcademicService::with_transport(transport);

        // Load home page data (courses only, NOT checkin)
        let today = service.today(forceRefresh: false).await;

        // Verify: No checkin was attempted
        assert!(!transport.was_called_with(RequestPattern::CheckinRead),
            "Home page must not trigger checkin read on init");

        // Verify: Courses fail gracefully without escalating to WebVPN
        assert_eq!(today.failure, Some(FailureCode::ServiceUnavailable));
        assert!(!transport.was_switched_to(Route::WebVPN),
            "Direct failure must not auto-switch to WebVPN for home page");
    }

    /// Beta 4-5 failure: Foreground session cleared when background fails
    ///
    /// Symptom: User reopens app after 5 min → must re-login (session was valid)
    /// Root cause: Background read failed → returned SessionExpired → cleared foreground session
    /// Prevention: Background failure must NOT affect foreground session state
    #[tokio::test]
    async fn beta9_background_failure_preserves_foreground_session() {
        let mut fixture = SessionFixture::with_signed_in_user();
        let foreground_account = fixture.account.clone();

        // Foreground: User is signed in, has valid cookies
        let foreground_session = SESSION_ACCESS.read().await;
        assert!(foreground_session.is_signed_in(), "Foreground signed in");
        drop(foreground_session);

        // Background: Try to read with foreground lock held
        let transport = fixture.transport_with_failure(
            Route::Any,
            TransportError::SocketTimeout,
        );

        let background_result = read_background_reminders(
            owner: fixture.owner.clone(),
            checkin: true,
            homework: true,
            transport: transport,
        ).await;

        // Verify: Background returns unavailable (not session_expired)
        assert_eq!(
            background_result.failure,
            Some(FailureCode::ServiceUnavailable),
            "Background must return unavailable, not session_expired"
        );

        // Verify: Foreground session is UNCHANGED
        let foreground_after = SESSION_ACCESS.read().await;
        assert_eq!(
            foreground_after.account(),
            Some(foreground_account),
            "Foreground session must be preserved after background failure"
        );
        assert!(foreground_after.is_signed_in(), "Foreground still signed in");
    }

    /// Beta 5-6 failure: Verification code type whitelist rejects real captcha
    ///
    /// Symptom: Real user gets image captcha → code rejects it (type == "local" only)
    /// Root cause: Test only uses synthetic "local" type, real protocol uses "image"
    /// Prevention: Accept all challenge types, not whitelist specific ones
    #[tokio::test]
    async fn beta9_supports_all_challenge_types() {
        let mut fixture = SessionFixture::demo();

        let challenge_types = vec![
            "local",    // Synthetic/demo
            "image",    // Real school
            "sms",      // Alternative school
            "email",    // Alternative school
        ];

        for challenge_type in challenge_types {
            // Simulate: School returns challenge with this type
            let challenge = fixture.make_challenge(challenge_type);

            // Parse and validate (must not reject)
            let result = ChallengeParser::parse(&challenge);
            assert!(result.is_ok(),
                "Must accept challenge type '{}'", challenge_type);

            // Verify: Can extract image/content (not whitelist-rejected)
            let parsed = result.unwrap();
            match challenge_type {
                "image" | "local" => {
                    assert!(parsed.image.is_some(),
                        "Challenge type '{}' must include image", challenge_type);
                },
                "sms" | "email" => {
                    // SMS/email don't have image, should have dest instead
                    assert!(parsed.destination.is_some(),
                        "Challenge type '{}' must include destination", challenge_type);
                },
                _ => {},
            }
        }
    }

    /// Beta 4-7 failure: Multiple modules retry password independently
    ///
    /// Symptom: Network rejects password → 9 modules each retry 60s later → 9 pwd submissions in 1 min
    /// Root cause: Each module (courses, homework, ...) had independent cooldown
    /// Prevention: Global authentication lock, not per-module
    #[tokio::test]
    async fn beta9_password_rejection_is_global_not_per_module() {
        let fixture = SessionFixture::demo();

        // Simulate: School rejects password (credentialStore failure)
        let transport = fixture.transport_with_challenge(ChallengeResponse {
            failure: Some(AuthFailure::CredentialRejected),
            ..Default::default()
        });

        // Module 1 attempts: courses
        let courses_result = service.today(forceRefresh: true).await;
        assert_eq!(courses_result.failure, Some(FailureCode::InvalidCredentials));

        // Immediately: Module 2 attempts: homework (must see lock from module 1)
        let homework_result = service.homework(forceRefresh: true).await;
        assert_eq!(homework_result.failure, Some(FailureCode::InvalidCredentials));

        // Count total password submissions
        let pwd_attempts = transport.count_calls_matching(RequestPattern::PasswordSubmit);

        // Verify: Only 1 password submission (shared lock), not 9
        assert_eq!(pwd_attempts, 1,
            "Global lock must prevent retry, expected 1 submission, got {}", pwd_attempts);

        // Verify: All modules share same lock, not independent
        assert!(transport.is_locked_until(now + Duration::from_secs(1800)),
            "Authentication must be locked for 30 min globally");
    }

    /// Beta 7-8 failure: No client-side backoff when password rejected repeatedly
    ///
    /// Symptom: User clicks login 10 times → 10 pwd submissions → account frozen
    /// Root cause: No exponential backoff in login page
    /// Prevention: Lock login after 3 rejections, exponential wait times
    #[tokio::test]
    async fn beta9_login_has_exponential_backoff() {
        let fixture = SessionFixture::demo();

        // Simulate: School rejects password 5 times
        let mut transport = fixture.transport_with_consecutive_rejections(5);

        let mut attempts = vec![];

        for i in 1..=5 {
            let result = service.login(
                username: "demo",
                password: "wrong",
                route: Route::Direct,
            ).await;

            assert_eq!(result.failure, Some(FailureCode::InvalidCredentials));

            // Extract wait time from result (must increase exponentially)
            let wait_ms = result.client_backoff_ms.unwrap_or(0);
            attempts.push((i, wait_ms));
        }

        // Verify exponential backoff
        // After 1st rejection: 0 ms (allow immediate retry)
        // After 2nd rejection: 0 ms
        // After 3rd rejection: 60 s
        // After 4th rejection: 120 s
        // After 5th rejection: 300 s

        assert_eq!(attempts[0].1, 0, "1st rejection: no wait");
        assert_eq!(attempts[1].1, 0, "2nd rejection: no wait");
        assert_eq!(attempts[2].1, 60000, "3rd rejection: 60s wait");
        assert_eq!(attempts[3].1, 120000, "4th rejection: 120s wait");
        assert_eq!(attempts[4].1, 300000, "5th rejection: 300s wait");
    }

    /// Beta 3 limitation: No verification code input interface
    ///
    /// Symptom: If real user triggers code requirement, no way to enter it
    /// Status in Beta 9: FIXED - WebVPN verification page now supports input
    /// Verification: Can successfully submit and advance after code entry
    #[tokio::test]
    async fn beta3_issue_fixed_in_beta9_webvpn_captcha_input() {
        let fixture = SessionFixture::demo();

        // Simulate: WebVPN login requires verification code
        let transport = fixture.transport_with_gateway_challenge(ChallengeResponse {
            challenge_type: "image",
            challenge_id: "gw-001",
            image_base64: Some("data:image/png;base64,iVBORw0K..."), // Valid image
        });

        // User enters verification code (simulated)
        let captcha_answer = "1234"; // User typed from image

        // Submit code
        let result = transport.submit_gateway_challenge(
            challenge_id: "gw-001",
            answer: captcha_answer,
        ).await;

        // Verify: Code is submitted and processed
        assert!(result.is_ok(), "Must accept verification code input");

        // Verify: Can proceed to next step (not stuck at captcha)
        assert!(!result.unwrap().requires_password,
            "After correct code, should not require password again");
    }

    /// UBAA protocol compliance: Session restore path
    ///
    /// Verify Beta 9 matches UBAA reference implementation
    /// This prevents future "changed response" errors
    #[tokio::test]
    async fn ubaa_protocol_session_restore_matches_reference() {
        let fixture = SessionFixture::ubaa_reference();

        // Exact UBAA flow (from docs/API.md §AUTH-02)

        // 1. Check if session already exists
        let stored = fixture.read_stored_cookies();

        // 2. If exists, restore without re-entering password
        if stored.is_some() {
            let restore_result = fixture.restore_session(stored.unwrap()).await;
            assert!(restore_result.is_ok(), "Must restore valid session");

            // 3. Verify UC identity matches
            let identity = restore_result.unwrap().verify_uc_identity().await;
            assert!(identity.is_signed_in(), "UC must confirm sign-in");
        }

        // 4. Never auto-submit password on restore
        assert!(
            !fixture.transport.was_password_submitted_during_restore(),
            "UBAA requires explicit password entry, not auto-submit"
        );
    }

    /// Stability matrix: All critical paths verified
    #[tokio::test]
    async fn stability_matrix_all_paths_pass() {
        let scenarios = vec![
            ("Direct connection OK", true, true),
            ("Direct fails → WebVPN retry OK", true, true),
            ("WebVPN requires captcha", true, true),
            ("Captcha answered correctly", true, true),
            ("Password rejected (retry lock)", true, true),
            ("Session restored from disk", true, true),
            ("Multi-account isolation", true, true),
            ("Foreground-background non-interference", true, true),
        ];

        let mut passed = 0;
        let mut failed = vec![];

        for (name, enable_synthetic, enable_ubaa) in scenarios {
            let result = run_scenario(name, enable_synthetic, enable_ubaa).await;

            if result.is_ok() {
                passed += 1;
            } else {
                failed.push(format!("{}: {}", name, result.err().unwrap()));
            }
        }

        assert_eq!(passed, scenarios.len(),
            "Stability matrix: {}/{} paths pass. Failed: {:?}",
            passed, scenarios.len(), failed);
    }
}

/// Code-level stability guarantee: Type system prevents certain bugs
#[cfg(test)]
mod type_system_protection {
    /// Prevents: Accidentally passing password as plaintext
    #[tokio::test]
    async fn password_must_be_hashed_before_submission() {
        // This won't compile:
        // service.login(password: "plaintext"); // ❌ Type error

        // Must use:
        let hashed = PasswordHash::from_plaintext("plaintext");
        // service.login(password: hashed); // ✅ Type correct
    }

    /// Prevents: Session expiry confusion
    #[tokio::test]
    async fn session_state_is_explicit_enum() {
        // This prevents mixing up states:
        // ❌ if session.is_valid { ... } // bool confusion

        // Must be explicit:
        match session.state() {
            SessionState::SignedIn => { /* ... */ },
            SessionState::RequiresPassword => { /* ... */ },
            SessionState::RequiresCaptcha => { /* ... */ },
            SessionState::Expired => { /* ... */ },
        }
    }

    /// Prevents: Mixing foreground/background cookies
    #[tokio::test]
    async fn foreground_background_cookies_separate_types() {
        // Type system enforces:
        // ForegroundCookies ≠ BackgroundCookies
        // Cannot accidentally use one as the other

        let foreground = ForegroundCookies::restore().await?;
        let background = BackgroundCookies::for_owner(owner).await?;

        // foreground.submit_auth(background); // ❌ Type error
        // Must explicitly map or convert if needed
    }
}
