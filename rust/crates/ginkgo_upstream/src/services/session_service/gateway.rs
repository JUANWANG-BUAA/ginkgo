//! Gateway challenges are scoped to the authenticated owner and single-use ID.
use super::*;
use ginkgo_domain::ports::LoginChallengeData;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    pub(super) fn finish_gateway_login(
        &self,
        outcome: Result<LoginResult, AppError>,
        owner: &AccountOwner,
    ) -> Result<(), AppError> {
        let mut identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|user| user.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        match outcome {
            Ok(LoginResult::SignedIn(profile))
                if profile.school_id.eq_ignore_ascii_case(&owner.account) =>
            {
                identity.gateway_pending = None;
                identity.active_route = Some(RouteMode::WebVpn);
                Ok(())
            }
            Ok(LoginResult::SignedIn(_)) => Err(AppError::session_expired()),
            Ok(LoginResult::CaptchaRequired { challenge, page }) => {
                identity.gateway_pending = Some(PendingLogin {
                    page,
                    route: RouteMode::WebVpn,
                    account: owner.account.clone(),
                    generation: owner.generation,
                    created: Instant::now(),
                });
                Err(AppError::with_detail(
                    ErrorCode::CaptchaRequired,
                    challenge.id,
                ))
            }
            Err(error) => Err(error),
        }
    }

    pub(super) async fn read_gateway_challenge(
        &self,
        expected_id: Option<&str>,
        refresh: bool,
    ) -> Result<Option<LoginChallengeData>, AppError> {
        let _gate = self.gateway_recovery_gate.lock().await;
        let owner = self.account_owner()?;
        let page = {
            let identity = self.identity.lock();
            let Some(pending) = identity.gateway_pending.as_ref() else {
                return Ok(None);
            };
            // Expired answers are rejected, but the owner may explicitly GET
            // a replacement without starting another password authentication.
            if !pending.belongs_to(&owner.account, owner.generation)
                || (!refresh && !pending.valid(&owner.account, owner.generation))
            {
                return Err(AppError::session_expired());
            }
            let LoginPage::Form {
                captcha: Some(challenge),
                ..
            } = &pending.page
            else {
                return Err(AppError::changed());
            };
            if expected_id.is_some_and(|id| id != challenge.id)
                || (refresh && expected_id.is_none())
            {
                return Err(AppError::session_expired());
            }
            pending.page.clone()
        };
        let session = self.session.routed(RouteMode::WebVpn);
        let result = async {
            let page = if refresh {
                // Revoke the old execution before contacting the school.
                if let Some(pending) = self.identity.lock().gateway_pending.as_mut() {
                    pending.created = Instant::now() - Duration::from_secs(301);
                }
                let page = auth::fetch_login_page(&session).await?;
                self.check_account_owner(&owner)?;
                let LoginPage::Form {
                    captcha: Some(_), ..
                } = &page
                else {
                    return Err(AppError::session_expired());
                };
                page
            } else {
                page
            };
            let LoginPage::Form {
                captcha: Some(challenge),
                ..
            } = &page
            else {
                return Err(AppError::changed());
            };
            let image = auth::challenge::image(&session, &challenge.id).await?;
            self.check_account_owner(&owner)?;
            let result = LoginChallengeData {
                challenge_id: challenge.id.clone(),
                challenge_type: challenge.captcha_type.clone(),
                text_supported: true,
                image,
            };
            if refresh {
                let mut identity = self.identity.lock();
                if identity.generation != owner.generation
                    || !identity
                        .authenticated
                        .as_ref()
                        .is_some_and(|user| user.account == owner.account)
                {
                    return Err(AppError::session_expired());
                }
                identity.gateway_pending = Some(PendingLogin {
                    page,
                    route: RouteMode::WebVpn,
                    account: owner.account.clone(),
                    generation: owner.generation,
                    created: Instant::now(),
                });
            }
            Ok(Some(result))
        }
        .await;
        result
    }

    pub(super) async fn answer_gateway_challenge(
        &self,
        expected_id: &str,
        answer: &str,
    ) -> Result<(), AppError> {
        if expected_id.is_empty() || answer.trim().is_empty() {
            return Err(AppError::invalid());
        }
        let _gate = self.gateway_recovery_gate.lock().await;
        let _school = self.school_recovery_gate.lock().await;
        let owner = self.account_owner()?;
        let credentials = self.recovery_credentials(&owner.account)?;
        let page = {
            let mut identity = self.identity.lock();
            let pending = identity
                .gateway_pending
                .as_ref()
                .ok_or_else(AppError::session_expired)?;
            if !pending.valid(&owner.account, owner.generation)
                || !matches!(&pending.page, LoginPage::Form { captcha: Some(challenge), .. } if challenge.id == expected_id)
            {
                return Err(AppError::session_expired());
            }
            // A challenge can be submitted once; an unknown result is not replayed.
            identity
                .gateway_pending
                .take()
                .ok_or_else(AppError::session_expired)?
                .page
        };
        let credentials = auth::Credentials {
            captcha_text: Some(answer.trim().to_owned()),
            ..credentials
        };
        let session = self.session.routed(RouteMode::WebVpn);
        let outcome = auth::complete_login(&session, &credentials, page).await;
        let result = self.finish_gateway_login(outcome, &owner);
        if result.is_ok() {
            self.gateway_generation.fetch_add(1, Ordering::Release);
            *self.gateway_login_failure.lock() = None;
            let _ = self.persist_active_session().await;
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        auth::{vault::MemoryVault, Credentials},
        foundation::http::{HttpMethod, HttpResponse},
        test_support::MockTransport,
    };
    use ginkgo_domain::ports::SessionSource;

    fn page(id: &str) -> HttpResponse {
        HttpResponse::new(
            200,
            auth::LOGIN_URL,
            format!(
                r#"<form action="/login"><input name="execution" value="execution-{id}" /></form><script>config.captcha = {{ type: 'char', id: '{id}' }};</script>"#
            ),
        )
    }
    fn image() -> HttpResponse {
        HttpResponse {
            bytes: Some(vec![0xff, 0xd8, 0xff, 0x00, 0xff, 0xd9]),
            ..HttpResponse::new(200, "https://sso.buaa.edu.cn/captcha", "")
        }
    }
    fn service(
        responses: Vec<HttpResponse>,
        gateway: bool,
    ) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
        let responses = if responses.is_empty() || !gateway {
            responses
        } else {
            std::iter::once(HttpResponse::new(
                200,
                auth::UC_STATUS_URL,
                r#"{"code":10600,"data":null}"#,
            ))
            .chain(responses)
            .collect()
        };
        let transport = MockTransport::with_responses(responses);
        let service = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
        service.set_route(ginkgo_domain::ports::RoutePreference::WebVpn);
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "synthetic".into(),
            },
        );
        service.remember_session_credentials(&Credentials {
            username: "sy2501001".into(),
            password: "synthetic".into(),
            captcha_text: None,
        });
        (service, transport)
    }
    #[tokio::test]
    async fn challenge_blocks_automatic_password_retries_and_wrong_id_keeps_current_page() {
        let (service, transport) = service(vec![page("cap-1"), image()], true);
        assert_eq!(
            service.ensure_webvpn_session().await.unwrap_err().code,
            ErrorCode::CaptchaRequired
        );
        assert!(service.resume_gateway_login("old", "1234").await.is_err());
        let challenge = service
            .gateway_challenge(Some("cap-1"), false)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(challenge.challenge_id, "cap-1");
        assert!(service.ensure_webvpn_session().await.is_err());
        assert_eq!(transport.request_count(), 3);
        assert!(transport
            .requests()
            .iter()
            .all(|r| r.method == HttpMethod::Get));
    }
    #[tokio::test]
    async fn refresh_rotates_execution_and_never_changes_explicit_preference() {
        let (service, transport) = service(vec![page("cap-1"), page("cap-2"), image()], true);
        *lock_value(&service.route) = RoutePreference::WebVpn;
        service.ensure_webvpn_session().await.unwrap_err();
        let challenge = service
            .gateway_challenge(Some("cap-1"), true)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(challenge.challenge_id, "cap-2");
        assert_eq!(service.session.route(), RouteMode::WebVpn);
        assert!(service.resume_gateway_login("cap-1", "1234").await.is_err());
        assert_eq!(transport.request_count(), 4);
        service.set_route(RoutePreference::Direct);
        assert!(service.resume_gateway_login("cap-2", "1234").await.is_err());
        assert_eq!(transport.request_count(), 4);
    }
    #[tokio::test]
    async fn failed_refresh_preserves_get_recovery_but_revokes_old_answers() {
        for gateway in [false, true] {
            let (service, transport) = service(
                vec![
                    page("cap-1"),
                    HttpResponse::new(503, auth::LOGIN_URL, "temporary"),
                    page("cap-2"),
                    image(),
                ],
                gateway,
            );
            if gateway {
                service.ensure_webvpn_session().await.unwrap_err();
            } else {
                service
                    .sign_in("sy2501001", "synthetic", None, false)
                    .await
                    .unwrap();
            }
            if gateway {
                assert!(service
                    .gateway_challenge(Some("cap-1"), true)
                    .await
                    .is_err());
                assert!(service.resume_gateway_login("cap-1", "old").await.is_err());
                assert_eq!(
                    service
                        .gateway_challenge(Some("cap-1"), true)
                        .await
                        .unwrap()
                        .unwrap()
                        .challenge_id,
                    "cap-2"
                );
            } else {
                assert!(service.login_challenge(Some("cap-1"), true).await.is_err());
                assert!(service.login_challenge(Some("cap-1"), false).await.is_err());
                assert_eq!(
                    service
                        .login_challenge(Some("cap-1"), true)
                        .await
                        .unwrap()
                        .challenge_id,
                    "cap-2"
                );
            }
            assert_eq!(transport.request_count(), 4 + usize::from(gateway));
            assert!(transport
                .requests()
                .iter()
                .all(|r| r.method == HttpMethod::Get));
        }
    }

    #[tokio::test]
    async fn image_failure_during_refresh_retains_the_original_get_handle() {
        for gateway in [false, true] {
            let (service, transport) = service(
                vec![
                    page("cap-1"),
                    page("cap-2"),
                    HttpResponse::new(503, auth::LOGIN_URL, "image unavailable"),
                    page("cap-3"),
                    image(),
                ],
                gateway,
            );
            if gateway {
                service.ensure_webvpn_session().await.unwrap_err();
                assert!(service
                    .gateway_challenge(Some("cap-1"), true)
                    .await
                    .is_err());
                assert!(service.resume_gateway_login("cap-1", "old").await.is_err());
                assert_eq!(
                    service
                        .gateway_challenge(Some("cap-1"), true)
                        .await
                        .unwrap()
                        .unwrap()
                        .challenge_id,
                    "cap-3"
                );
            } else {
                service
                    .sign_in("sy2501001", "synthetic", None, false)
                    .await
                    .unwrap();
                assert!(service.login_challenge(Some("cap-1"), true).await.is_err());
                assert!(service.login_challenge(Some("cap-1"), false).await.is_err());
                assert_eq!(
                    service
                        .login_challenge(Some("cap-1"), true)
                        .await
                        .unwrap()
                        .challenge_id,
                    "cap-3"
                );
            }
            assert_eq!(transport.request_count(), 5 + usize::from(gateway));
            assert!(transport
                .requests()
                .iter()
                .all(|r| r.method == HttpMethod::Get));
        }
    }

    #[tokio::test]
    async fn expired_login_challenge_refreshes_with_get_and_a_new_execution() {
        let (service, transport) = service(vec![page("cap-1"), page("cap-2"), image()], false);
        service
            .sign_in("sy2501001", "synthetic", None, false)
            .await
            .unwrap();
        service
            .identity
            .lock()
            .pending_login
            .as_mut()
            .unwrap()
            .created = Instant::now() - Duration::from_secs(301);
        assert!(service.login_challenge(Some("cap-1"), false).await.is_err());
        let next = service.login_challenge(Some("cap-1"), true).await.unwrap();
        assert_eq!(next.challenge_id, "cap-2");
        assert!(service.login_challenge(Some("cap-1"), false).await.is_err());
        assert_eq!(transport.request_count(), 3);
        assert!(transport
            .requests()
            .iter()
            .all(|r| r.method == HttpMethod::Get));
    }

    #[tokio::test]
    async fn expired_challenge_still_blocks_background_authentication() {
        let (service, transport) = service(vec![page("cap-1")], true);
        service.ensure_webvpn_session().await.unwrap_err();
        service
            .identity
            .lock()
            .gateway_pending
            .as_mut()
            .unwrap()
            .created = Instant::now() - Duration::from_secs(301);
        *service.gateway_login_failure.lock() = None;
        assert_eq!(
            service.ensure_webvpn_session().await.unwrap_err().code,
            ErrorCode::CaptchaRequired
        );
        assert_eq!(
            transport.request_count(),
            2,
            "expiry must not restart authentication"
        );
    }

    #[tokio::test]
    async fn credential_rejection_uses_long_cooldown_but_service_failure_does_not() {
        let (service, transport) = service(vec![], true);
        for code in [
            ErrorCode::InvalidCredentials,
            ErrorCode::PreLoginTip,
            ErrorCode::ServiceUnavailable,
        ] {
            *service.automatic_login_failure.lock() = Some((
                Instant::now() - Duration::from_secs(61),
                AppError::new(code.clone()),
            ));
            assert_eq!(
                service.check_automatic_login_failure().is_err(),
                matches!(code, ErrorCode::InvalidCredentials | ErrorCode::PreLoginTip)
            );
        }
        for code in [ErrorCode::InvalidCredentials, ErrorCode::PreLoginTip] {
            *service.gateway_login_failure.lock() = Some((
                Instant::now() - Duration::from_secs(61),
                AppError::new(code.clone()),
            ));
            assert_eq!(
                service.ensure_webvpn_session().await.unwrap_err().code,
                code
            );
            assert_eq!(transport.request_count(), 0);
        }
        *service.gateway_login_failure.lock() = Some((
            Instant::now() - Duration::from_secs(1801),
            AppError::new(ErrorCode::InvalidCredentials),
        ));
        assert!(service.ensure_webvpn_session().await.is_err());
        assert!(
            transport.request_count() > 0,
            "expired cooldown permits a bounded later read"
        );
    }

    #[tokio::test]
    async fn expired_challenge_can_refresh_without_a_password_post() {
        let (service, transport) = service(vec![page("cap-1"), page("cap-2"), image()], true);
        service.ensure_webvpn_session().await.unwrap_err();
        service
            .identity
            .lock()
            .gateway_pending
            .as_mut()
            .unwrap()
            .created = Instant::now() - Duration::from_secs(301);
        assert!(service.resume_gateway_login("cap-1", "1234").await.is_err());
        let next = service
            .gateway_challenge(Some("cap-1"), true)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(next.challenge_id, "cap-2");
        assert!(service.resume_gateway_login("cap-1", "1234").await.is_err());
        assert_eq!(transport.request_count(), 4);
        assert!(transport
            .requests()
            .iter()
            .all(|r| r.method == HttpMethod::Get));
    }

    #[tokio::test]
    async fn expired_answer_and_unknown_submission_are_never_replayed() {
        let (service, transport) = service(vec![page("cap-1"), page("pre-submit")], true);
        service.ensure_webvpn_session().await.unwrap_err();
        service
            .identity
            .lock()
            .gateway_pending
            .as_mut()
            .unwrap()
            .created = Instant::now() - Duration::from_secs(301);
        assert!(service.resume_gateway_login("cap-1", "1234").await.is_err());
        assert_eq!(transport.request_count(), 2);
        service
            .identity
            .lock()
            .gateway_pending
            .as_mut()
            .unwrap()
            .created = Instant::now();
        // The preparatory GET succeeds, then the password POST has no response.
        assert!(service.resume_gateway_login("cap-1", "1234").await.is_err());
        let calls = transport.request_count();
        assert!(service.resume_gateway_login("cap-1", "1234").await.is_err());
        assert_eq!(transport.request_count(), calls);
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.method == HttpMethod::Post)
                .count(),
            1
        );
    }
    #[tokio::test]
    async fn wrong_answer_is_a_ubaa_refusal_and_cannot_replay_the_consumed_challenge() {
        let (service, transport) = service(
            vec![
                page("cap-1"),
                page("pre-submit"),
                HttpResponse::new(
                    401,
                    auth::LOGIN_URL,
                    "<div id=\"errorDiv\">验证码错误</div>",
                ),
            ],
            true,
        );
        service.ensure_webvpn_session().await.unwrap_err();
        let error = service
            .resume_gateway_login("cap-1", "wrong")
            .await
            .unwrap_err();
        assert_eq!(error.code, ErrorCode::PreLoginTip);
        assert_eq!(error.detail.as_deref(), Some("验证码错误"));
        let count = transport.request_count();
        assert!(service
            .resume_gateway_login("cap-1", "wrong")
            .await
            .is_err());
        assert_eq!(transport.request_count(), count);
        assert_eq!(service.current_account().unwrap(), "sy2501001");
        assert!(service.identity.lock().gateway_pending.is_none());
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.method == HttpMethod::Post)
                .count(),
            1
        );
    }

    #[tokio::test]
    async fn correct_answer_uses_supplied_execution_and_preserves_school_identity() {
        let (service, transport) = service(
            vec![
                page("cap-1"),
                page("pre-submit"),
                HttpResponse::new(302, auth::LOGIN_URL, "")
                    .with_header("Location", "https://uc.buaa.edu.cn/?ticket=ST-synthetic"),
                HttpResponse::new(
                    200,
                    "https://uc.buaa.edu.cn/?ticket=ST-synthetic",
                    "service",
                ),
                HttpResponse::new(200, auth::UC_ACTIVATION_URL, ""),
                HttpResponse::new(
                    200,
                    auth::UC_STATUS_URL,
                    r#"{"code":0,"data":{"schoolid":"sy2501001","name":"synthetic"}}"#,
                ),
            ],
            true,
        );
        service.ensure_webvpn_session().await.unwrap_err();
        service
            .resume_gateway_login("cap-1", "correct")
            .await
            .unwrap();
        assert_eq!(service.current_account().unwrap(), "sy2501001");
        assert!(service
            .gateway_challenge(None, false)
            .await
            .unwrap()
            .is_none());
        assert_eq!(service.session.route(), RouteMode::WebVpn);
        let requests = transport.requests();
        let posts: Vec<_> = requests
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .collect();
        assert_eq!(posts.len(), 1);
        assert!(posts[0].body.as_ref().unwrap().contains("execution-cap-1"));
        assert!(service.gateway_login_failure.lock().is_none());
    }
}
