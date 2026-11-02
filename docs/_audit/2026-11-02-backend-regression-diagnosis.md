# Beta.3 前后认证、路由与持久化诊断

日期：2026-11-02。首轮为源码与历史取证；以下 F1–F11 保留初次诊断时点，不能当作本轮修复后的现状。后续实现、合成验证与一次真实登录失败分别见本文追加复核及 [修复记录](2026-11-02-backend-repair.md)。学校写操作未执行。

## 结论

确有 Beta.3 之后引入的严重认证回归；最明确的是 Beta.4 将自动路由能力绑定密码保存状态，以及之后取消认证 GET 网络错误回退。当前又通过放宽登录成功判定修补可用性，产生新的认证证明缺口。图书馆、签到共用这些基础设施，不能把同时失败理解成多个学校系统同时故障。

也存在 Beta.3 之前就有的能力差距：Rust Cookie 从未持久化，重启恢复主要依靠保存的密码重新登录；UBAA 则保存按路线隔离的 Cookie 和本地认证记录。整体退回 Beta.3 可以移除部分新回归，但不能完成真正的会话持久化，也不能消除旧有模块恢复缺口。

不能从 Git 提交证明改动者使用了什么模型、参数规模、是否有意隐瞒。可以确认的是实现、注释、测试名、提交说明与实际行为多处不一致。

## 范围和版本

| 对照对象 | 固定引用 | 用途 |
| --- | --- | --- |
| Beta.2 | `0042526` / `android-v0.1.0-beta.2` | Beta.3 前基线 |
| Beta.3 | `32b6a1d` / `android-v0.1.0-beta.3` | UI 大改之前的主要对照 |
| Beta.4 | `d923913` / `android-v0.1.0-beta.4` | 含自动回退门控的发布 tag |
| 当前 HEAD / Beta.6 tag | `5215a1bc96461f168ee228d32bd02e36cfc210df` | 最新已提交实现；不等同公开 APK 实测 |
| 当前工作树 | HEAD 加已有未提交修改 | 登录路线持久化、认证 GET 回退、签到合并等；不能视为已发布 |
| UBAA 本轮远端源码 | `155e8b56ae76348e67c70414e3a9ab7fa54f2dda` | GitHub shallow clone；不是文档里旧的 e8a397f |

UBAA：https://github.com/BUAASubnet/UBAA/tree/155e8b56ae76348e67c70414e3a9ab7fa54f2dda 。本地只读副本 `/tmp/ginkgo-audit-ubaa-20261102`。没有把它的服务端中转接口当成本项目的学校接口。

审查时已有工作树改动，而且 `auth/tests.rs` 在审查期间发生外部变更。未覆盖、撤销或提交这些改动。报告将 tag、HEAD 和工作树分开。全文所述当前行号可随外部编辑变化，应优先按函数名定位。

## 关键演变

1. Beta.2 → Beta.3：认证主要变化是账号大小写兼容、模块拒绝分层、公开读取路由和错误映射，并非一次全面重写登录。
2. `94ef91b` / Beta.4：登录成功后设置 `automatic_fallback(remembered || webvpn_cookie_present())`，将运行时路线与持久密码选择耦合。
3. `bd97642`：移除这一门控，同时加入学校/网关分别冷却等保护；说明此前已识别回归。
4. `b8bcb5d`：大面积回退认证与验证码，移除网关挑战页面及相关命令，也撤销了分开的失败冷却。其“恢复 Beta.3”不等于所有后续状态都是 Beta.3。
5. `5b8e585`：再次接通验证码；`c98ce17` 新增认证专用 `send_auth`，停止网络错误触发的认证 GET 回退。
6. `2c85a6c`：UC 不可用时以提交账号构造成功身份。
7. `5215a1b`：保存本次登录凭据到内存供网关恢复，登录跳转遇到非登录页面提前结束。
8. 未提交工作树：重新允许认证 GET 遇到任意传输错误切换 WebVPN；修改签到多 ID 合并规则；新增登录页路线保存。

## 诊断明细

### F1：Beta.4 自动模式与记住密码绑定【已确认历史回归，当前门控已移除】

证据：Beta.4 的 `services/session_service/session_source.rs::sign_in`，以及 `auth/session.rs::activate_automatic_webvpn_fallback`。未保存密码且当时无网关 Cookie，后续安全 GET 也无法回退。登录成功不代表校外业务 URL 可直达，因此签到/图书馆会成为直接受害者。

此门控在 Beta.3 没有。`bd97642` 已删除，`b8bcb5d` 后也未恢复。不能把这个旧门控继续当作当前全部问题的解释。

### F2：认证 GET 的网络回退被取消【已确认 HEAD 行为回归，工作树正在反向修改】

证据：`c98ce17`，`auth/session.rs::send_auth` 与 `auth/login.rs`、`auth/uc.rs`。业务 `send_with_fallback` 遇到 GET 传输错误可以回退；HEAD 的认证链只有 483/策略页才回退。校外静默丢包、连接失败不会产生 483，于是自动登录在直连处终止。

“安全 GET 切路由会重复提交密码”不是该函数的必然行为：密码 POST 本来就通过单次 `send` 提交。实际完整链可能需要网关再次认证，但需要统计整个用户动作的 POST，而不是禁止所有认证 GET 回退。

未提交修改重新接受 GET 传输错误，方向解决了这一缺口；尚不能证明完整登录只提交一次。新测试仅调用取登录页，且忽略其返回错误，再断言零 POST，不能证明完成了网关认证。

### F3：登录成功证明被放宽过度【已确认代码分支，误登录需专门反例验证】

证据：`auth/mod.rs::complete_login`、`directory_unavailable`，`auth/login.rs::follow_redirects_and_check_error`。

原来需要 UC 激活与身份确认。现在只要起始是 Form，后续 UC 出现 ServiceUnavailable、NetworkUnreachable 或 ChangedResponse，即构造 `UserProfile { school_id: submitted, name: empty }` 返回 SignedIn。Form 只证明准备提交，不能单独证明学校接受密码。

尤其跳转链对任何非登录目标返回成功，不验证必须带 service ticket；普通 HTTP 200 无 execution/错误文字也会走到成功候选。该宽松结束条件与 UC 降级组合，缺少明确 CAS 成功证据。不能把 ChangedResponse 一概解释为“目录不可达”。

UBAA 本轮 `LocalConnectionAuth.kt::login` 仍要求 `validateLocalConnectionSession()` 为 Valid；TransientError 返回失败。UBAA 并不支持现在这项降级的充分性。

建议认证结果拆为：CAS 已确认、身份资料暂不可用、业务会话未就绪；只有已验证的成功证据允许发布身份。不得为了显示工作台把结构漂移映射为成功。

### F4：Cookie 会话没有跨进程持久化【已确认旧有能力缺口】

证据：`auth/session.rs::Session::new` 创建两个空 CookieJar；`session_service/session_source.rs::restore` 从 vault 枚举账号并重新登录；`ginkgo_runtime/src/lib.rs` 创建新 Session。没有 Cookie 序列化恢复路径。

因此未记住密码时，进程被杀后需要重新登录；记住密码时，每次冷启动可能重新走密码认证/验证码。此行为 Beta.3 已存在，不能说是 Beta.4 才删除持久会话。

UBAA 的 `LocalCookieStore` / `PersistentLocalCookieStorage` 写 Settings，并按 ConnectionMode 隔离；`LocalAuthSessionStore` 保存认证摘要。它的存储安全策略也需要独立评估，不能直接照搬为明文 Cookie 文件。

### F5：同次登录凭据只修了网关恢复，没有修齐学校恢复【已确认当前不对称】

证据：`session_service.rs::ensure_webvpn_session` 可 fallback 到 `session_credentials()`，但 `silent_login` 仍只读取 vault。未记住密码，网关恢复与学校恢复表现不同。`restore` 成功分支也没有保存本次凭据到这个内存槽。

另一个细节：网关优先用 vault，再用本次输入；若保存新密码失败而 vault 残留旧密码，可能优先使用旧凭据。内存 clone 还保留 captcha_text，验证码不应作为跨认证挑战的复用凭据。需按账号、认证代次与挑战拆分，不扩大密码持久化范围。

### F6：网关成功仍用“存在 Cookie”作弱证明【已确认设计缺口】

证据：`auth/mod.rs::establish_webvpn_session` 在 SignedIn 后只检查 `webvpn_cookie_present()`。网关预登录也能发 Cookie，该条件不能证明可访问目标业务。与 F3 的宽松成功组合尤其危险。

失败时 `ensure_webvpn_session` 无条件把实际路线置 Automatic，即使用户偏好是明确 WebVPN。偏好与实际路线因此可能矛盾；后续请求又尝试直连。

学校恢复和网关恢复仍共用 `automatic_login_failure` 60 秒槽：一边失败会抑制另一边，与 `bd97642` 曾引入的分层保护相反。验证码分支未保存网关 LoginPage，只返回 challenge ID；被回退删除的网关验证页面目前并不存在完整替代链。

### F7：图书馆当前主要问题是认证恢复，不是整个业务协议被改坏【已确认差异范围；实网根因待区分】

Beta.3 → HEAD，`adapters/library_http.rs` 与 `services/library_service.rs` 没有提交差异。场馆、座位等主协议不能归因于这段期间对库文件的直接修改。共享 Session、网关与登录变化足以影响它。

旧缺口：`login_library` 在 WebVPN 上遇到 library_login 才建立网关；直连 CAS 真过期会直接返回错误，没有学校 silent_login 恢复。与签到恢复策略不一致。

UBAA 对照：本项目与 `LocalLibBookApi.kt` 都使用 CAS 获取 cas 参数 → login/user 换业务 token、登录锁与一次业务 token 恢复，基础链路相近。不能通过比较文件名称就建议整段重写。

### F8：签到的业务会话错误与学校会话错误边界仍不完整【已确认恢复路径缺口】

证据：`services/checkin_service.rs::try_fetch_checkin`：缓存 iclass 课程查询遇 BusinessRejected 才立即重建 iclass；SessionExpired 转给学校 silent_login。`adapters/checkin_http.rs::classify_json` 对 401 直接判学校 SessionExpired。业务 sessionId 失效的 401 因而可能触发不必要的全局密码登录。

已缓存 iclass 的 course_schedule 如果切换到网关并返回 webvpn_login_required，不经过 establish_iclass 的网关恢复分支，第一次失败不能就地恢复。下一次失败清理/重试的表现又依赖具体错误码。

UBAA 使用 sessionMutex 与按 studentId 的 sessionCache；但它把多种读取失败吞成 code=200 空列表，因此“UBAA 看着正常”也不能证明请求成功。其签到写恢复还允许重试，不能照搬到本项目单次提交的安全约束。

### F9：工作树正在把多个签到目标合并为任意一个【已确认未提交语义回归风险】

证据：`codecs/checkin.rs::merge_candidates` 的未提交差异。旧实现对同堂、未签到、不同 id 保留独立目标；新实现合并为一行并用排序后第一个 id 作为写入目标，`sign_in_allowed = !conflicting`。

多个 courseSchedId 不自动等价于同一个写目标。只提交第一个不能证明其他记录也完成，且更换上游排序/ID 后会选不同目标。应把一行展示与多个写目标分开，未知语义时禁止任意选 ID。

同时测试由断言四个独立目标改成断言两行，修改了验收标准；测试通过不能证明协议等价。

### F10：网络路线持久化仍存在两个入口不同步【已确认工作树接线缺口】

HEAD 的 Rust preference 和实际 route 均在内存；Beta.3 也没有跨进程保存路线。工作树新增 `AppPreferences.routeMode`、登录页写入和启动 restore 前 setRoute，是局部补齐。

但 `features/settings/settings_page.dart::_changeRoute` 仍只调用 service.setRoute，未写 AppPreferences。随后调用统一 onSignOut，执行实际 signOut/清密码。重启按文件旧值恢复，新登录页也可能重新选择旧路线。因此登录页选路线与设置页选路线行为不一致。

### F11：外观偏好持久化没有找到“拆分时丢失接线”的证据【撤销初步怀疑】

Beta.3 的 AppPreferences 自带文件读写；`efdad39` 抽出 DisplayPreferencesFileStore，同时 main 创建并注入读写实例，并传给各 GinkgoApp。不能只看到 shared 默认空操作就认定生产没有保存。

当前 `DisplayPreferencesFileStore` 仍有临时文件写入与 rename，AppPreferences 串行保存。尚需设备上按具体选项复现：外观、快捷入口、提醒、课程可见性分别有不同存储链，不能用 routeMode 的确定缺口概括所有设置。未进行这些项目的设备重启验收，外观持久化根因保持未确定。

## 测试结果和证据质量

本轮执行：`cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked`：386 单元测试和 1 个共享 fixture runner 通过。仅说明运行时工作树的合成测试通过，不代表 Beta.6 APK、所有平台、实网登录或真实写入通过。`git diff --check` 通过。

最初按 HEAD 旧测试名筛选时运行了 0 项：审查期间该测试被外部修改并改名。没有把这次零测试写成验证通过；随后运行完整 upstream 测试。

测试盲区：缺少完整用户登录动作的密码 POST 计数与成功身份断言、已登录→业务路线变化→网关挑战、无保存密码恢复、进程重启 Cookie 恢复、多 courseSchedId 写目标语义等。现有 mocks 多为预置顺序响应，证明既定脚本可走通，不能独立证明该脚本与学校协议相符。

此前文档中的“实网全部通过”与“完整页面未结束/登录波动”须按当次日期、构建和账号路线理解。不能从局部只读成功推导验证码、过期恢复和冷启动均通过。

## 建议处置顺序

先固定一个不可变候选和脱敏复现矩阵，再实施最小修复；不建议整体覆盖成 UBAA，也不建议无条件退回 Beta.3 后宣称恢复正常。

1. 优先收紧 F3 的登录成功证据，暂停 F9 任意签到目标合并，保留单次写入与结果不明禁止重发。
2. 将用户路线偏好、实际路线、学校认证、网关认证、模块 token 分成明确状态；认证安全 GET 允许有界探测，密码提交按完整用户动作统计。
3. 修复学校/网关失败冷却互相污染、明确 WebVPN 失败后擅自切 Automatic、网关验证码无完整恢复上下文；优先使用本次已确认登录的账号凭据，验证码不复用。
4. 图书馆和签到各自补业务 token/session 恢复，只有学校认证确实失效才触发学校恢复。
5. 网络路线两个入口统一持久化；真正 Cookie 持久化另按安全存储设计审查后实施，不能将“保存密码自动再登录”标为“恢复会话”。
6. 设备验收矩阵至少交叉：自动/直连/WebVPN，记住/不记住密码，冷启动/前后台/强停，校内/校外，正常/验证码/UC 不可用/业务 token 过期。先只读；真实签到和预约仍由本人确认触发。

本文不另建 TODO。后续接受的修复项只进入 `docs/MIRROR-TODO.md`，协议修正以 `docs/API.md` 为唯一事实入口。


## 追加复核：前后端与本轮修复自身的缺口

本次比较仍固定 Beta.3 `32b6a1d`、HEAD `5215a1b`、当前未提交工作树与 UBAA `155e8b56`。不是所有问题都由 UI 修改引起：Beta.3→HEAD 的图书馆业务适配没有提交变化，共享认证改变足以同时破坏多个模块；本轮新增安全存储同样需要反查，不能因为是修复代码就假定正确。

| 编号 | 归属与触发 | 已确认行为及影响 | 本批处置 |
| --- | --- | --- | --- |
| R1 | 前端启动，setRoute 返回类型化失败而非抛异常 | `GinkgoRoot.restore` 忽略返回值，继续恢复；UI 所示路线与实际路线可能不同 | 先检查 failure，失败停在登录页并显示错误，不继续恢复 |
| R2 | 前端设置页，安全存储删除失败 | bridge 的 `failure_response` 也是 signedOut；页面只看 state，把失败当成功，保存错误路线并实际退出 | failure 优先；失败不持久化、不退出；事务结束才解除 busy |
| R3 | 登录/网关验证码超过五分钟，或刷新 GET 返回 503 | 过期连刷新也被拒绝；刷新失败时撤销上下文及 UI ID，使用户只能重新走登录 | 允许所属账号/代次的匹配 ID 显式 GET 换挑战；旧答案过期，刷新失败保留只用于 GET 的上下文；页面保留刷新入口 |
| R4 | 后端新增持久化，反复冷启动或收到 Set-Cookie | `PersistedSession::new` 每次设置当前时间，所谓 24 小时硬上限实际可滑动延长 | Identity 保存认证生命周期起点，恢复和 Cookie 轮换沿用原时间；没有更改学校 Cookie 的自身有效期 |
| R5 | 后端冷启动，UC 返回 503/结构漂移 | 从加密记录直接构造 SignedIn，与“在线验证后发布”文档矛盾；remembered 无条件 true 也误称保存了密码 | 暂时错误保留密文但不发布身份；成功恢复的 remembered 按实际保险库密码判断 |
| R6 | 前端用户反复提交错误密码；后台网关重复恢复 | `bd97642` 加入登录拒绝退避，`b8bcb5d` 后消失；文档仍描述存在。当前网关失败只有 60 秒冷却，历史文档的 30 分钟锁定同样不能当现状 | 本批恢复用户明确密码拒绝的 60/120/300 秒本地退避；学校/网关分别冷却，明确凭据拒绝 30 分钟、暂时错误 60 秒；过期网关挑战仍阻止后台重新认证，等待用户显式刷新 |
| R7 | 文档/协议 | API 同时写 Cookie 未持久化、公开读取继承用户路线；实施页仍说模型解码裸 JSON，与当前源码矛盾 | 同步 API 修订表、隐私与实施说明；历史发布记录不重写 |

R3 旧答案保持失效，允许的是用户显式请求新的 GET；不会为了恢复操作而自动重放密码或答案。R5 只收紧冷进程持久快照恢复，不把已在线验证的同进程身份在临时抖动时全部清空。

### 验证与证据

两项临时合成诊断探针在修复前实际复现了“过期挑战刷新拒绝”及“恢复重置快照时间且无密码仍 reported remembered”。探针日志 `/tmp/ginkgo-repair-20261102/audit-probes.log`；确认后移除临时探针，正式回归改为断言正确行为，不把错误行为固化成验收标准。

正式回归覆盖路线失败不恢复/不退出、连续密码拒绝退避、登录和网关过期挑战 GET 更新、刷新失败再次 GET、原 ID 不可继续使用、原固定期限不被冷启动和 Set-Cookie 延长、无保存密码恢复状态和 UC 暂不可用不发布身份。完整门禁最终结果见修复记录，编译失败或中途日志不计通过。

### 原有诊断的当前状态

F1 历史门控已撤；F2/F3/F5/F6/F7/F8/F10 已有工作树修复及合成回归；F4 已增加 Android 加密快照，本批进一步修正期限/恢复证明；F9 保留不同未签到 ID 的独立目标，禁止任意挑一个代签；F11 外观文件接线仍不能归因为 UI 拆分丢失。以上不等于真实账号全模块验收，尤其登录、验证码、网关恢复仍需真实挑战证据。

进一步重点是完整认证动作的请求计数、登录/网关拒绝分类、过期密码提示的 action/service 上下文、设置保存失败后的可见恢复，以及页面旧响应和账号切换。学校未证实的字段/成功码不补猜测；未完成事项只进 MIRROR-TODO。
