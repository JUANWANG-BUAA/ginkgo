# 2026-11-02 后端回归修复记录

状态：工作树实现，未发布；真实账号只读登录尚未执行，学校写入未验收。用户已明确授权真实账号只读验证，但本机 Android AVD 启动后持续 `offline`，因此未向学校发送账号凭据。Mac 主机能访问 SSO，实际路由经 `utun5` 虚拟隧道；系统 HTTP/SOCKS/PAC 代理关闭。基线 HEAD 为 `5215a1b`。开始时已有未提交改动，本轮未提交、未推送；既有 tracked 差异备份于 `/tmp/ginkgo-repair-20261102/preexisting.patch`。

## 已修改

- 恢复 Beta.3 / UBAA 的成功身份验证约束：UC 失败与结构漂移不再伪造登录成功；保留 Cookie，允许用户稍后重试。
- 自动模式认证 GET 允许有界回退，并修复并发请求中另一请求先切路线导致本请求不回退的缺口。密码 POST 不由传输层重放。
- 学校和网关恢复失败各自冷却；明确 WebVPN 偏好在网关恢复失败后保留。
- 恢复优先使用当前账号同次已验证登录的内存凭据，验证码答案清除；恢复登录也登记内存凭据。未选择记住密码不写保险库。
- 图书馆直连学校认证失效可恢复一次；签到已缓存 session 查询遇网关挑战可恢复网关并重建模块会话；业务 401 先重建模块会话，学校登录页才触发学校恢复。
- 撤销未提交的签到多 ID 任意合并，恢复独立提交目标。
- 登录页路线选择补齐忙状态、成功后保存、失败保留旧值与提示、切换后清除旧验证码；设置页切换同步保存同一偏好。
- 登录输入组件按职责拆出，使页面符合 600 行限制。修复既有未提交代码的未定义 showNote、废弃 minSize 和错误隐私说明。

## 验证

回归包含：UC 500 和未知 HTML 不能发布身份、学校/网关失败互不抑制、显式 WebVPN 失败保留、内存凭据优先且不复用验证码、无保存密码图书馆恢复、登录页路线保存/恢复/等待/失败。

`bash scripts/check-mirror.sh` 最终退出码 0：架构/设计/接口/API 门禁、严格 Clippy、core/upstream/workspace 测试、Flutter analyze、全部 Flutter 测试、FRB 重新生成零漂移检查均通过。本轮 upstream 391 项单元测试及 fixture runner、Flutter 687 项测试通过，数量只属于本次执行。最终日志 `/tmp/ginkgo-repair-20261102/baseline-final.log`。

首次完整运行发现两项既有 UI 回归：WebVPN 说明消失、登录错误失去警告图标；已恢复准确说明、图标与 liveRegion 后复跑通过。新增路线测试验证异步切换期间锁定、失败保留旧路线，未用修改测试预期掩盖这些 UI 回归。

`python3 scripts/generate-interface-index.py --check`、`python3 scripts/check-api-doc.py` 与 `git diff --check` 通过。无 Android 设备连接，未运行设备或真实账号验收。`flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` 退出码 0，正常入口 Debug APK 已生成：`flutter/build/app/outputs/flutter-apk/app-debug.apk`。它是本地测试包，不是签名公开更新资产。合成测试不证明真实认证或设备重启通过。

## 未覆盖与后续

尚未增加 Cookie 持久化；网关独立验证码页面已在第三批接通，真实学校挑战及验证后的业务读取仍未验收。保留现有登录验证码机制及刷新/挑战代次保护。安全存储和网络策略改动须按 `docs/COLLABORATION.md` 在合并前人工审查；未擅自使用真实账号。待办只在 `docs/MIRROR-TODO.md` 维护。

## 持续 Goal：网关挑战状态机（第二批）

已在 domain/core/upstream 接通独立的网关挑战读取、刷新和单次作答端口；尚未增加 FFI 命令或 Flutter 页面，不能声称完整用户闭环可用。网关恢复保留学校返回的新 LoginPage；等待用户回答时禁止自动密码重试。读取图片保留先前实际路线，作答要求精确匹配当前挑战 ID、账号及会话代次。刷新撤销旧 execution；未知提交结果消耗原挑战，阻止重发。

新增回归覆盖旧 ID、路线变化、过期、刷新轮换、未知结果单次提交，以及错误答案后使用新 execution 成功作答并保留学校身份。本轮 `bash scripts/check-mirror.sh` 退出码 0：严格 Clippy、core/upstream/workspace、Flutter analyze 和 687 项 Flutter 测试、FRB 重新生成零漂移均通过；upstream 为 395 项单元测试及共享 fixture runner。日志 `/tmp/ginkgo-repair-20261102/gateway-baseline.log`。下一步仍是 FFI/页面接入、安全 Cookie 持久化；唯一 TODO 保留未完成状态。

## 持续 Goal：网关验证码 FFI 与设置页（第三批）

新增两条 FFI 命令：`load_gateway_challenge` 与 `resume_gateway_login`，通过 FRB 2.12.0 生成绑定，未手改生成物。Flutter 独立 `GatewayVerificationGateway` 由 NativeMirrorService 提供，经 ServiceCapabilities 登记，设置页提供“WebVPN 验证”入口。页面区分没有挑战、读取失败、等待作答、提交中和明确验证成功；无挑战不宣称业务可用。失败保留类型化错误并只读取新挑战，禁止自动重发答案。离开页面后迟到响应不更新 UI。

新增五项 widget 回归：无挑战不误报成功、刷新及答错后用新 ID 作答、忙状态与销毁后的迟到响应、设置入口经能力矩阵接入、320dp 两倍字号操作。两条新命令均在排他门内校验 expectedAccount，拒绝旧账号页面；空账号能力有桥接回归测试。本轮还修复了错误类型的导入循环，桥接测试使用仓库 TEST_GATE 避免干扰退出测试。本轮 `bash scripts/check-mirror.sh` 退出码 0：架构/API/接口/设计门禁、严格 Clippy、Rust 全 workspace、Flutter analyze 与 692 项 Flutter 测试、FRB 重新生成零漂移全部通过。日志 `/tmp/ginkgo-repair-20261102/gateway-ui-baseline.log`。API 总表与生成索引已同步为 91 条 FFI 命令，无原始学校 JSON 逃生舱。Cookie 持久化与真实设备/账号验证仍未完成。`flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` 退出码 0，已重建配套 Rust/FRB 的正常入口 Debug APK；日志 `/tmp/ginkgo-repair-20261102/gateway-ui-apk.log`。未连接设备，未进行真实网关挑战或学校写入。

## 持续 Goal：Android Keystore 会话快照（第四批）

登录成功后，Rust 将账号、资料显示名、用户路线偏好和直连/WebVPN 两份 CookieJar 编为版本化记录，交给 Android 独立 Keystore AES-GCM 密钥加密，密文存于私有且不备份的 SharedPreferences。后续认证响应包含 `Set-Cookie` 时也串行更新快照；匿名 Session 没有持久化回调。该快照不依赖“记住密码”；验证码答案与业务 token 不保存。24 小时硬上限、账号身份复核、路线匹配和 UC 在线校验通过后才恢复身份；过期、身份不符或路线失配的快照清除。显式登出、手动开始新登录、已初始化后的路线切换都会删除快照；会话快照写读删除使用 `spawn_blocking`，不会把加密偏好 IO 放在 Tokio 工作线程上。Windows/macOS 保留原来进程内 Cookie 与密码恢复行为。

新增合成回归覆盖 CookieJar 两路线 JSON 往返、无保存密码的冷进程恢复、后续 `Set-Cookie` 轮换持久化、过期快照清理、异账号拒绝和路线切换删除。本批 upstream 会话筛选测试数量以最终门禁日志为准；测试使用内存保险库，未验证 Android Keystore/JNI 实机往返。设备当前未连接，真实登录和写操作未进行。该存储涉及 Cookie 持久化，合并前须维护者人工安全审查；待办与范围见 [MIRROR-TODO](../MIRROR-TODO.md) 与 [隐私说明](../PRIVACY.md)。

## 持续 Goal：真实网络与账号只读准备检查（第五批）

用户明确授权使用真实账号做只读验收。发送账号凭据前先检查网络：Mac 的 `en0` 地址位于 `10.138.0.0/16`；到学校 SSO 的路由由 `utun5` 承载；macOS 显式 HTTP、SOCKS 与 PAC 代理均关闭。匿名 SSO 登录页请求返回 HTTP 200，TLS 校验通过，curl 未使用 HTTP 代理。这说明当前主机能经虚拟隧道路由到学校入口；不能据此断言 Android AVD 已使用同一条路由，也不能仅凭接口名确认隧道提供者。

新建的隔离 `GinkgoSessionColdBoot` AVD 在 Android 37 arm64 镜像上启动失败，`adb` 持续报告 `offline`，QEMU 报告宿主未启用 HVF；未安装 APK、未打开登录页、未提交账号密码，也未完成验证码或业务读取。已有 Beta.7 模拟器因签名不匹配未卸载或清数据。故真实登录、Keystore/JNI 冷启动恢复和真实学校业务读取仍未验收；学校写入未尝试。后续在可用 Android 设备或模拟器上继续，凭据只经正常登录 UI 输入。


## 第五批后续：实际模拟器登录结果补记

已有 `Ginkgo_Alpha7_Release_QA` AVD 使用只读磁盘模式成功启动，ADB 为 device 且系统启动完成；此前“AVD offline，未提交密码”仅对应准备检查阶段。随后通过显式启用的 `live_acceptance_test.dart` 实际提交一次用户授权的登录，约 13 秒后未获得 signedIn，未观察到验证码输入框，受保护模块未继续读取。测试 finally 执行退出清理，报告接收器收到两条记录，但错误正文未保留，不能判断为密码错误、网络故障或学校拒绝。模拟器随后退出；未自动再试密码、未执行学校写入。凭据不入库、不进入构建参数或诊断文档，临时接收器及探测文件已清理。

## 第六批：前后端复核与认证操作稳定性

本轮从 Beta.3/HEAD/UBAA 的固定对照继续检查，并反查本轮新增存储；详细证据归入 [诊断追加复核](2026-11-02-backend-regression-diagnosis.md#追加复核前后端与本轮修复自身的缺口)。已修复启动/设置忽略路线失败值、设置切换事务提前解锁、登录/网关过期挑战不能 GET 更新、刷新失败丢失上下文、快照期限滑动、冷启动 UC 暂不可用仍发布缓存身份、remembered 混淆 Cookie 与密码，以及被回退删除的用户错误密码退避。保留验证码的原图片端点、双答案字段和单次 POST，不按 type 猜测新协议。

固定期限沿用现有快照格式的 saved_at_ms；修复前已被重写的历史时间无法还原，不能宣称追溯原登录时刻。新登录建立新生命周期，后续恢复和 Cookie 轮换不延长起点。敏感存储仍须合并前人工审查，真实 Keystore 冷启动与学校挑战未验收。

追加恢复分类冷却：学校与网关独立计时，明确凭据拒绝冷却 30 分钟、暂时错误 60 秒；已存在但过期的网关挑战也不触发后台重新认证，只允许用户显式 GET 换挑战。对应回归不休眠，直接控制单调时钟时间戳并检查请求次数。

最终 `bash scripts/check-mirror.sh` 退出码 0，日志 `/tmp/ginkgo-repair-20261102/review-accepted.log`：架构、API/接口、设计门禁、fmt、严格 Clippy、Rust core/upstream/workspace、Flutter analyze、696 项 Flutter 测试与 FRB 重新生成零漂移均通过。独立 upstream 为 409 项单元测试及共享 fixture runner；workspace 特性组合的数量不同，不将两者混为同一次运行。`python3 scripts/check-api-doc.py`、接口索引检查与 `git diff --check` 通过。正常入口 `flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` 退出码 0，产物 `flutter/build/app/outputs/flutter-apk/app-debug.apk`，日志 `/tmp/ginkgo-repair-20261102/review-main-apk.log`；已覆盖集成测试入口包。未安装到设备，本批没有再次发送真实凭据或学校写请求。


## 提交前续接说明

用户要求在额度耗尽前先落地提交。最后一轮全量优化初查只阅读代码及仓库已有截图，未继续更改应用实现；新发现的图书馆旧 service 控制器、确认后上下文复核和大字号统计行布局问题已进入唯一 MIRROR-TODO。当前提交保留真实账号/设备/写入验收与公开发布阻断，不创建发布 tag、不发布 APK。


## 图书馆服务替换收尾复核

`LibraryPage` 在服务替换时重建控制器，清除旧快照，并阻止旧确认弹窗提交到新服务。`library_service_replacement_test.dart` 两条回归在提交 `4529cfb` 的旧页面实现上均失败，在修复实现上通过；覆盖旧响应迟到、新服务读取和确认撤销。完整 `bash scripts/check-mirror.sh` 通过（日志 `/tmp/ginkgo-closeout-gate.log`，临时本机证据）：包含 Rust、Flutter 分析与测试、协议/文档检查和 FRB 零漂移。校外验收脚本的强制路线检查及失败记录同步落地，未据此解除发布阻断；没有在本次收尾复核中重试真实凭据或执行学校写操作。设备、真实账号及其余确认上下文验收继续见唯一 TODO。


## 座位预约与签到确认上下文修复

本批代码检查及合成回归确认：确认弹窗期间更换服务、刷新查询或改变同 ID 时段的日期，旧确认仍可向当前服务发起写入；签到弹窗也未重查时间窗口。旧提交完成后可能将提示和回查作用于替换后的页面；座位回查回调抛错会留下忙状态。

修复将确认与服务/查询代次绑定，座位捕获区域、完整时段及原回查回调，签到确认后重查时间；上下文变化撤销旧确认，旧结果不更新新页面。座位回查使用异常收尾释放忙状态，未知写入继续禁止重发；签到失败或旧快照保留数据但禁用提交。`library_seat_mutation_context_test.dart` 和 `checkin_mutation_context_test.dart` 覆盖上述边界。学校协议、FFI 签名和写入次数策略未改变；只执行合成 fake 写入，未重试真实账号或进行学校写操作。

验证：两份新增文件共 10 条回归在 `38e160d` 的旧实现上全部失败，在修复实现上全部通过；关联图书馆测试也通过。完整 `bash scripts/check-mirror.sh` 最终退出 0，含 Rust fmt/严格 Clippy/分层与 workspace 测试、文档及协议锁、Flutter 分析与 708 条测试、FRB 重新生成零漂移。临时本机日志为 `/tmp/ginkgo-mutation-old-final.log`、`/tmp/ginkgo-mutation-final.log`、`/tmp/ginkgo-mutation-full-gate-final.log`；日志不构成设备或真实学校验收。本批未构建或发布新的 APK；发布验收仍 blocked。
