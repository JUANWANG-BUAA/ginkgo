# Android Alpha.2 发布记录

已于 2026-10-21 公开发布 [android-v0.1.0-alpha.2](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.2)，源码提交 `01cb3c0`，版本 `0.1.0-alpha.2+3`，Android 7.0+ / arm64-v8a。

下载 [正式 APK](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.2/Ginkgo-0.1.0-alpha.2-android-arm64.apk) 与 [SHA-256 校验和](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.2/checksums.txt)。

**发布后认证异常（2026-10-21）**：后续单次实测 SSO 密码提交返回 302，UC 激活却跳向 HTTP SSO，最终 UC 状态码 10600，不能建立有效会话。Alpha.2 尚不包含该跳转兼容修复；详见 [诊断记录](_audit/2026-10-21-auth-redirect-incident.md)。不能将此现象直接判定为账号封禁。

- APK：39,964,460 字节；SHA-256 `3e3bd5164bff330a9aa11e700a49c20dd39f7586b3ea3c2617d4c50c9cdb3ebf`，GitHub资产digest一致。
- 签名证书：`451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与 Alpha.1 相同；versionCode 从 2 增至 3，支持覆盖升级。
- 正常 main 入口、Release 无 debuggable、INTERNET 权限存在。Flutter、app、Rust 三个 arm64 动态库均在包内；ELF LOAD 至少 16 KB 对齐，`zipalign -c -P 16 -v 4` 通过。
- 已安装最终签名包并打开登录、离线工作台、设置和运行自检；Rust桥接、本机文件、安全存储写入/读回/删除均通过。该 Release smoke 未重新登录真实账号，也未提交学校写操作。
- 当前完整门禁、真实账号只读与最新登录失败分别记录于 [本轮验收](MIRROR-ACCEPTANCE-2026-10-21.md)。165项Rust核心、88项Flutter测试通过；最新实网复测的学校服务暂不可用仍未消除。

签到及图书馆预约管理新增逐次确认、提交后回查和未知结果不重发，但真实写入未验收，属实验功能。博雅选退课、CGYY写入、作业提交/附件仍未迁移。首次学校认证可能需8–10秒，非空成绩/GPA、本科账号和完整读屏仍待验收。

Alpha.1正式包可直接升级。debug包签名不同，须先备份本地待办再卸载调试包；卸载会清除本地数据。应用只通过浏览器下载，不自动安装。
