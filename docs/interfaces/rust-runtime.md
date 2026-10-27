# 组装（ginkgo_runtime）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

连接 core 与真实学校/平台实现；平台保险库选择。

## lib

- `pub type AppService = Workspace<SchoolClient<ReqwestTransport, PlatformVault>>;`  
  <sub>type · rust/crates/ginkgo_runtime/src/lib.rs:14</sub>
- `pub fn library_loans_portal_url() -> String {…}`  
  <sub>fn · rust/crates/ginkgo_runtime/src/lib.rs:16</sub>
- `pub fn create_service() -> Result<AppService, AppError> {…}` — Called lazily on the first command, never while Flutter initializes.  
  <sub>fn · rust/crates/ginkgo_runtime/src/lib.rs:21</sub>
- `pub fn has_saved_accounts() -> Result<bool, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_runtime/src/lib.rs:29</sub>
- `pub fn verify_credential_storage(account: &str, secret: &str) -> bool {…}`  
  <sub>fn · rust/crates/ginkgo_runtime/src/lib.rs:33</sub>
- `pub async fn check_update( current: &str, ) -> Result<ginkgo_core::features::updates::UpdateSummary, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_runtime/src/lib.rs:39</sub>
