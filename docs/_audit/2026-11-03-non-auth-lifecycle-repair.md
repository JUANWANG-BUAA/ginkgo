# 2026-11-03 非登录生命周期回归修复

本轮按用户要求暂不排查真实登录，先修复无需学校账号即可复现的现有功能。账号受管控仍属待确认条件；未使用真实凭据、未执行学校写入、未修改认证协议、未发布。唯一未完成清单仍为 [MIRROR-TODO](../MIRROR-TODO.md)。

## 复现与修复

| 触发 | 旧行为 | 当前工作树 |
| --- | --- | --- |
| 空教室页在日期/查询读取中替换服务 | 没有 `didUpdateWidget` 失效路径，旧日期和旧查询仍可发布，新服务不重新初始化 | 清除旧查询、筛选和日期；日期与查询各自按代次丢弃旧响应，重新读取新服务日期 |
| 学习快照开启确认期间替换 gateway | 确认后使用新的 `widget.gateway`，旧确认可能作用于新服务 | 提前锁定忙状态，确认和变更绑定原实例；实例变化撤销旧确认，旧变更结果/finally 不污染新状态 |
| 学习快照状态读取或设置抛异常 | 异常未处理，可能停留在正在确认或没有核对出口 | 显示固定错误；禁用继续变更，提供只读重读状态；不自动重放设置操作 |
| 通知页替换服务、前后台读取与权限请求交错 | 旧权限读取可覆盖新权限结果，替换服务不重读，旧请求可修改新实例 | 服务代次隔离请求和收尾；权限读取修订号隔离旧结果；请求期间不启动竞争读取，使用原提醒控制器 |
| 本机设置重读遇到排队保存或更新选择 | 旧磁盘结果可覆盖新外观选择；旧重读错误可覆盖新成功 | 先等待已有保存；校验保存修订号和重读修订号，仅当前读取更新状态，销毁后不发布 |

隐私页“Cookie 只在内存”的旧说明同步为 Android 加密短期学校会话、恢复前验证与业务令牌仅内存的实际边界；未改变数据存储实现。实施页另移除学术文化 JSON 信封的过时描述，并将 Beta.4 段落明确为历史发布记录。

## 验证证据

新增 `flutter/test/non_auth_lifecycle_regression_test.dart`。首批 9 项在旧实现全部失败，日志 `/tmp/ginkgo-nonauth-before.log`：覆盖空教室两条实例替换、学习快照状态失败/确认替换/旧保存/保存失败、通知替换/旧读取覆盖授权、本机设置旧读取覆盖新选择。最初测试文件的编译失误另行修正后，才执行这次旧实现验证，不将编译失败计作回归复现。

修复后上述测试与既有页面代次、设置、空教室集合检查共 37 项通过，日志 `/tmp/ginkgo-nonauth-after.log`。继续补充快照失败后的只读重试、确认去重/取消，以及设置重读等待保存和旧错误隔离；新增文件最终 12 项通过，日志 `/tmp/ginkgo-nonauth-expanded.log`。

`flutter/integration_test/non_auth_lifecycle_test.dart` 复用同一组合成端口场景，不读取真实账号、保险库或学校服务。修正测试替身跨错误 Zone 注入异常的时序后，在已恢复的 API37 ARM64 / emulator-5580 上 12 项全部通过，日志 `/tmp/ginkgo-nonauth-device-final.log`。前两次设备运行因测试替身 Future 的错误 Zone 不一致引发未处理合成异常及绑定连锁失败，日志保留，不计作产品失败或通过；最终运行保留全部原场景和断言。完整基线和正常入口构建结果见下方追加。

UI-01/PREF-01 已同步到功能契约与接口索引；协议锁补入空教室、学习快照页面及新回归出处后刷新。学校协议未修改，刷新摘要不解除发布阻断。当前候选不能沿用 Beta.7 的旧验收摘要。

## 验收边界

这些回归验证页面与本机状态的生命周期，并不证明真实账号链路、Android 通知系统实际投递、Keystore 会话冷恢复、物理设备存储故障、TalkBack、学校写入或 Windows 当前候选构建通过。发布验收保持 blocked。

## 模拟器重复退出的根因与恢复

用户在修复进行中追加要求排查近期频繁的模拟器故障。本机为 Apple Silicon / macOS 27.2，Android Emulator 37.2.12；`kern.hv_support=1`、`-accel-check` 可用，GUI/headless QEMU 签名均通过严格校验。故障发生在模拟器启动层，未运行 Ginkgo 登录。

`Ginkgo_Beta2_Release_QA` 与 `GinkgoSessionColdBoot` 的外层 `.ini` 及内部 `config.ini` 均写为 `target=android-0`，实际使用 API37 ARM64 Google Play 镜像；其他三个 AVD 的 target 与镜像一致。Android [启动源码](https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android-qemu2-glue/main.cpp) 的 Apple ARM 路径仅在识别的 API≥21 且 ABI 匹配时加入 `-enable-hvf`。本次及数份 11-02 GUI 崩溃均为 `sAddressSpaceDevicePing → qemu_tcg_cpu_thread_fn` 空指针；headless 则由 hang detector 终止。配置与实际加速路径相符，不能仅凭主机加速检查成功就排除元数据问题。

先备份两台 QA AVD 的四个元数据文件，再只将 `target=android-0` 校正为实际的 `android-37.0`。未清空 userdata、快照或磁盘，未重签 SDK，未修改系统权限、TLS、代理或健康 AVD。备份目录为本次工作区的 `emulator-diagnosis/avd-metadata-backup/`（绝对路径见终端记录，不入库复制机器配置）。

同一个 Beta2 QA 镜像以 `-read-only -no-snapshot -no-window` 冷启动后，日志 `/tmp/ginkgo-nonauth-emulator-fixed.log` 明确包含 `-enable-hvf` 与识别出的 API37；ADB 返回 `sys.boot_completed=1`、SDK=37、PAGE_SIZE=4096。此前失败日志为 `/tmp/ginkgo-nonauth-emulator.log` 与 `/tmp/ginkgo-nonauth-emulator-window.log`。该对照确认本次故障与错误 target 有关；ColdBoot AVD 已校正元数据，尚未独立启动验收，不把所有历史崩溃都归为这一根因。

旧 `.learnings/ERRORS.md` 的 2026-10-23 记录已提过此问题，本轮复现补入同文件；Flutter README 增加检查外层/内层 target 与实际 HVF 的步骤。后续创建 AVD 应复查生成元数据，不以反复冷启动或清数据替代定位。


## 最终本地验证

完整 `bash scripts/check-mirror.sh` 最终退出 0，日志 `/tmp/ginkgo-nonauth-full-gate-final.log`：保留 Rust 严格 Clippy/分层与 workspace 测试、文档/架构/协议检查、Flutter 分析及 761 项测试、FRB 重新生成零漂移。首轮在测试重复联网解析阶段停滞；脚本保留前置主包及独立包依赖解析，分析与测试增加 `--no-pub` 复用刚解析的依赖，避免重复解析，并非跳过测试或将整个基线改为离线。

正常 `lib/main.dart` 入口 ARM64 Debug APK 以 `--pub` 重建成功，日志 `/tmp/ginkgo-nonauth-main-build.log`；不是测试驱动包、未签名公开发布。设备 12 项为合成端口测试，不提升为真实账号、实际通知投递或物理设备证据。
