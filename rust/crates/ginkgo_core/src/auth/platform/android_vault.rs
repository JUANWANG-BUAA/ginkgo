//! Android Keystore adapter.
//!
//! Java/Kotlin cannot be instantiated from a Dart-loaded library without a JNI
//! entry point, so `MainActivity` calls `System.loadLibrary` once; `JNI_OnLoad`
//! caches the app class loader's `CredentialVault` class. All encryption and
//! `SharedPreferences` access stays in Kotlin.
use crate::{
    auth::{vault::sanitized, CredentialSource, CredentialVault, Credentials},
    AppError,
};
use jni::{
    objects::{GlobalRef, JString, JValue},
    sys::{jint, JNI_ERR, JNI_VERSION_1_6},
    JNIEnv, JavaVM,
};
use std::{ffi::c_void, sync::OnceLock};

const VAULT_CLASS: &str = "cn/edu/buaa/ginkgo/ginkgo_mirror/CredentialVault";
static VM: OnceLock<JavaVM> = OnceLock::new();
static CLASS: OnceLock<GlobalRef> = OnceLock::new();

/// Called by the bridge crate's exported `JNI_OnLoad`.
///
/// # Safety
/// `vm` must be the raw `JavaVM*` supplied by the JVM to `JNI_OnLoad`.
pub unsafe fn jni_on_load(vm: *mut c_void) -> jint {
    let Ok(vm) = JavaVM::from_raw(vm.cast()) else {
        return JNI_ERR;
    };
    let Ok(mut env) = vm.get_env() else {
        return JNI_ERR;
    };
    let Ok(class) = env.find_class(VAULT_CLASS) else {
        return JNI_ERR;
    };
    let Ok(global) = env.new_global_ref(class) else {
        return JNI_ERR;
    };
    if CLASS.set(global).is_err() || VM.set(vm).is_err() {
        return JNI_ERR;
    }
    JNI_VERSION_1_6
}

pub struct AndroidVault;

impl AndroidVault {
    pub fn new() -> Result<Self, AppError> {
        Ok(Self)
    }

    fn with_env<R>(action: impl FnOnce(&mut JNIEnv) -> Result<R, AppError>) -> Result<R, AppError> {
        let vm = VM.get().ok_or_else(AppError::credential_store)?;
        let mut env = vm
            .attach_current_thread()
            .map_err(|_| AppError::credential_store())?;
        action(&mut env)
    }

    fn call_bool(
        env: &mut JNIEnv,
        method: &str,
        signature: &str,
        args: &[JValue],
    ) -> Result<bool, AppError> {
        let class = CLASS.get().ok_or_else(AppError::credential_store)?;
        match env.call_static_method(class, method, signature, args) {
            Ok(value) => value.z().map_err(|_| AppError::credential_store()),
            Err(_) => {
                // Never surface a Java exception message: it may contain data.
                let _ = env.exception_clear();
                Err(AppError::credential_store())
            }
        }
    }

    fn call_string(
        env: &mut JNIEnv,
        method: &str,
        signature: &str,
        args: &[JValue],
    ) -> Result<Option<String>, AppError> {
        let class = CLASS.get().ok_or_else(AppError::credential_store)?;
        let value = match env.call_static_method(class, method, signature, args) {
            Ok(value) => value,
            Err(_) => {
                let _ = env.exception_clear();
                return Err(AppError::credential_store());
            }
        };
        let object = value.l().map_err(|_| AppError::credential_store())?;
        if object.is_null() {
            return Ok(None);
        }
        env.get_string(&JString::from(object))
            .map(|text| Some(String::from(text)))
            .map_err(|_| AppError::credential_store())
    }

    fn argument<'local>(
        env: &mut JNIEnv<'local>,
        value: &str,
    ) -> Result<JString<'local>, AppError> {
        env.new_string(value)
            .map_err(|_| AppError::credential_store())
    }
}

impl CredentialSource for AndroidVault {
    fn load(&self, account: &str) -> Result<Option<Credentials>, AppError> {
        let payload = Self::with_env(|env| {
            let account = Self::argument(env, account)?;
            Self::call_string(
                env,
                "load",
                "(Ljava/lang/String;)Ljava/lang/String;",
                &[JValue::Object(&account)],
            )
        })?;
        payload
            .map(|payload| serde_json::from_str(&payload).map_err(|_| AppError::credential_store()))
            .transpose()
    }
}

impl CredentialVault for AndroidVault {
    fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError> {
        let payload = serde_json::to_string(&sanitized(credentials))
            .map_err(|_| AppError::credential_store())?;
        let saved = Self::with_env(|env| {
            let account = Self::argument(env, account)?;
            let payload = Self::argument(env, &payload)?;
            Self::call_bool(
                env,
                "save",
                "(Ljava/lang/String;Ljava/lang/String;)Z",
                &[JValue::Object(&account), JValue::Object(&payload)],
            )
        })?;
        if saved {
            Ok(())
        } else {
            Err(AppError::credential_store())
        }
    }

    fn delete(&self, account: &str) -> Result<(), AppError> {
        let deleted = Self::with_env(|env| {
            let account = Self::argument(env, account)?;
            Self::call_bool(
                env,
                "delete",
                "(Ljava/lang/String;)Z",
                &[JValue::Object(&account)],
            )
        })?;
        if deleted {
            Ok(())
        } else {
            Err(AppError::credential_store())
        }
    }

    fn accounts(&self) -> Result<Vec<String>, AppError> {
        let payload =
            Self::with_env(|env| Self::call_string(env, "accounts", "()Ljava/lang/String;", &[]))?;
        match payload {
            Some(payload) => {
                serde_json::from_str(&payload).map_err(|_| AppError::credential_store())
            }
            None => Ok(Vec::new()),
        }
    }
}
