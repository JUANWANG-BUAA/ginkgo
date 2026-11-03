//! Credential-vault test doubles.
//!
//! Production implementations live in [`super::platform`]; the in-memory vault
//! exists so mock-HTTP tests can exercise login and recovery without touching
//! a real keychain.
use super::{session::PersistedSession, CredentialSource, CredentialVault, Credentials};
use crate::foundation::mutex::Mutex;
use crate::AppError;
use std::{collections::BTreeMap, sync::Arc};

#[derive(Clone, Default)]
pub struct MemoryVault {
    entries: Arc<Mutex<BTreeMap<String, Credentials>>>,
    session: Arc<Mutex<Option<PersistedSession>>>,
}

impl MemoryVault {
    pub fn with(account: &str, credentials: Credentials) -> Self {
        let vault = Self::default();
        vault.entries.lock().insert(account.to_owned(), credentials);
        vault
    }

    pub fn names(&self) -> Vec<String> {
        self.entries.lock().keys().cloned().collect()
    }
}

impl CredentialSource for MemoryVault {
    fn load(&self, account: &str) -> Result<Option<Credentials>, AppError> {
        Ok(self.entries.lock().get(account).cloned())
    }
}

impl CredentialVault for MemoryVault {
    fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError> {
        self.entries
            .lock()
            .insert(account.to_owned(), sanitized(credentials));
        Ok(())
    }

    fn delete(&self, account: &str) -> Result<(), AppError> {
        self.entries.lock().remove(account);
        Ok(())
    }

    fn accounts(&self) -> Result<Vec<String>, AppError> {
        Ok(self.names())
    }

    fn save_session(&self, session: &PersistedSession) -> Result<(), AppError> {
        *self.session.lock() = Some(session.clone());
        Ok(())
    }

    fn load_session(&self) -> Result<Option<PersistedSession>, AppError> {
        Ok(self.session.lock().clone())
    }

    fn delete_session(&self) -> Result<(), AppError> {
        *self.session.lock() = None;
        Ok(())
    }

    fn has_session(&self) -> Result<bool, AppError> {
        Ok(self.session.lock().is_some())
    }
}

/// Write, read back and remove one synthetic credential. The reserved prefix
/// prevents callers from replacing or deleting a real saved account.
pub fn verify_vault_round_trip<V: CredentialVault + ?Sized>(
    vault: &V,
    account: &str,
    secret: &str,
) -> bool {
    const DIAGNOSTIC_PREFIX: &str = "__ginkgo_vault_test__";
    if !account.starts_with(DIAGNOSTIC_PREFIX) {
        return false;
    }
    let credentials = Credentials {
        username: account.to_owned(),
        password: secret.to_owned(),
        captcha_text: None,
    };
    if vault.save(account, &credentials).is_err() {
        return false;
    }
    let ok = matches!(
        vault.load(account),
        Ok(Some(saved)) if saved.password == secret
    );
    let deleted = vault.delete(account).is_ok();
    let absent = matches!(vault.load(account), Ok(None));
    ok && deleted && absent
}

/// Captcha answers are one-time and must never be persisted.
pub(crate) fn sanitized(credentials: &Credentials) -> Credentials {
    Credentials {
        username: credentials.username.clone(),
        password: credentials.password.clone(),
        captcha_text: None,
    }
}

#[cfg(test)]
mod diagnostic_tests {
    use super::*;
    struct StickyVault(MemoryVault);
    impl CredentialSource for StickyVault {
        fn load(&self, account: &str) -> Result<Option<Credentials>, AppError> {
            self.0.load(account)
        }
    }
    impl CredentialVault for StickyVault {
        fn save(&self, account: &str, value: &Credentials) -> Result<(), AppError> {
            self.0.save(account, value)
        }
        fn delete(&self, _: &str) -> Result<(), AppError> {
            Ok(())
        }
        fn accounts(&self) -> Result<Vec<String>, AppError> {
            self.0.accounts()
        }
    }
    #[test]
    fn diagnostic_does_not_pass_when_delete_silently_leaves_data() {
        assert!(!verify_vault_round_trip(
            &StickyVault(MemoryVault::default()),
            "__ginkgo_vault_test__sticky",
            "synthetic"
        ));
    }
}
