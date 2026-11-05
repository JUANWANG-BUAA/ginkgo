//! `SessionSource` 的客户端实现：登录挑战、状态、路由切换、登录/恢复/退出。
//!
//! 认证与会话状态全部留在这里；Flutter 只见粗粒度结果。字段可见性不变。

use super::{Identity, PendingLogin, SchoolClient};
use crate::{
    auth::{self, CredentialVault, Credentials, LoginPage, LoginResult},
    foundation::{http::HttpTransport, mutex::lock_value},
    AppError, ErrorCode,
};
use ginkgo_domain::ports::*;
use std::{sync::atomic::Ordering, time::Instant};

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionSource for SchoolClient<T, V> {
    async fn login_challenge(
        &self,
        expected_id: Option<&str>,
        refresh: bool,
    ) -> Result<LoginChallengeData, AppError> {
        let (page, route, account, generation, created) = {
            let mut identity = self.identity.lock();
            let generation = identity.generation;
            let pending = identity
                .pending_login
                .as_mut()
                .ok_or_else(AppError::session_expired)?;
            if !pending.belongs_to(&pending.account, generation)
                || (!refresh && !pending.valid(&pending.account, generation))
            {
                return Err(AppError::session_expired());
            }
            let LoginPage::Form {
                captcha: Some(challenge),
                ..
            } = &pending.page
            else {
                return Err(AppError::invalid());
            };
            if expected_id.is_some_and(|id| id != challenge.id)
                || (refresh && expected_id.is_none())
            {
                return Err(AppError::session_expired());
            }
            if refresh {
                pending.created = Instant::now() - std::time::Duration::from_secs(301);
            }
            (
                pending.page.clone(),
                pending.route,
                pending.account.clone(),
                pending.generation,
                pending.created,
            )
        };
        self.session.set_route(route);
        // Refresh is a new login-page GET, not an invented refresh endpoint and
        // never an ExistingSession hop or form submission.
        let clear_original_pending = || {
            let mut identity = self.identity.lock();
            if identity.generation == generation
                && identity.pending_login.as_ref().is_some_and(|pending| {
                    pending.account == account
                        && pending.generation == generation
                        && pending.created == created
                })
            {
                identity.pending_login = None;
            }
        };
        let page = if refresh {
            match auth::fetch_login_page(&self.session).await {
                Ok(page) => page,
                // Retain only an expired GET recovery handle on failure.
                Err(error) => return Err(error),
            }
        } else {
            page
        };
        let LoginPage::Form {
            captcha: Some(challenge),
            ..
        } = &page
        else {
            clear_original_pending();
            return Err(AppError::session_expired());
        };
        let challenge = challenge.clone();
        let text_supported = auth::cas::text_captcha_supported(&challenge);
        let image = if text_supported {
            auth::challenge::image(&self.session, &challenge.id).await?
        } else {
            vec![]
        };
        {
            let mut identity = self.identity.lock();
            if identity.generation != generation
                || identity.pending_login.as_ref().is_none_or(|pending| {
                    !pending.belongs_to(&account, generation)
                        || pending.created != created
                        || (!refresh && !pending.valid(&account, generation))
                })
            {
                return Err(AppError::session_expired());
            }
            identity.pending_login = Some(PendingLogin {
                page,
                route: self.session.route(),
                account: account.clone(),
                generation,
                created: if refresh { Instant::now() } else { created },
            });
        }
        let identity = self.identity.lock();
        if identity.generation != generation
            || identity.pending_login.as_ref().is_none_or(|pending| {
                !pending.valid(&account, generation)
                    || !matches!(&pending.page,
                LoginPage::Form { captcha: Some(current), .. } if current.id == challenge.id)
            })
        {
            return Err(AppError::session_expired());
        }
        Ok(LoginChallengeData {
            challenge_id: challenge.id,
            challenge_type: challenge.captcha_type,
            text_supported,
            image,
        })
    }

    async fn gateway_challenge(
        &self,
        expected_id: Option<&str>,
        refresh: bool,
    ) -> Result<Option<LoginChallengeData>, AppError> {
        self.read_gateway_challenge(expected_id, refresh).await
    }

    async fn resume_gateway_login(&self, expected_id: &str, answer: &str) -> Result<(), AppError> {
        self.answer_gateway_challenge(expected_id, answer).await
    }

    fn status(&self) -> SessionStatus {
        let identity = self.identity.lock();
        SessionStatus {
            account: identity
                .authenticated
                .as_ref()
                .map(|user| user.account.clone()),
            profile: identity
                .authenticated
                .as_ref()
                .map(|user| user.profile.clone()),
            route: self.preference(),
        }
    }

    /// Route changes invalidate the cookie jars and cached snapshots, matching
    /// the Apple rule that direct and WebVPN sessions never mix.
    fn set_route(&self, preference: RoutePreference) {
        let changed = {
            let mut route = lock_value(&self.route);
            let changed = *route != preference;
            *route = preference;
            changed
        };
        if changed {
            self.clear_identity();
        }
        self.route_initialized.store(true, Ordering::Release);
        if changed || self.identity.lock().authenticated.is_none() {
            self.session.set_route(preference.into());
        }
    }

    async fn apply_route_change(&self, preference: RoutePreference) -> Result<(), AppError> {
        let changed = self.preference() != preference;
        if changed && self.route_initialized.load(Ordering::Acquire) {
            // A user-selected route change invalidates the old persisted jars
            // before changing the live preference. If secure deletion fails,
            // keep the old route active and surface the storage error.
            self.delete_persisted_session().await?;
        }
        self.set_route(preference);
        Ok(())
    }

    async fn sign_in(
        &self,
        account: &str,
        password: &str,
        captcha: Option<&str>,
        remember: bool,
    ) -> Result<SessionOutcome, AppError> {
        let account = account.trim();
        if account.is_empty() || password.is_empty() {
            return Err(AppError::invalid());
        }
        // A manual login begins a new session lifetime. Revoke the previously
        // persisted cookie snapshot before attempting a different login so an
        // interrupted/failed attempt cannot silently restore the old account.
        self.delete_persisted_session().await?;
        let switching_account = self
            .identity
            .lock()
            .authenticated
            .as_ref()
            .is_some_and(|current| current.account != account);
        if switching_account {
            self.clear_identity();
        }
        let credentials = Credentials {
            username: account.to_owned(),
            password: password.to_owned(),
            captcha_text: captcha
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_owned),
        };
        let (pending, generation) = {
            let mut identity = self.identity.lock();
            (identity.pending_login.take(), identity.generation)
        };
        let mut credentials = credentials;
        // A challenge that merely timed out still belongs to this sign-in:
        // drop the answer and hand back the new captcha instead of ending the
        // attempt with "school session expired". A challenge that belongs to
        // another account or an older session is never replaced silently.
        let timed_out = pending.as_ref().is_some_and(|page| {
            page.belongs_to(account, generation) && !page.valid(account, generation)
        });
        let page = match pending {
            Some(page) if page.valid(account, generation) => {
                self.session.set_route(page.route);
                page.page
            }
            _ => {
                if credentials.captcha_text.is_some() && !timed_out {
                    return Err(AppError::session_expired());
                }
                credentials.captcha_text = None;
                self.session.set_route(self.preference().into());
                auth::fetch_login_page(&self.session).await?
            }
        };
        match auth::complete_login(&self.session, &credentials, page).await {
            Ok(LoginResult::CaptchaRequired { challenge, page }) => {
                let mut identity = self.identity.lock();
                if identity.generation != generation {
                    return Err(AppError::session_expired());
                }
                // Keep the page the school just re-rendered: its `execution`
                // token is the one the answer must be submitted with.
                identity.pending_login = Some(PendingLogin {
                    page,
                    route: self.session.route(),
                    account: account.to_owned(),
                    generation,
                    created: Instant::now(),
                });
                Ok(SessionOutcome::CaptchaRequired(challenge))
            }
            Ok(LoginResult::SignedIn(profile)) => {
                self.clear_automatic_login_failure();
                let canonical_account = profile.school_id.clone();
                let remembered = if remember {
                    let saved = self.vault.save(&canonical_account, &credentials).is_ok();
                    if saved && canonical_account != account {
                        let _ = self.vault.delete(account);
                    }
                    saved
                } else {
                    let _ = self.vault.delete(&canonical_account);
                    if canonical_account != account {
                        let _ = self.vault.delete(account);
                    }
                    false
                };
                self.clear_caches();
                self.set_authenticated(canonical_account, profile.clone());
                // set_authenticated resets the record; re-seat the credential
                // afterwards so the gateway can be opened in the same session.
                self.remember_session_credentials(&credentials);
                // Session persistence is independent from the optional saved
                // password. A Keystore failure does not turn a valid login
                // into a failed school authentication.
                let _ = self.persist_active_session().await;
                Ok(SessionOutcome::SignedIn {
                    profile,
                    remembered,
                })
            }
            Err(error) => {
                self.identity.lock().pending_login = None;
                Err(error)
            }
        }
    }

    /// Restore after process start. The in-memory cookies are validated first;
    /// a saved account is only re-logged-in when that confirmation fails.
    async fn restore(&self) -> Result<SessionOutcome, AppError> {
        if self.identity.lock().authenticated.is_none() {
            self.session.set_route(self.preference().into());
        }
        match self.load_persisted_session().await {
            Ok(Some(saved)) => {
                if !saved.is_usable_for(
                    self.preference().into(),
                    crate::foundation::cookie::CookieJar::now_ms(),
                ) {
                    if saved.route == super::RouteMode::Automatic {
                        // The old format cannot identify the authenticated
                        // route. Ask for one explicit login instead of probing
                        // both jars or silently submitting a saved password.
                        return Ok(SessionOutcome::SignedOut);
                    }
                    let _ = self.delete_persisted_session().await;
                } else {
                    let account = saved.account.clone();
                    self.session.set_route(saved.route);
                    self.session.restore_cookies(saved.cookies);
                    match auth::validate_session(&self.session).await {
                        Ok(profile) if profile.school_id.eq_ignore_ascii_case(&account) => {
                            self.clear_caches();
                            // Cookie authentication already succeeded. The
                            // optional password entry cannot invalidate it.
                            let remembered =
                                self.vault.load(&account).is_ok_and(|entry| entry.is_some());
                            self.set_authenticated(account, profile.clone());
                            self.identity.lock().persisted_started_at_ms = saved.saved_at_ms;
                            let _ = self.persist_active_session().await;
                            return Ok(SessionOutcome::SignedIn {
                                profile,
                                remembered,
                            });
                        }
                        Ok(_) => {
                            self.clear_identity();
                            let _ = self.delete_persisted_session().await;
                            return Ok(SessionOutcome::SignedOut);
                        }
                        Err(error) if error.code == ErrorCode::SessionExpired => {
                            self.clear_identity();
                            let _ = self.delete_persisted_session().await;
                        }
                        Err(error) => return Err(error),
                    }
                }
            }
            Ok(None) => {}
            // A locked/unreadable vault is not evidence of expiry. Keep the
            // saved session intact and let the caller offer a local retry.
            Err(error) => return Err(error),
        }
        let account = self
            .identity
            .lock()
            .authenticated
            .as_ref()
            .map(|user| user.account.clone());
        let has_cookies =
            self.session.direct_cookie_present() || self.session.webvpn_cookie_present();
        if let Some(account) = account.filter(|_| has_cookies) {
            match auth::validate_session(&self.session).await {
                Ok(profile) if profile.school_id == account => {
                    self.update_profile(&account, profile.clone())?;
                    return Ok(SessionOutcome::SignedIn {
                        profile,
                        remembered: self.vault.load(&account).is_ok_and(|entry| entry.is_some()),
                    });
                }
                // The cookie jar no longer belongs to the published account.
                // Drop it and fall through to the saved-credential flow rather
                // than rebinding the profile of a different login.
                Ok(_) => self.clear_identity(),
                Err(error) if error.code == ErrorCode::SessionExpired => {}
                // The directory being unreachable says nothing about the
                // school session: keep the saved identity instead of forcing
                // the user back to the login page.
                Err(error) if auth::directory_unavailable(&error) => {
                    let profile = self
                        .identity
                        .lock()
                        .authenticated
                        .as_ref()
                        .map(|user| user.profile.clone());
                    if let Some(profile) = profile {
                        return Ok(SessionOutcome::SignedIn {
                            profile,
                            remembered: self
                                .vault
                                .load(&account)
                                .is_ok_and(|entry| entry.is_some()),
                        });
                    }
                }
                Err(error) => return Err(error),
            }
        }

        let accounts = match self.vault.accounts() {
            Ok(accounts) => accounts,
            Err(_) => return Ok(SessionOutcome::SignedOut),
        };
        // A startup must never cycle through saved accounts and submit several
        // passwords. Further account selection belongs to explicit sign-in.
        let Some(account) = accounts.into_iter().next() else {
            return Ok(SessionOutcome::SignedOut);
        };
        let credentials = match self.vault.load(&account) {
            Ok(Some(credentials)) => credentials,
            Ok(None) | Err(_) => return Ok(SessionOutcome::SignedOut),
        };
        let page = auth::fetch_login_page(&self.session).await?;
        match auth::complete_login(&self.session, &credentials, page).await {
            Ok(LoginResult::SignedIn(profile)) => {
                self.clear_automatic_login_failure();
                self.clear_caches();
                self.set_authenticated(credentials.username.clone(), profile.clone());
                self.remember_session_credentials(&credentials);
                let _ = self.persist_active_session().await;
                Ok(SessionOutcome::SignedIn {
                    profile,
                    remembered: true,
                })
            }
            Ok(LoginResult::CaptchaRequired { challenge, page }) => {
                let mut identity = self.identity.lock();
                let generation = identity.generation;
                identity.pending_login = Some(PendingLogin {
                    page,
                    route: self.session.route(),
                    account: credentials.username,
                    generation,
                    created: Instant::now(),
                });
                Ok(SessionOutcome::CaptchaRequired(challenge))
            }
            Err(error) if error.code == ErrorCode::InvalidCredentials => {
                let _ = self.vault.delete(&account);
                Ok(SessionOutcome::SignedOut)
            }
            Err(error) => Err(error),
        }
    }

    /// Local sign-out never waits for an upstream round trip. Identity,
    /// cookies, snapshots and the saved password are always cleared.
    async fn sign_out(&self) {
        self.forgotten_account.lock().take();
        let account = {
            let mut identity = self.identity.lock();
            let account = identity.authenticated.take().map(|user| user.account);
            *identity = Identity {
                generation: identity.generation.wrapping_add(1),
                ..Identity::default()
            };
            account
        };
        // Remember the account for the credential purge, which runs after the
        // caller has released its gate. A route change or failed restore can
        // already have cleared identity, so both may be empty.
        *self.forgotten_account.lock() = account;
        self.session.clear_cookies();
        self.clear_identity();
    }

    /// Remove every saved password. This is a JNI round trip into Keystore
    /// followed by a blocking `SharedPreferences.commit()`, so it runs on a
    /// blocking thread and never under the caller's session gate.
    async fn purge_credentials(&self) {
        if self.delete_persisted_session().await.is_err() {
            let _ = self.delete_persisted_session().await;
        }
        // An enumeration failure defaults to knowing only the signed-in
        // account; Android vault no longer reports that failure as an empty
        // list. Explicit logout must still remove saved accounts so nothing
        // can be restored.
        let mut accounts = self.vault.accounts().unwrap_or_default();
        if let Some(account) = self.forgotten_account.lock().take() {
            if !accounts.contains(&account) {
                accounts.push(account);
            }
        }
        if accounts.is_empty() {
            return;
        }
        // Deletes are idempotent local keychain operations; one retry covers a
        // transient Keystore/keychain failure. The caller runs this *after*
        // releasing its session gate, so a slow `commit()` delays only this
        // command; every queued read proceeds.
        for account in accounts {
            if self.vault.delete(&account).is_err() {
                let _ = self.vault.delete(&account);
            }
        }
    }

    /// Clear all read snapshots without touching credentials or the session.
    fn clear_snapshots(&self) {
        self.clear_caches();
    }

    fn account(&self) -> Result<String, AppError> {
        self.current_account()
    }
}
