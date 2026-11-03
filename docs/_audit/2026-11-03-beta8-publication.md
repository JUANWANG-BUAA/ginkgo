# Android Beta.8 发布记录

本记录跟踪用户明确要求的代码推送、APK 发包和公开资产校验。readiness 仍为 `blocked`。此次发布沿用 Beta.7 的用户指令例外，不能标记契约通过。

## 内容

- 版本 `0.1.0-beta.8+18`，标签 `android-v0.1.0-beta.8`。
- APK、签名、SHA-256、CI、Release、静态网站部署及回下载证据补充于发布完成后。
- 本轮完整离线复核见 [覆盖矩阵](2026-11-03-beta-regression-coverage.md)；UBAA 有五项运行日时钟相关测试失败，受控时钟下原测试体通过。
- 仍未完成：真实账号/验证码、物理设备、学校写入、Windows 新提交 CI、维护者安全审查，以及根登录退避重启后的持久化。

## 门禁例外

Android tag workflow 预期在签名前因 readiness blocked 而失败。用户明确要求发布后，维护者手工上传与本记录所绑定源码构建出的签名 Release APK、sidecar 和 `checksums.txt`。没有修改阻断项为通过，也没有伪造人审或真实业务证据。
