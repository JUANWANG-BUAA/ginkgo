# 后台提醒与冷恢复修复

## 授权与范围

2026-11-03，用户反馈 Beta.9 已能登录，但离开几分钟后再次打开要求登录；未重启、未手动清理。用户授权“后台提醒调度，以及冷启动恢复失败处理”，回复“好的，开始”。这只构成 NETWORK-FREEZE 的最小恢复例外，不授权改 CAS、验证码、密码提交、Cookie、HTTP 或路线。

冻结基线仍为 Beta.9 `c4afc0c3f5edad5cded1352da5b536001edb430a`。原始哈希不替换；唯一获准源文件修订为 `services/session_service/session_source.rs`，只把持久会话读取错误从吞错改为向上传递，当前 SHA-256 为 `7cf178f8abe7b00704a508b3826814678f16210997a41ca941394a938b2bbd21`。检查器及清单同时固定该例外，拒绝其他路径与任意新哈希。

## 源码确认

- ReminderScope 的 Dart Timer 只在前台运行，Android 没有系统后台查询任务。通知权限不等于后台查询能力。
- 已有 AlarmManager 计划独立于 Flutter 和登录状态，不能把所有漏提醒都归因于登录；此前重启没有恢复计划。
- Kotlin `loadSession` 把读取/解密异常返回 null，Rust 又吞掉快照读取错误，冷启动 UI 将恢复故障归到登录页。新增 Rust 回归在旧实现实际得到 `SignedOut` 而失败，修复后返回 `CredentialStore`。
- 用户现场没有进程/保险库/UC 分支证据，不能断言几分钟后必然是系统杀进程或某一个 Keystore 错误；24 小时固定快照期限不是几分钟定时退出，保留期限不变。

## 实现

Android JobScheduler 持久周期任务最短 15 分钟，要求网络；使用有总时限的无界面 Flutter engine。任务经独立 FRB 命令复用原 SchoolClient；从平台保险库只读取会话快照，严格检查账号摘要、格式、路线和期限，再拷贝至没有密码的 MemoryVault，由原 UC 验证发布身份。后台既不读取保存密码，也不覆盖/删除前台的持久会话；会话更新仅在本轮内存保留。后台不调用交互 `restore_session`，不自动签到、交作业或补交密码。

Android 按账号摘要和随机代次串行配置/更新/清理。迟到任务、前台已打开、切账号和关闭开关时拒绝旧结果；失败分组保留旧计划，确认空分组才清空。重启/覆盖升级重排未过期计划；通知保持泛化文字。设置显示后台调度状态；恢复失败提供重试或用户主动手动登录。

前台控制器只提交尚未同步的成功分组，并用修订号保护同步期间到达的新结果；恢复前台不是成功查询，不能把旧 UI 计划重新覆盖到后台较新的计划上。首次读取之前先配置原生任务；若期间退出/换号则不再发起学校读取。恢复按钮同一时刻只允许一轮恢复，路线初始化等待期间连续点击不排队重复恢复。

周期后台调度不是常驻进程，也不是实时推送；系统省电、休眠和厂商限制仍会延迟，短时签到可能漏检。已过期/超过 24 小时的快照不在后台自动登录续期。需用户打开应用恢复身份。Android 官方依据：`JobInfo.Builder.setPeriodic`、`JobService` 以及 Flutter `FlutterEngine`/`DartEntrypoint` API。

## 验证

### 本地完整基线

`bash scripts/check-mirror.sh` 最终通过，包含严格 Clippy、core/upstream/workspace 测试、22 个已知会话错误变体检出、Flutter 分析、802 项 Flutter 测试与 FRB 再生成零漂移。完整日志为本机 `/tmp/ginkgo-background-mirror-final.log`。最终定向测试 `background_reminders_test.dart`、`session_restore_failure_test.dart`、启动/路线测试也通过；其中后台/恢复新增测试覆盖相同计划键、空结果与失败分组、账号匹配、首次慢读取、同步期间更新、退出后不读学校、恢复连点合流。

- `session_restore_storage.rs` 在原 `Err(_) => {}` 实现上实际失败：预期 `CredentialStore`，却返回 `SignedOut`；修复后通过。NoNetwork 和密码端口均为 panic，排除隐式学校请求和密码回退。
- 前台恢复覆盖旧计划回归在中间错误实现上实际失败：恢复后仍提交 `homework`；修订号/一次性待同步组修复后通过。此项红绿日志为 `/tmp/ginkgo-background-resume-red.log` 与最终完整基线。
- 新后台会话的严格转录覆盖 Direct/WebVPN 各自的 UC 成功、失效和其他身份，精确匹配 GET 目标、Accept、X-Requested-With、Cookie 和次数；无多余请求或密码 POST。未把该转录说成完整学校读取的实网验收。
- 冻结门禁通过：64 个保护文件中只存在上文固定的 1 个授权修订；原始基线哈希清单不变，9 项门禁自测通过。

### 隔离 Android 闭环

使用本轮新建的 `GinkgoBackground20261103` ARM64 API 37 模拟器、`emulator-5580`，全程飞行模式、无学校账号/会话。执行：

```sh
GINKGO_BACKGROUND_CHECK_PROFILE=1 bash scripts/check-android-background-reminders.sh emulator-5580
```

脚本只接受 `GinkgoBackground*` 隔离 AVD，使用合成摘要/计划，成功结束时清除合成应用数据并用 `--pub` 重建正常 `lib/main.dart` Debug APK。SDK 的 Debug/Profile 按设计保留 dev 插件，不能据此判为测试入口；仅 Release 过滤测试插件。本轮不交付公开 Release，也不把调试包当更新资产。最终源码复跑退出码 0，全部阶段通过；本机主日志 `/tmp/ginkgo-background-device-final.log`，详细日志/截图 `/var/folders/sr/4bdwkpcd647c8y1xdg0ggpzh0000gn/T/ginkgo-background.QiX171/`。文件只作本机本次证据，不作为未来检查的固定输入。

实际闭环覆盖：原生分组保留与成功空清理、换账号清理/拒绝旧账号清理、后台双 Flutter engine、进程被 `am kill` 后独立 JNI/FRB 启动、正常重启自动重排、正式 main 的 Profile AOT 后台执行、覆盖升级后的正常 main Debug 冷任务。注入 `integration_test/data/invalid-session.xml` 合成损坏记录后，JNI/Rust/后台返回 `storageUnavailable`，正常 UI 显示“暂未恢复登录状态 / 重试恢复”，原记录字节保留。UI 截图已查看，无正文/按钮重叠。Profile 只作 AOT 验证，不是公开 Release 产物。

过程中确实抓到默认 Dart 库入口无法解析的问题，改为显式库 URI 并以运行结果验证；首次构建 Profile 曾等待 Gradle 下载依赖，最终正常完成，没有改应用网络或关闭 TLS。重启脚本使用系统正常关机路径并确认新 boot ID；早期直接硬重启造成新装应用系统启动状态未刷盘、另一次 reboot 关闭 shell 返回 255，均未算产品通过，现已修正测试夹具而不是放宽应用断言。

### 保留边界

本轮没有使用真实凭据、学校网络请求或学校写操作，未请求发布，未提升版本或解除 readiness。未用本地 macOS 结果代替 Windows 主机构建。物理设备上的厂商省电、调度配额、锁屏/实际 Keystore 故障、真实 Cookie/UC 暂时失败和真实新增作业/签到发现仍需设备验收；本轮合成损坏记录不是这些情形的全部替代。凭据存储、日志及新增权限仍需按 COLLABORATION 人工审查。唯一未完成清单继续维护于 MIRROR-TODO，不另建重复 TODO。
