//! Windows Credential Manager / macOS Keychain adapter.
//!
//! The credential blob is JSON; the account list is stored in a separate
//! keychain entry so restore can find a saved account without scanning or
//! persisting student IDs elsewhere.
use crate::{
    auth::{vault::sanitized, CredentialSource, CredentialVault, Credentials},
    AppError,
};
use keyring::{Entry, Error as KeyringError};
use std::sync::Mutex;

const SERVICE: &str = "cn.edu.buaa.ginkgo.mirror";
const INDEX: &str = "__ginkgo_accounts__";

pub struct KeyringVault {
    index_lock: Mutex<()>,
}

impl KeyringVault {
    pub fn new() -> Result<Self, AppError> {
        Ok(Self {
            index_lock: Mutex::new(()),
        })
    }

    fn entry(account: &str) -> Result<Entry, AppError> {
        Entry::new(SERVICE, account).map_err(|_| AppError::credential_store())
    }

    fn index_entry() -> Result<Entry, AppError> {
        Entry::new(SERVICE, INDEX).map_err(|_| AppError::credential_store())
    }

    fn write_index(&self, accounts: &[String]) -> Result<(), AppError> {
        let _guard = self
            .index_lock
            .lock()
            .map_err(|_| AppError::credential_store())?;
        let payload = serde_json::to_string(accounts).map_err(|_| AppError::credential_store())?;
        Self::index_entry()?
            .set_password(&payload)
            .map_err(|_| AppError::credential_store())
    }
}

impl CredentialSource for KeyringVault {
    fn load(&self, account: &str) -> Result<Option<Credentials>, AppError> {
        match Self::entry(account)?.get_password() {
            Ok(payload) => serde_json::from_str(&payload)
                .map(Some)
                .map_err(|_| AppError::credential_store()),
            Err(KeyringError::NoEntry) => Ok(None),
            Err(_) => Err(AppError::credential_store()),
        }
    }
}

impl CredentialVault for KeyringVault {
    fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError> {
        let payload = serde_json::to_string(&sanitized(credentials))
            .map_err(|_| AppError::credential_store())?;
        Self::entry(account)?
            .set_password(&payload)
            .map_err(|_| AppError::credential_store())?;
        let mut accounts = self.accounts()?;
        if !accounts.iter().any(|saved| saved == account) {
            accounts.push(account.to_owned());
            self.write_index(&accounts)?;
        }
        Ok(())
    }

    fn delete(&self, account: &str) -> Result<(), AppError> {
        match Self::entry(account)?.delete_credential() {
            Ok(()) | Err(KeyringError::NoEntry) => {}
            Err(_) => return Err(AppError::credential_store()),
        }
        let mut accounts = self.accounts()?;
        if accounts.iter().any(|saved| saved == account) {
            accounts.retain(|saved| saved != account);
            self.write_index(&accounts)?;
        }
        Ok(())
    }

    fn accounts(&self) -> Result<Vec<String>, AppError> {
        match Self::index_entry()?.get_password() {
            Ok(payload) => serde_json::from_str::<Vec<String>>(&payload)
                .map_err(|_| AppError::credential_store()),
            Err(KeyringError::NoEntry) => Ok(Vec::new()),
            Err(_) => Err(AppError::credential_store()),
        }
    }
}
