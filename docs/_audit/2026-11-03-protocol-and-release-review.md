# 2026-11-03 全范围协议与候选复核

本记录是范围与当次证据，不是第二份 TODO。未完成任务仍只维护在 [MIRROR-TODO](../MIRROR-TODO.md)，学校协议事实仍只在 [API](../API.md)。用户要求核对所有协议、优化前后端后发包；此前要求暂停真实账号登录继续有效，疑似风控未证实。本轮不提交真实密码，不执行学校写操作，不把源码对齐/合成回归冒充所有实网业务已通过。

## 1. 覆盖清点

以下覆盖当前全部 `adapters/*_http.rs`，生成本表时校验无遗漏。认证、HTTP/Cookie/WebVPN、学习子适配和服务层另列；清点完成不代表每个字段/分支已经重新逐条人工证明。

| 模块 | 当前适配器 | 协议参照 | 验证入口/边界 |
| --- | --- | --- | --- |
| 本科课表/考试 | `schedule_http.rs` | API §2；UBAA LocalScheduleApi | services/tests/academic.rs；schedule_http 内测 |
| 研究生课表/学籍/执行报告 | `graduate_schedule_http.rs`、`graduate_http.rs` | API §3/§7.4；UBAA/Apple 固定取证 | services/tests/academic.rs；graduate_schedule_http 内测 |
| 成绩 | `grades_http.rs` | API §4；UBAA LocalGradeApi | grades_http 内测；grades fixtures |
| 图书馆座位/预约/状态/历史 | `library_http.rs` | API §5；UBAA LocalLibBookApi/官方前端 | services/tests/library.rs；library fixtures |
| 公开书目/复本 | `library_books_http.rs` | API §6.1；官方 OPAC 前端 | services/tests/library_books.rs；匿名实网 |
| 本人借阅 | `library_loans_http.rs` | API §6.2；官方 OPAC 配置 | services/tests/library_loans.rs；真实认证仍未验收 |
| 图书馆人数 | `library_stats_http.rs` | API §5.5；图书馆官网 | services/tests/campus.rs；匿名实网 |
| 空教室 | `classroom_http.rs` | API §6A；UBAA LocalClassroomApi | services/tests/classroom.rs；本轮新增激活/策略回归 |
| SPOC 作业/学习/文件 | `homework_http.rs`、`homework_files_http.rs` | API §7.1；UBAA LocalSpocApi/LocalSpocSupport | services/tests/homework.rs/homework_files.rs；adapters/learning/tests.rs |
| 博雅 | `bykc_http.rs` | API 教育数据索引；UBAA LocalBykcApi/Crypto | services/tests/academic.rs；bykc fixtures |
| iClass 签到 | `checkin_http.rs` | API §7.2；UBAA LocalSigninApi | services/tests/checkin.rs；checkin fixtures |
| CGYY | `cgyy_http.rs` | API §6B；UBAA LocalCgyyApi/官方前端 | services/tests/cgyy_booking.rs；cgyy fixtures |
| 校园卡余额 | `campus_card_http.rs` | API §6E；官方航财通前端 | services/tests/campus_card.rs；campus_card fixtures |
| 校园通知 | `notices_http.rs` | API §7.3/附录；官方公开页面 | services/tests/campus.rs；匿名实网 |
| 校车时刻表 | `shuttle_http.rs` | API §6C；官方公开页面 | shuttle_http 内测；匿名实网（不含实时余票） |
| 就业活动 | `career_http.rs` | API §6G；官方就业网 | services/tests/career.rs；匿名实网 |
| 学术文化 | `campus_activities_http.rs` | API §6F；官方公开列表 | services/tests/campus_activities.rs；匿名实网 |
| 应用更新 | `updates_http.rs` | API Android 更新源；非学校协议 | updates fixtures；services/updates_service.rs |

其他必要链路：`auth/` 的 CAS/UC/验证码/会话、`foundation/` 的 Cookie/WebVPN/HTTP、`adapters/reqwest_transport.rs` 的 TLS/请求生命周期；`adapters/learning/{mod,announcements,resources,assessments}.rs` 的课程/栏目/公告/下载；`adapters/student_services.rs` 的组合读取。共享 fixture runner、所有 upstream/core/workspace 测试与 Flutter gateway/widget 检查进入完整门禁。平台 Keystore、通知、偏好和升级是客户端契约，不借用 UBAA 协议对齐充当设备验收。

本轮 fixture 来源清点：`synthetic` 157 份。当前没有 redacted-upstream fixture，不能据合成契约 runner 宣称所有真实响应字段均已验证；历史人工取证仍须按 API 的日期/范围引用。

## 2. 已确认差异与本轮修复

- 空教室激活响应原先被忽略，激活 503/登录页后仍继续业务查询；现在激活和查询均分类，失败即停。明确 483/访问策略禁止不误判成凭据过期；不会把该错误当作学校会话过期；独立的路线/网关恢复边界不变。成功 fixture 改成真实成功语义的 app 最终地址，不能用 CAS 登录 URL 的空 HTML 冒充已激活。
- 成绩首次读取失败后，学期选择原先藏在成功内容里，用户不能切到其他学期。现在学期列表独立可用；切换期间仍保留旧成绩，但明确标注所读学期及当前展示学期。原请求代次保护保留。
- 不要求与 UBAA 的所有策略逐字相同。API §7.2 已记录 iClass 写入直连 HTTP8081/HTTPS8347 差异；本项目不为追求字面一致降级明文或自动重发写请求。UBAA 成功后额外直连密码尝试、失败吞成空列表、较宽 Cookie 匹配等也不能照搬。
- 本轮不扩大功能：本人借阅认证、实时余票、组/文本作答、未来阳光打卡等继续按原支持边界。API 中的未来/未接入部分不变成当前可发布承诺。

## 3. 匿名真实只读

新增非生产 `public_protocol_probe`（`network` feature，显式 `GINKGO_MANUAL_LIVE_NETWORK=1`）。它不接收账号、不调用保险库；使用真实适配器的匿名会话，仅查询公开信息，输出模块/状态/数量/固定错误码。默认每组一次读取，书目复本用本次搜索首条公开记录，不输出其标识。`--catalog-only` 用于仅补查搜索/复本，不重复其他组。公开 POST 仅为书目查询，不是学校状态写入。主 App 不调用该工具。

首次六组实测（`/tmp/ginkgo-public-protocol-live.jsonl`）：学术文化 7 条、图书馆人数 2 校区、就业活动 22 条、校园通知 5 条、校车 4 表、书目搜索 20 条均实际解析成功，最终确认共享 Session 无认证 Cookie。该结果只覆盖本次公开查询，不能外推受保护接口、其他页/全部参数、Android 或业务写入；当前仍可能经过宿主隧道，不能称纯校园直连。

## 4. 验证与发布状态

两项空教室新回归在旧实现失败（`/tmp/ginkgo-classroom-old-verified.log`）；两项成绩交互新回归在旧页面失败（`/tmp/ginkgo-grades-term-old.log`）。修复后关联测试通过，后续完整门禁/设备结果在本记录追加，未取得结果前不写为通过。

当前不将发布记录改成 ready：真实账号相关测试已按用户要求暂停，物理设备、本人写操作和维护者安全审查也不能凭代码推断。完整门禁和设备结果见 §5、§8，按各自证据范围记录；不修改最低版本门禁。


## 5. 本地与设备验证结果

- 锁定缓存依赖下完整 `bash scripts/check-mirror.sh` 退出 0：原有检查均保留，含严格 Clippy、Rust 分层/workspace、协议锁/文档/源码索引、FRB 零漂移、Flutter 分析与 747 条测试。日志 `/tmp/ginkgo-protocol-all-full-gate.log`；不计作在线依赖获取、远端 CI 或物理设备通过。
- `scripts/check-android-module-visual.sh` 在隔离 `GinkgoLiveReadOnly20261102` / emulator-5580（API37 ARM64）最终退出 0：加密学习快照设备往返、常规深浅色、窄屏大字、3.2× 标签与滚动末端四段通过，捕获 72 张纯合成截图；已按六张总览及成绩原图复核，没有发现本轮新增遮挡/溢出。截图目录 `/tmp/ginkgo-20261103-protocol-visual`，总览 `/tmp/ginkgo-visual-review-1.png` 至 `-6.png`；日志 `/tmp/ginkgo-20261103-device-gate.log`。仅为脚本覆盖范围，不证明所有真实账号页面、TalkBack 或物理设备帧率。
- `integration_test/auth_test.dart` 在同一隔离 AVD 两项通过：两次仅 `__ginkgo_vault_test__` 合成密钥写读删除、无保存账号时启动登录页。无真实密码提交，不证明在线 UC 身份的会话冷恢复。日志 `/tmp/ginkgo-20261103-auth-device.log`。
- 追加书目专用匿名复查使用真实搜索首条公开记录，复本返回并解析 2 条，最终共享 Session 仍无认证 Cookie（`/tmp/ginkgo-public-catalog-live.jsonl`）。这补充首次六组实测，不输出书目信息。
- 首轮本地 Release 命令错误使用 `--no-pub`，沿用 integration_test 插件注册表，Java 编译失败；这是构建调用失误，不当作产品新回归。按仓库要求以 `--pub` 正常 main 入口重新生成，结果另记；不手改生成注册表。

## 6. 公开基线校正与 Git 连接

GitHub Release API/CLI 确认最新公开版为 [Android Beta.6](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-beta.6)，发布于 2026-11-01T16:41:41Z，发布说明版本 `0.1.0-beta.6+16`。APK 资产 `Ginkgo-0.1.0-beta.6-android-arm64.apk`、大小 43848469、GitHub digest `f99c2ef3d8a10230b540d6764d9d6f6c53229fbcd53879e9104eeb8aba11dc2b`；同时提供同名 `.apk.sha256`。本轮修正 README、Flutter README、AGENTS、实现/TODO 入口与网站静态回退的过时 Beta.2/Beta.4 最新版声明，历史发布报告不追改。Beta.7 当前仍是未发布候选，不改写 Beta.6 历史说明。

本机 Git 配置把 GitHub URL 重写到 gh-proxy.com，该路径返回 403；以单次命令最长前缀 insteadOf 覆盖可直连 GitHub，确认 main 仍为 `5215a1bc96461f168ee228d32bd02e36cfc210df`。不修改全局 Git/代理配置、不经第三方镜像推送凭据。


## 7. 后续发现的下载页与登录对比度

下载页 JavaScript 原先只接受 checksums.txt，真实 Beta.6 只有 APK 专用 .apk.sha256，因此会跳过新版，静态回退也指向不存在的 checksums.txt。现在接受精确同名的 APK sidecar 或 checksums.txt，并保持 GitHub 仓库 URL/大小校验；不接受其他 APK 的 sidecar。新增 5 项无网络 Node 回归，旧实现两项失败、修复后全部通过，涵盖新版选择、无关/恶意校验文件拒绝、API 失败保留静态链接和静态校验链接。加入本地完整门禁与 mirror CI，不新增 Node 应用或第三方包。日志 `/tmp/ginkgo-landing-old.log`、`/tmp/ginkgo-landing-fixed.log`。

Release 实际操作发现登录占位提示在暗/亮背景上对比不足。两项新测试在旧实现分别测得约 2.47/1.73，低于本项目此次设定的 4.5 目标；修复明确使用动态 secondaryLabel 的 0.8 alpha，合成背景混色后深浅色均通过。只改变呈现，不改验证码/密码协议；关联路线与挑战回归通过。日志 `/tmp/ginkgo-login-contrast-old.log`、`/tmp/ginkgo-login-contrast-fixed.log`。此前 72 图不含这项新登录变化，最终签名候选的登录图见 §8。

首个正常入口 --pub 签名 Release 候选构建成功，ARM64/build17/非调试/无 integration_test/16KiB zipalign 和签名校验通过；签名与公开 Beta.6 相同。公开下载 Beta.6 APK 与其 sidecar 及 GitHub digest 一致。已在隔离 AVD 通过旧版 UI 保存深色与合成 demo 待办，再覆盖安装首个 Beta.7 候选，登录页保持深色，重新进入演示后待办保留。该检查不使用学校账号，demo 待办不等价真实账号记录；这不是物理设备验证。该候选早于占位提示修复，最终签名候选需重建并复核，不把初版 SHA 冒充最终资产。

## 8. 最终候选、截图与证据绑定

最终候选源码摘要 `source_sha256=281c29828870096b28b8befebda017b30305cff50bcddf1434d4a78296f3823d`；协议契约摘要 `contract_sha256=b5481b6e366689975c92152cb3365d132891a3bbe7f206055586ef774ed56bfe`。`python3 scripts/check-contracts.py --candidate`、`python3 scripts/generate-interface-index.py --check` 与 `git diff --check` 均通过；协议锁与源码/文档摘要匹配，但这些门禁不是人工协议事实审查。

最终签名候选以正常 `lib/main.dart` 和 `--pub` 构建，版本 `0.1.0-beta.7+17`，包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，大小 44,117,349 字节，SHA-256 `812de3c0288609efe5b4cac66b650fe85413c44741adfe123e60d6c313e60f50`。APK 签名验证通过，证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245` 与公开 Beta.6 一致；16 KB `zipalign` 检查通过，包仅含 `arm64-v8a`，未发现 `debuggable` 标记或 `integration_test`，正常入口启动成功。最终本地包和 basename-only `checksums.txt` 位于 `/tmp/ginkgo-beta7-candidate/`，尚未发布。

重新从已校验的公开 Beta.6 安装开始，在隔离 `emulator-5580`（Android API 37 / ARM64）保存深色外观和一条合成离线演示本机待办，再以 `adb install -r` 覆盖安装上述最终签名 Beta.7。系统安装、主 Activity 冷启动成功；最终登录页保留深色偏好，重新进入离线演示后待办仍存在。随后切换浅色并返回登录，最终候选的暗/亮登录页均重新捕获。待办属于演示数据，只证明本次隔离 AVD 的本机演示存储，不代表真实账号数据；模拟器升级不能代替物理设备升级验收。

随记录提交三张无账号信息的最终候选截图：

- 深色登录页：[PNG](assets/2026-11-03-beta7-login-dark.png)
- 浅色登录页：[PNG](assets/2026-11-03-beta7-login-light.png)
- 覆盖升级后仍存在的合成本机待办：[PNG](assets/2026-11-03-beta7-upgrade-tasks.png)

### EVIDENCE baseline

完整锁定缓存依赖门禁 `/tmp/ginkgo-beta7-final-baseline.log` 退出 0：Rust 严格 Clippy、Rust 测试、Flutter 分析与 749 条 Flutter 测试、Node 网站回归、文档/API/架构/协议检查及 FRB 零漂移均通过。此结果不证明依赖在线解析、远端 CI、真机或学校业务验收。

### EVIDENCE production-entrypoint

最终签名 Release APK 安装于隔离 Android API 37 ARM64 AVD，`MainActivity` 冷启动成功（Android 报告 1,304 ms Activity 启动时间；仅此 AVD 单次启动值，不作为流畅度/性能验收）。正常 main 入口、包版本和签名静态检查见本节，不代表物理设备启动验收。

### EVIDENCE feature:tasks

从 Beta.6 写入合成离线演示待办后，最终签名 Beta.7 覆盖安装；进入“更多 → 待办”后仍显示 `upgrade-check-20261103`，未写入学校。

### EVIDENCE feature:more

最终签名 Beta.7 从离线演示进入“更多”页，页面标签、账号与设置入口可见；只覆盖本次模拟器入口，不代表该页全部快捷服务的学校功能。

### EVIDENCE feature:settings

最终签名 Beta.7 设置页可打开，深浅色选项可修改并返回登录页；Beta.6 的深色偏好经本次覆盖安装仍生效。本次没有重启后逐项验收所有系统、通知、提醒或账号设置。

上述 case 均只可填入 readiness 对应的 `local` / `emulator` 证据；其余账号只读、验证码/网关、全部功能、物理设备、学校写入、维护者人审和 Windows 远端 CI 仍未通过。readiness 保持 `blocked`。

最后执行 `python3 scripts/check-contracts.py --release`，按契约预期退出 1。它确认候选源码/契约摘要匹配，但仍拒绝 release：账号与路线真实只读、全部验证码/会话闭环、物理设备设置/性能/通知/升级、学校本人写入、维护者安全审查、Windows 远端 CI 以及其余真实功能验收缺证据；P0/P1 未经维护者归零，reviewer 也未填写。不得删减必验项或把本轮模拟器/匿名公共读取提升为错误证据等级。
