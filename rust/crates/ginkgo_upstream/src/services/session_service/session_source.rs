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
use std::time::Instant;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionSource for SchoolClient<T, V> {
    async fn login_challenge(
        &self,
        expected_id: Option<&str>,
        refresh: bool,
    ) -> Result<LoginChallengeData, AppError> {
        let (page, account, generation, created) = {
            let mut identity = self.identity.lock();
            let pending = identity
                .pending_login
                .as_ref()
                .ok_or_else(AppError::session_expired)?;
            if !pending.valid(&pending.account, identity.generation) {
                identity.pending_login = None;
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
            (
                pending.page.clone(),
                pending.account.clone(),
                pending.generation,
                pending.created,
            )
        };
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
                Err(error) => {
                    clear_original_pending();
                    return Err(error);
                }
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
        {
            let mut identity = self.identity.lock();
            if identity.generation != generation
                || identity
                    .pending_login
                    .as_ref()
                    .is_none_or(|pending| !pending.valid(&account, generation))
            {
                return Err(AppError::session_expired());
            }
            identity.pending_login = Some(PendingLogin {
                page,
                account: account.clone(),
                generation,
                created: if refresh { Instant::now() } else { created },
            });
        }
        let image = if text_supported {
            auth::challenge::image(&self.session, &challenge.id).await?
        } else {
            vec![]
        };
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
        self.session.set_route(preference.into());
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
        let switching_account = self
            .identity
            .lock()
            .authenticated
            .as_ref()
            .is_some_and(|current| current.account != account);
        if switching_account {
            self.clear_identity();
        }
        self.session.set_route(self.preference().into());
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
        let page = match pending.filter(|page| page.valid(account, generation)) {
            Some(pending) => pending.page,
            None => {
                // A stale answer must never be submitted against a newly fetched page.
                if credentials.captcha_text.is_some() {
                    return Err(AppError::session_expired());
                }
                auth::fetch_login_page(&self.session).await?
            }
        };
        let retry_page = page.clone();
        match auth::complete_login(&self.session, &credentials, page).await {
            Ok(LoginResult::CaptchaRequired(challenge)) => {
                let mut identity = self.identity.lock();
                if identity.generation != generation {
                    return Err(AppError::session_expired());
                }
                identity.pending_login = Some(PendingLogin {
                    page: retry_page,
                    account: account.to_owned(),
                    generation,
                    created: Instant::now(),
                });
                Ok(SessionOutcome::CaptchaRequired(challenge))
            }
            Ok(LoginResult::SignedIn(profile)) => {
                self.clear_automatic_login_failure();
                let remembered = if remember {
                    self.vault.save(account, &credentials).is_ok()
                } else {
                    let _ = self.vault.delete(account);
                    false
                };
                self.clear_caches();
                self.set_authenticated(account.to_owned(), profile.clone());
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
        self.session.set_route(self.preference().into());
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
                        remembered: true,
                    });
                }
                // The cookie jar no longer belongs to the published account.
                // Drop it and fall through to the saved-credential flow rather
                // than rebinding the profile of a different login.
                Ok(_) => self.clear_identity(),
                Err(error) if error.code == ErrorCode::SessionExpired => {}
                Err(error) => return Err(error),
            }
        }

        let accounts = match self.vault.accounts() {
            Ok(accounts) => accounts,
            Err(_) => return Ok(SessionOutcome::SignedOut),
        };
        for account in accounts.into_iter().take(5) {
            let credentials = match self.vault.load(&account) {
                Ok(Some(credentials)) => credentials,
                Ok(None) | Err(_) => continue,
            };
            let page = auth::fetch_login_page(&self.session).await?;
            match auth::complete_login(&self.session, &credentials, page.clone()).await {
                Ok(LoginResult::SignedIn(profile)) => {
                    self.clear_automatic_login_failure();
                    self.clear_caches();
                    self.set_authenticated(credentials.username, profile.clone());
                    return Ok(SessionOutcome::SignedIn {
                        profile,
                        remembered: true,
                    });
                }
                Ok(LoginResult::CaptchaRequired(challenge)) => {
                    let mut identity = self.identity.lock();
                    let generation = identity.generation;
                    identity.pending_login = Some(PendingLogin {
                        page,
                        account: credentials.username,
                        generation,
                        created: Instant::now(),
                    });
                    return Ok(SessionOutcome::CaptchaRequired(challenge));
                }
                Err(error) if error.code == ErrorCode::InvalidCredentials => {
                    let _ = self.vault.delete(&account);
                }
                Err(error) => return Err(error),
            }
        }
        Ok(SessionOutcome::SignedOut)
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
