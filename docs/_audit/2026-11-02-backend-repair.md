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


## 预约确认收尾与大字号列表布局

进一步复现三个缺口：预约列表刷新后旧确认仍有效（包括返回同一快照实例）；已销毁控制器可发起新写入；确认按钮快速重复触发可关闭下层页面。三条新增回归在修复前均失败，修复后通过。现在预约读取代次绑定确认，销毁后拒绝新操作，同时保留已开始操作的原回查；共享确认框检查自身路由是否仍为当前路由，签到也复用该保护。

已查看历史 `all-pages/checkin-light-large.png` 并用当前组件复现布局不足：320dp/1x、430dp/2x、800dp/3.2x 的附加核对信息仍位于副标题旁，三条新布局测试失败。共享 `AppleListTile` 根据实际可用宽度与 17sp 文本缩放，将附加信息移至副标题下方；普通宽度/字号保留同行布局，行点击与尾部操作仍独立。未限制用户系统字号。

本机 Flutter widget 渲染使用同一中文字体 STHeiti、430×650、2x 字号、同一合成签到统计数据，对比亮暗模式。已人工查看前后图：核对时间移至统计文字后方，统计不再被挤成断行。产物位于忽略目录 `artifacts/local/ui-review/confirmation-layout/{before,after}-{light,dark}.png`，仅为组件渲染；不是 Android 设备截图、全页面首屏验收或真实账号数据。临时渲染测试已删除，稳定几何与操作测试入库。

补充操作一致性：刷新中或刷新失败保留旧预约时，原按钮仍可点击而新提交保护会直接返回。新增回归先复现按钮未禁用，再同步禁用这些状态的按钮；成功刷新恢复按钮，旧数据与错误重试出口保留。该问题不应以静默拦截冒充可用反馈。

本批最终检查：在线 `check-mirror.sh` 在 Flutter pub get 连接等待超过数分钟后，为优先执行用户新授权的登录实测而主动中断（退出 143），不得计作通过。随后用 Bash 临时命令包装仅将 Flutter/Dart 的依赖获取改为 `pub get --offline`，且分析/测试使用已解析依赖；不修改仓库门禁脚本或减少任何检查。相同 `bash scripts/check-mirror.sh` 的所有检查完成、退出 0：Rust fmt/严格 Clippy/分层与 workspace 测试、架构/文档/协议锁、Flutter 分析与 716 条测试、FRB 重新生成零漂移；这是锁定缓存依赖下的完整检查，不代表在线依赖获取成功。日志 `/tmp/ginkgo-confirm-layout-offline-deps-gate.log`。三条操作/控制器回归、三条布局回归和一条按钮状态回归分别在修复前失败，普通布局/独立操作及关联回归通过。

用户后续要求的 WebVPN 登录实测未通过，详见[单独记录](2026-11-02-webvpn-live-acceptance.md#用户再次授权的-webvpn-登录复核)。测试后的正常 main 入口 Android ARM64 Debug 已重新构建并安装成功（`/tmp/ginkgo-confirm-layout-main-apk.log`）；本批没有发布、没有提升更新门禁，设备视觉和真实业务仍未验收。


## 认证失败分类与凭据误删保护

以 `709bead` 为对照，旧实现将普通登录表单重显、入口/导航 401、无说明的认证提交 401 都分类为凭据错误。保存密码恢复时，该错误会触发删除凭据；根因未明时这既误导用户，也破坏持久化体验。此前合成“wrong password”测试只返回普通登录表单，不能证明密码错误。该断言已改为明确错误提示样本，保留真正凭据拒绝时的删除及不保存规则，另补未知失败保留凭据但不发布身份的回归。

当前策略见 [API §1.6](../API.md#16-手动跟随重定向与错误检测)：有可作答验证码仍先返回挑战；只有提取的明确凭据拒绝文案进入 InvalidCredentials。未知表单或无说明的认证 POST 401 返回需人工处理提示；入口/导航/过期确认 401 为服务问题，策略禁止与验证码错误保留自身含义。未知结果不自动重发密码、不发布身份；PreLoginTip 和明确凭据拒绝同属 30 分钟后台冷却，网络/服务错误仍 60 秒，学校与网关分别保护。该策略不新增学校字段或成功码。

实网验收脚本只记录登录错误是否出现，不再把任意 UI 错误正文写进聚合报告，避免上游提示带账号信息。没有新增原始 HTML/请求日志，也未再次使用真实账号。本批无法定位上次 WebVPN 实测的具体失败原因，保留真实验收缺口。

验证：最终回归放回 `709bead` 的旧认证/冷却实现后，upstream 416 项中有 8 项失败；恢复修复后全部通过。最终 `check-mirror.sh` 使用与上一批相同的临时 Bash 依赖包装：仅 pub get 走锁定缓存、分析/测试使用已解析依赖，未修改门禁脚本或减少检查。完整检查退出 0，含 Rust fmt/严格 Clippy、分层/workspace 测试、架构/文档/协议锁、Flutter 分析及 716 条测试、FRB 零漂移；不计作在线依赖获取成功。日志 `/tmp/ginkgo-auth-classification-old-verified.log`、`/tmp/ginkgo-auth-classification-full-gate.log`。正常 main 入口 ARM64 Debug APK 构建成功，日志 `/tmp/ginkgo-auth-classification-main-apk.log`；未安装到真实设备、未再登录真实账号、未发布。


## 密码到期确认上下文

继续检查未验收的密码到期分支，确认原代码把确认 POST 固定发送到不含查询参数的 `LOGIN_URL`；无论提示页声明什么 action，都丢弃 service 与当前上下文。当前修复按提示页 action 解析目标，缺失/空值保留当前逻辑登录地址，并复用 CAS HTTPS origin、端口和 userinfo 校验。无效或不安全 action 在确认 POST 前终止；旧实现并未把 token 发给外站，而是忽略 action 后仍向固定 CAS 发请求，不应将该缺口夸大成已证实的凭据外泄。

确认正文仍为新 execution 与 ignoreAndContinue，不收集密码或旧验证码；重复到期提示不再次确认，传输异常不重放。新增 `auth/expiry_tests.rs` 覆盖直连/WebVPN 路由、action/query、无 action、非法目标、重复提示、确认失败和后续新验证码。测试均为合成，无真实登录、无真实密码到期操作；真实页面形态（包括多表单）与设备完整流程仍待验收。

验证：6 条新增用例在 `5977a8e` 的旧分支实现上有 4 条失败（2 条既有边界保护通过），修复后全部通过。`check-mirror.sh` 按前两批方式仅离线解析锁定缓存依赖、分析/测试不再获取依赖，所有检查原样执行且退出 0：Rust fmt/严格 Clippy/分层与 workspace、文档/架构/协议锁、Flutter 分析与 716 条测试、FRB 零漂移。此结果不证明在线依赖获取或学校实网验收。日志 `/tmp/ginkgo-expiry-old-verified.log`、`/tmp/ginkgo-expiry-full-gate.log`。正常 main 入口 Android ARM64 Debug 构建成功（`/tmp/ginkgo-expiry-main-apk.log`），未安装验收、未发包；发布门禁继续阻断。


## 设置持久化与启动恢复

复核当前设置路径，发现保存队列延迟读取当前快照，快速连续操作时会把早期意图替换为后来的值；旧保存失败也可在后续成功后残留错误。异步失败在 AppPreferences 销毁后仍 notify，可能使保存 Future 再次抛异常。偏好读取失败被当成默认配置继续启动，无法确认用户原先是否主动退出，仍调用 setRoute/restoreSession。退出标记写入的迟到失败及登录路线保存失败缺乏持续可重试反馈。

现在每次保存捕获快照、串行执行，并仅由最新结果发布写错误；已排队写入在销毁后继续完成而不通知。readFailed 明确阻止自动路线初始化/恢复，登录页提供显式重读，成功后按原保存路线与退出标记决定是否恢复。writeError 单独向登录页呈现并允许重试保存，外观页也可重试；不会重新发学校认证。退出标记保存失败文案不再误称“恢复功能可能仍会显示登录页”。v1 格式、私有目录及临时文件替换适配器未改变；没有密码或 Cookie 进入普通偏好。

新增 PREF-01 客户端约束与 `preferences_consistency_test.dart`，保存错误只按最新结果展示；合成 Fake 记录路线/恢复调用数与本机写入快照。未使用真实账号，未执行学校写入，仍需设备存储故障和完整冷启动验收。

关键字段兼容：旧文件缺失 routeMode 或 explicitSignOut 时保留既有默认兼容；字段存在却类型/取值非法时视为读取失败，避免静默假定自动路线或未退出。该校验先于状态赋值，不改写原文件；其他显示字段的默认策略不变。

验证：11 条新增回归在 `21a77a3` 旧实现上全部失败，修复后通过；另加真实临时 v1 文件的旧版显示字段兼容测试，读取不改写原文件。按前述锁定缓存依赖方式执行完整 `check-mirror.sh`，所有检查退出 0（Rust、严格 Clippy、架构/文档/协议锁、Flutter 分析与 728 条测试、FRB 零漂移），未省略检查，不计作在线依赖获取成功。日志 `/tmp/ginkgo-preferences-old-complete.log`、`/tmp/ginkgo-preferences-full-gate.log`。正常 main 入口 ARM64 Debug APK 构建成功（`/tmp/ginkgo-preferences-main-apk.log`），未安装设备验收、未重新使用真实账号、未发包。发布证据仍 blocked，存储/认证敏感边界保持合并前人工审查。


## 认证重定向中的显式错误

匿名主机 GET 的脱敏文本结构观察：CAS 最终 HTTP 200、一个 form 标记、存在 execution 字段标识、未见 config.captcha 字面标识；WebVPN 入口最终 HTTP 200、一个 form 标记、存在 execution 与 config.captcha 字面标识。未解析配置值，不据此确认可作答挑战。仅保留结构布尔值/计数，不保留 HTML、Cookie、execution、重定向参数或图片；无真实凭据、无密码 POST。这不是 Android 链路、真实登录或验证码提交验收。

源代码检查发现，CAS 提交后遇非登录目标便结束跟随，只在已请求 URL 上检查 exception.message；UC 激活跳转也未检查该错误。合成链复现显式拒绝被忽略，并在随后 UC mock 返回有效身份时发布 SignedIn。当前修复由认证 GET 目标解析统一前置检查错误参数，正常 CAS 链也复用同一判定；不跟随错误目标、不继续激活/身份验证，不自动再发密码。参数只解码一次，重复空项不遮蔽后续非空错误，空错误参数仍允许正常 ticket 跳转。

该修复落实 API §1.6 的既有错误标记，不新增学校协议断言；不能据此断定上次 WebVPN 实测就是此原因。敏感认证变更保持合并前人工审查，真实成功验收仍未完成。

同批继续补齐 UC 激活 HTTP 200 正文的已知非空错误区域检查；新合成回归在修复前同样可绕过明确错误并返回 SignedIn，修复后立即返回认证提示且不查询 UC 状态。错误正文只走现有内存提示，不新增原始响应或个人信息日志。

2026-11-03 源码复核更正：上段为当时策略和运行记录，不作为当前正确性结论。Beta.3、冻结 Swift 与固定 UBAA 均不将 UC 激活 HTTP 200 导航正文交给 CAS 文本解析器；该额外条件会把模板占位误作拒绝，现已撤销，仍保留显式错误跳转和后续 UC 身份验证。恢复完整票据跟随后，原测试的第三个响应实际处于 CAS 回调而非 UC 激活，不能证明其名称所称的覆盖。对应测试源码已重新划清调用边界，本轮按用户要求未运行；详见[源码对照](2026-11-03-webvpn-captcha-source-comparison.md)。

验证：5 条新回归在 `bc28b81` 的旧实现上全部失败，修复后 upstream 全部通过。最终 `check-mirror.sh` 按前述锁定缓存依赖方式执行，原有检查均保留并退出 0：Rust fmt/严格 Clippy/分层与 workspace、架构/文档/协议锁、Flutter 分析与 728 条测试、FRB 零漂移；不计作在线依赖获取或学校真实登录验收。日志 `/tmp/ginkgo-redirect-error-old-final.log`、`/tmp/ginkgo-redirect-error-complete-gate.log`。正常 main 入口 ARM64 Debug APK 构建成功（`/tmp/ginkgo-redirect-error-main-apk.log`），未安装设备验收、未再次提交真实密码、未发包。发布门禁仍 blocked。


## 呈现读取期限与独立分区

图书馆原超时回调递增整个控制器代次，导致另一个分区仍在有效时间内的响应被丢弃；旧请求 finally 还会按字符串键清除新请求的计时器。超时只停止 loading，却不结束原 Future，刷新控件、显式排队强刷和写后回查仍可能永远等待。通用 RefreshSection 同样没有在超时时收敛调用方 Future。失效旧队列的完成还可能清除新强刷槽，旧写失败可在新上下文发布提示。

引入共用 ReadDeadline，仅截断呈现读取等待并消费迟到原生结果；不取消原生请求，不用于写提交。图书馆分区各自拥有读取期限，超时不改变账号/控制器代次；完成只清理自身对象。上下文失效结束旧普通等待、释放槽并清旧显示，新强刷槽按身份清理。通用 RefreshSection 复用期限与槽身份规则。普通读取销毁后结束等待；已提交操作继续按原持有者队列回查，已销毁页面不接收通知。不确定写仍禁止重发，读取超时后释放页面忙状态但保留待核实保护。

当前只执行合成读写 Fake，未使用真实账号、未执行学校写入；Rust 请求生命周期、业务 TTL 与学校协议未变。设备弱网、原生命令长时间等待及返回导航仍待验收。

验证：11 条新回归在 `ca2d116` 旧实现上全部失败，修复后通过；关联分区、层级刷新、服务替换和既有写后回查测试通过。按前述锁定缓存依赖方式运行完整 `check-mirror.sh`，检查未减少，最终退出 0：Rust/严格 Clippy、架构/文档/协议锁、Flutter 分析与 739 条测试、FRB 零漂移。该结果不计作在线依赖获取或设备弱网验收。日志 `/tmp/ginkgo-read-deadline-old-final.log`、`/tmp/ginkgo-read-deadline-complete-gate.log`。正常 main 入口 ARM64 Debug 构建成功（`/tmp/ginkgo-read-deadline-main-apk.log`）；未使用真实账号、未执行学校写入、未发布，发布证据仍 blocked。


## 网关验证码页的实例与代次隔离

原 GatewayChallengePage 未处理 gateway 替换，旧挑战和已输入答案可留在新实例页面，旧读取/作答完成也只检查 mounted。合成复现旧挑战覆盖新挑战、旧作答成功在新页面显示“验证通过”、旧作答失败后转而补读新 gateway，以及旧 finally 清掉新读取的忙状态。该证据只证明 Flutter 状态串用，不能据此声称 Rust 账号绑定已被绕过。

当前在实例替换时清空挑战/答案/提示，递增页面代次并重新读取；读取、提交、失败后的只读补读都捕获原实例和代次，每个完成分支及 finally 均校验当前代次。旧提交保持单次，不自动重发；旧失败不请求新实例。Rust 的账号/代次/挑战 ID 保护未修改。

新增 gateway_challenge_generation_test.dart；全部为合成 gateway 与图片，不使用真实账号或验证码，不执行学校写入。页面销毁、320dp 大字号、刷新失败保留 GET 恢复入口等既有回归继续保留，真实网关验证与设备账号/路线切换仍待验收。

验证：6 条新代次回归在 `52d94ed` 旧页面实现上全部失败，修复后与既有网关用例共 12 条通过。按前述锁定缓存依赖方式执行完整 `check-mirror.sh`，原有检查均保留并退出 0，含 Rust/严格 Clippy、架构/文档/协议锁、Flutter 分析与 745 条测试、FRB 零漂移；不计作在线依赖获取或学校真实登录验收。日志 `/tmp/ginkgo-gateway-generation-old-verified.log`、`/tmp/ginkgo-gateway-generation-full-gate.log`。正常 main 入口 ARM64 Debug 构建成功（`/tmp/ginkgo-gateway-generation-main-apk.log`）；未再次使用真实账号、未安装设备验收、未发包，发布证据仍 blocked。


## WebVPN 登录 POST 的 401 与新验证码交互

追加实测定位见 [认证阶段记录](2026-11-02-webvpn-live-acceptance.md)：宿主 Rust 经 WebVPN 的登录页和验证码 GET 成功，单次密码 POST 返回 401，含 execution、验证码和非空提示，未到 UC。具体提示未保留，仅知不含“验证码”、不匹配有限明确凭据拒绝原文；不能据此声称本次实网原因已修复。

源码另确认 401 分支无条件早于新挑战解析，导致本可由用户继续作答的完整验证码表单也被结束。现仅凭据 POST 401 且无非空提示或明确验证码提示时，检查新 execution/验证码和安全 CAS action 后返回新挑战。策略拒绝、明确凭据拒绝、其他账号提示继续返回原错误；入口/导航/密码到期确认 401 不开放这一分支。只返回交互，不自动再次发密码，不发布身份。该修复不会把本次 `other_tip` 实测伪装成验证码通过。

新增四项回归覆盖直连/WebVPN、新 execution/ID/action、单次 POST、策略/凭据/未知提示优先级、不安全 action、入口 401 和不完整表单。旧实现在两项新增回归失败，其他拒绝保护保持通过。学校新验证码提交成功仍未验收；真实拒绝提示与 Android 关联阶段仍待补。

验证：锁定缓存依赖下完整 `bash scripts/check-mirror.sh` 退出 0，保留全部原检查，含 Rust fmt/严格 Clippy/分层与 workspace、文档/接口索引/协议锁、FRB 零漂移、Flutter 分析与 745 条测试；不计作在线依赖获取或真实认证成功。upstream 独立 431、workspace 特性合并 433 条单测通过。日志 `/tmp/ginkgo-401-captcha-full-gate.log`；新增用例旧实现失败日志 `/tmp/ginkgo-401-captcha-before.log`。`check-contracts.py --release` 按预期退出 1，保持发布阻断。

正常 `lib/main.dart` 入口 Android ARM64 Debug APK 重建成功（`/tmp/ginkgo-401-captcha-main-apk.log`），未安装设备验收、未发布。本轮没有 Android 设备登录成功或物理设备证据；仅宿主 Rust 的真实认证阶段测试与合成回归。


## UBAA 错误 DOM 对照与可复跑认证诊断

对照固定 UBAA `155e8b56` 的 `findLoginError`，补齐 p.errors，并在已知错误/提示节点中跳过空占位。两项新回归在旧实现均失败：一种漏掉非空提示，另一种在 CAS 明确段落拒绝后仍被后续有效 UC mock 覆盖为 SignedIn。修复后停止于明确提示，不继续 UC，不新发密码。只扫描已知区域，不将所有段落当错误；未新增学校端点或重试策略。

新增 `network` feature 下的非生产 `auth_stage_probe` example（默认匿名，`--submit` 才读取私有管道并单次提交）。输出固定元数据/关键词而非原始正文；可选临时验证码图片采用 create_new，Unix 0600，正常结束/超时清理。诊断端口、图片与隐私策略须合并前人工审查；不进入 App 启动路径、不访问平台保险库。专门测试覆盖输出隐私、英文/未知提示和 UBAA 字段对照。

按用户持续推进要求只做一次新真实提交，实际页面在替换合成凭据后与 UBAA 八字段/值多重集合一致，仍在 POST 得到 401，未到 UC。诊断初版关键词没有命中非空提示，已补盲点但不重复尝试；真实原因仍未确认。精确耗时、结构、对照和边界见 [实测记录](2026-11-02-webvpn-live-acceptance.md)。不能以本次解析修复冒充真实认证已恢复。

验证：两项新解析回归在旧实现均失败（`/tmp/ginkgo-error-shape-old.log`）；修复后 upstream 独立测试通过（`/tmp/ginkgo-error-shape-fixed.log`）。诊断 example 的三项隐私/分类/字段对照测试通过（`/tmp/ginkgo-stage-probe-tests-complete.log`），未启用网络时正常拒绝；最终版本显式匿名 WebVPN 冒烟成功，仅 GET，并输出 anonymous_only 后清空内存 Cookie（`/tmp/ginkgo-probe-anonymous-final.jsonl`）。锁定缓存依赖下完整 `check-mirror.sh` 退出 0，原检查未减少，含严格 Clippy、Rust 分层/workspace、文档/协议锁/接口索引、FRB 零漂移、Flutter 分析与 745 条测试（`/tmp/ginkgo-ubaa-error-complete-gate.log`）。正常 main 入口 Android ARM64 Debug 构建成功（`/tmp/ginkgo-ubaa-error-main-apk.log`），未安装设备验收、未发布；发布门禁按预期退出 1。上述不计作在线依赖获取、Windows 编译或真实登录成功。
