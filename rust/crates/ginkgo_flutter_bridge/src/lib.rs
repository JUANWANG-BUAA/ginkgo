pub mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

/// JVM entry point for the Android credential vault. Flutter loads this
/// library from Dart, which does not run `JNI_OnLoad`; `MainActivity` calls
/// `System.loadLibrary` first so the app class loader is available here.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(
    vm: *mut core::ffi::c_void,
    _reserved: *mut core::ffi::c_void,
) -> i32 {
    unsafe { ginkgo_core::auth::platform::jni_on_load(vm) }
}
