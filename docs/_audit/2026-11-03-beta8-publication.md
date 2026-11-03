# Android Beta.8 发布记录

本记录跟踪用户明确要求的代码推送、APK 发包和公开资产校验。readiness 仍为 `blocked`。此次发布沿用 Beta.7 的用户指令例外，不能标记契约通过。

## 内容

- 版本 `0.1.0-beta.8+18`，标签 `android-v0.1.0-beta.8`。
- PR #3 已合并，标签指向 `2fb79d8f0855d602ab8aaa6ab51477a65b59aed4`。Release 于 `2026-11-03T11:32:18Z` 公开，`draft=false`、`prerelease=true`。
- APK 为 `Ginkgo-0.1.0-beta.8-android-arm64.apk`，44,257,197 字节，SHA-256 `fb0019cf647183273e65f475fb3f04d2a5457fbac268cd92b0e550808f33ad20`。APK、同名 `.sha256`、basename-only `checksums.txt` 三个资产均 uploaded；API digest 与本地一致。候选源码、契约和原生库绑定见 [产物元数据](2026-11-03-beta8-artifact.json)。
- 正常 `lib/main.dart` Release 构建、versionCode 18、ARM64、非调试、16KiB 对齐、生产插件注册表及包内 Rust 库核验通过。证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245` 与 Beta.7 一致。本轮未安装或启动应用，未请求学校系统。
- PR mirror CI `41625326707` 的 contracts、bindings、android、windows 均通过，PR CI/iOS 通过。合并后的 mirror CI `41627308919` 四个 job 和主 CI `41627309107` 也通过。该证据仅限对应提交，不覆盖真实学校业务。
- Pages 部署 `41627307876` 成功；线上 HTML 实际抓取已包含 Beta.8 下载、版本和校验链接。
- 本轮完整离线复核见 [覆盖矩阵](2026-11-03-beta-regression-coverage.md)；UBAA 有五项运行日时钟相关测试失败，受控时钟下原测试体通过。
- 仍未完成：真实账号/验证码、物理设备、学校写入、维护者安全审查，以及根登录退避重启后的持久化。

## 门禁例外

Android tag workflow `41627724687` 实际在 `Require candidate-bound Android acceptance before signing` 因 readiness blocked 而失败，签名步骤未运行。日志还列出旧验收摘要、缺少维护者审查和设备/账号/写入证据。用户明确要求发布后，手工上传与本记录所绑定源码构建出的签名 Release APK、sidecar 和 `checksums.txt`。没有修改阻断项为通过，也没有伪造人审或真实业务证据。
