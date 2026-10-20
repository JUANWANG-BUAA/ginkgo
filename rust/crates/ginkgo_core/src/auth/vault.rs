//! Credential-vault test doubles.
//!
//! Production implementations live in [`super::platform`]; the in-memory vault
//! exists so mock-HTTP tests can exercise login and recovery without touching
//! a real keychain.
use super::{CredentialSource, CredentialVault, Credentials};
use crate::AppError;
use std::{collections::BTreeMap, sync::Mutex};

#[derive(Default)]
pub struct MemoryVault {
    entries: Mutex<BTreeMap<String, Credentials>>,
}

impl MemoryVault {
    pub fn with(account: &str, credentials: Credentials) -> Self {
        let vault = Self::default();
        vault
            .entries
            .lock()
            .expect("memory vault")
            .insert(account.to_owned(), credentials);
        vault
    }

    pub fn names(&self) -> Vec<String> {
        self.entries
            .lock()
            .expect("memory vault")
            .keys()
            .cloned()
            .collect()
    }
}

impl CredentialSource for MemoryVault {
    fn load(&self, account: &str) -> Result<Option<Credentials>, AppError> {
        Ok(self
            .entries
            .lock()
            .expect("memory vault")
            .get(account)
            .cloned())
    }
}

impl CredentialVault for MemoryVault {
    fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError> {
        self.entries
            .lock()
            .expect("memory vault")
            .insert(account.to_owned(), sanitized(credentials));
        Ok(())
    }

    fn delete(&self, account: &str) -> Result<(), AppError> {
        self.entries.lock().expect("memory vault").remove(account);
        Ok(())
    }

    fn accounts(&self) -> Result<Vec<String>, AppError> {
        Ok(self.names())
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
    let _ = vault.delete(account);
    ok
}

/// Captcha answers are one-time and must never be persisted.
pub(crate) fn sanitized(credentials: &Credentials) -> Credentials {
    Credentials {
        username: credentials.username.clone(),
        password: credentials.password.clone(),
        captcha_text: None,
    }
}
