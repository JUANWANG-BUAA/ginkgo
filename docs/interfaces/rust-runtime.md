# 组装（ginkgo_runtime）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

连接 core 与真实学校/平台实现；平台保险库选择。

## lib

- `pub type AppService = Workspace<SchoolClient<ReqwestTransport, PlatformVault>>;`  
  <sub>rust/crates/ginkgo_runtime/src/lib.rs:14</sub>
- `pub fn library_loans_portal_url() -> String { ginkgo_upstream::adapters::library_loans_http::portal_url() }`  
  <sub>rust/crates/ginkgo_runtime/src/lib.rs:16</sub>
- `pub fn create_service() -> Result<AppService, AppError> { let transport = ReqwestTransport::new().map_err(\|_\| AppError::unavailable())?; Ok(Workspace…` — Called lazily on the first command, never while Flutter initializes.  
  <sub>rust/crates/ginkgo_runtime/src/lib.rs:21</sub>
- `pub fn has_saved_accounts() -> Result<bool, AppError> { Ok(!platform_vault()?.accounts()?.is_empty()) }`  
  <sub>rust/crates/ginkgo_runtime/src/lib.rs:29</sub>
- `pub fn verify_credential_storage(account: &str, secret: &str) -> bool { platform_vault().is_ok_and(\|vault\| { ginkgo_upstream::auth::vault::verify_vau…`  
  <sub>rust/crates/ginkgo_runtime/src/lib.rs:33</sub>
- `pub async fn check_update( current: &str, ) -> Result<ginkgo_core::features::updates::UpdateSummary, AppError> { static TRANSPORT: OnceLock<Result<Re…`  
  <sub>rust/crates/ginkgo_runtime/src/lib.rs:39</sub>
