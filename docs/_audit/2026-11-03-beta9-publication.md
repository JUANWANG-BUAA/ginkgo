# Android Beta.9 发布记录

用户在源码对齐后明确要求“收尾发包”。本轮继续沿用用户明确指令的手动发布例外，readiness 保持 `blocked`，不改为契约验收通过。

## 候选

- 版本 `0.1.0-beta.9+19`，标签计划为 `android-v0.1.0-beta.9`。
- 范围仅为认证网络链及对应回归源码、协议说明；参考固定 UBAA `e8a397fc`，详见 [源码对照](2026-11-03-webvpn-captcha-source-comparison.md)。不改 Swift，不额外提交直连密码，不降低 TLS/身份/Cookie 作用域边界。
- `cargo fmt --all --manifest-path rust/Cargo.toml` 成功；`cargo check --manifest-path rust/Cargo.toml -p ginkgo_upstream --tests --offline --locked` 成功。首次不带 `--all` 的虚拟 workspace 格式化命令未找到 target，改用正确命令后成功，没有将第一次失败记为通过。
- 本轮本地没有执行测试用例、学校请求、真实账号、应用或模拟器操作。编译不能替代测试通过；既往 Beta.8/参考捕获的通过记录不外推到本候选。
- 正常 `lib/main.dart`、ARM64、外部发布签名 Release 构建成功。aapt 确认版本 `0.1.0-beta.9` / versionCode 19、正常 MainActivity、非 debuggable、仅 arm64-v8a；生产插件注册表不含 integration_test；zipalign 16KiB 校验成功。
- APK 44,245,313 字节，SHA-256 `3fed839d2393b6abf3ca46e7f8e7c1ba8d6d7d18bfa74d286341ee07cfd0c713`；apksigner 验证通过，证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245` 与 Beta.8 一致。
- 协议锁按 API 修订 115/116 与对应源码完成审查后刷新，未修改独立参考捕获；生成接口索引同步。`check-contracts.py --release` 仍明确失败：readiness blocked、候选不匹配旧验收、缺账号/设备/写入/人审等证据；没有将该结果改成通过。
- 公开下载、校验和、代码推送及 CI 结果收齐后补充。

## 保留边界

物理设备、验证码实机成功、冷恢复、学校写入及维护者安全审查仍未完成；不提升 `minBuild`，不修改旧版本发布记录为本轮通过。自动 tag 发布仍受既有 release 门禁约束，手动签名产物不称为 CI 签名通过。
