//! Platform credential-vault adapters.
//!
//! Android uses the Android Keystore through a small Kotlin bridge; Windows and
//! macOS use the system keychain. Other targets deliberately fail closed rather
//! than falling back to a plaintext store.
#[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
use super::{CredentialSource, CredentialVault, Credentials};
use crate::AppError;

#[cfg(target_os = "android")]
mod android_vault;
#[cfg(any(target_os = "windows", target_os = "macos"))]
mod keyring_vault;

#[cfg(target_os = "android")]
pub use android_vault::{jni_on_load, AndroidVault as PlatformVault};
#[cfg(any(target_os = "windows", target_os = "macos"))]
pub use keyring_vault::KeyringVault as PlatformVault;

#[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
pub use UnsupportedVault as PlatformVault;

/// Build the vault for the current platform. Android's JNI class handle is
/// installed during `JNI_OnLoad`; no per-call initialization is required.
pub fn platform_vault() -> Result<PlatformVault, AppError> {
    PlatformVault::new()
}

#[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
pub struct UnsupportedVault;

#[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
impl UnsupportedVault {
    fn new() -> Result<Self, AppError> {
        Err(AppError::credential_store())
    }
}

#[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
impl CredentialSource for UnsupportedVault {
    fn load(&self, _account: &str) -> Result<Option<Credentials>, AppError> {
        Err(AppError::credential_store())
    }
}

#[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
impl CredentialVault for UnsupportedVault {
    fn save(&self, _account: &str, _credentials: &Credentials) -> Result<(), AppError> {
        Err(AppError::credential_store())
    }

    fn delete(&self, _account: &str) -> Result<(), AppError> {
        Err(AppError::credential_store())
    }

    fn accounts(&self) -> Result<Vec<String>, AppError> {
        Err(AppError::credential_store())
    }
}
