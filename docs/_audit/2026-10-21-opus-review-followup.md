# Opus 5.5 原评审：核实、定位与改进落实

> **原评审作者：Opus 5.5（用户在对话中提供的分析）。**
>
> **本文件的核实、取舍、代码修复与测试记录：Codex，2026-10-21。** 本文件整理原意见并校正过时结论，不将本次实现冒署为 Opus 5.5；原评审中的规模统计和“实际跑过”属于原作者陈述，本次不直接继承。

核对基线：分支 `feat/rust-flutter-mirror`，起始 HEAD `e1d78c0`。本文记录本轮实现；Android Alpha.3 包含本次修复，发布与升级证据见 [Alpha.3 记录](../archive/mirror/MIRROR-ANDROID-ALPHA3.md)。Windows 主机结果见 [PD Windows 11 记录](../archive/mirror/WINDOWS-2026-10-21.md)；旧 Alpha.2 不包含本次修复。

## 采纳并实施

### 1. 共享 fixture 仍不足以约束双端解析

**定位**：[Rust runner](../../rust/crates/ginkgo_upstream/tests/contracts.rs)、[契约路由](../../rust/crates/ginkgo_upstream/src/services/contracts.rs)、[Swift 新 runner](../../BUAA-AssistantTests/SharedParserContractTests.swift)。原有 Swift 测试已共享规则样例，但多数上游解析样例只在 Rust 执行；原评审提出的漂移风险成立，不能据“都在 fixtures/”推断双端已经一致。

**改进**：Swift 递归读取 Rust 同一目录的版本化 JSON，调用生产 CasPageParser、ScheduleParser、GradeParser 和 SPOC 加密实现，对同一 `expected` 断言。只转换属性命名、缺值 null、稳定错误码；没有复制响应、重写解析算法或修改期望来消除差异。首批覆盖 CAS、学期 / 周次 / 本科课程 / 考试、成绩 / 学期码、SPOC 加密。iOS 工程通过 XcodeGen 再生成以纳入测试，未手改工程。

**验收**：本轮 9 类、17 份共享解析样例通过，macOS 与 iOS 模拟器全量共享单元测试通过。签到、图书馆、博雅、研究生及 SPOC 列表 / 详情仍待扩，不宣称全库跨语言一致。覆盖清单只维护在 [fixtures 说明](../../fixtures/README.md)。

### 2. Rust 锁中毒导致后续调用反复 panic

**定位**：[内存锁封装](../../rust/crates/ginkgo_upstream/src/foundation/mutex.rs)、[SessionService](../../rust/crates/ginkgo_upstream/src/services/session_service.rs)、[HTTP Session](../../rust/crates/ginkgo_upstream/src/auth/session.rs)、[MemoryVault](../../rust/crates/ginkgo_upstream/src/auth/vault.rs) 及各 application 服务缓存。

**校正原判断**：`std::sync::Mutex` 中毒后 `.expect()` 会再次 panic，这个可靠性问题成立；但“任意 panic 跨 FFI 都会直接 abort”对本项目过度概括。锁定的 FRB 2.12.0 handler / executor 已有 `PanicBacktrace::catch_unwind`，生成入口并非简单裸 FFI。捕获 panic 也不会自动修复中毒状态，因此仍需处理。未采用原文未经本轮同口径复核的“306 处”数字。

**改进**：不新增 parking_lot 依赖，也不盲目保留可能写到一半的复合状态。可丢弃的身份、Cookie、缓存和内存凭据中毒后，在持锁期间整体重置为安全空值，再清除 poison；下一次读取不会继续 panic。单一 Copy 路线枚举中毒后保留完整值，避免把显式直连 / WebVPN 悄悄重置成自动。同步 guard 不跨 await，原有 generation、异步 gate 和 bridge 生命周期锁保持职责。

持久化的 [Keyring 锁](../../rust/crates/ginkgo_upstream/src/auth/platform/keyring_vault.rs) 与 [待办存储锁](../../rust/crates/ginkgo_core/src/tasks_store.rs) 本来就将中毒转换为 AppError，保留此行为。测试中的 expect、受控结果校验与 LazyLock 正则不做机械替换。恢复策略不保证修复所有 panic，也不适用于 durable 数据。

**验收**：身份 / 缓存中毒回归先在旧实现失败、改后通过；跨线程中断更新后清空重建、后续读写正常，路线保留及 poison 清除有单独回归。恢复理由依据 [Rust Mutex poisoning 文档](https://doc.rust-lang.org/std/sync/struct.Mutex.html#poisoning)：中毒只说明不变量可能受损，取回 guard 本身并不能证明状态正确。

### 3. 身份字段拆散，清理和发布难以保证完整

**定位**：[session_service.rs](../../rust/crates/ginkgo_upstream/src/services/session_service.rs) 的 `Identity`、`AuthenticatedIdentity`、`status`、`set_authenticated`、`update_profile`、`clear_identity`；业务 token 引用同步调整到 checkin / library / cgyy 服务。

**改进**：account 与 profile 作为一个可选登录态，待续登录页、iclass 会话、library / CGYY token 统一放进一个身份锁。登录成功整体替换，退出 / 切路线整体清理，状态读取一次获得账号与 profile；静默恢复只更新仍属同一账号的 profile。新增身份字段可通过 Default 进入统一清理路径，不再维护散落字段列表。

**边界**：原 bridge 已用生命周期 RwLock 排斥登录 / 退出等独占操作与查询；原评审未提到这一层，不能断言正常 FFI 用户一定能观察到任意中间态。本次改进让 core 自身的同步发布不变量更明确，不以合并一个锁替代跨 await 的生命周期管理。

**验收**：并发读写循环只允许“账号与 profile 同属一个身份”或“均无”；替换身份 / 切路线清空全部业务凭据。旧的退出、迟到 token 响应和并发恢复测试继续通过。

### 4. Flutter 复杂异步页面需要明确状态所有者

**定位**：[LibraryController](../../flutter/lib/features/library/library_controller.dart)、[LibraryPage](../../flutter/lib/features/library/library_page.dart)、[控制器回归](../../flutter/test/library_controller_test.dart)，原有 `library_progressive_widget_test.dart` 与 `write_actions_widget_test.dart`。

**校正**：`setState` 数量不能单独证明架构错误。座位回查结果通知原图书馆页的 `onReservationChanged` 回调在起始代码已存在，原评审把过去 bug 当作现状的部分过时。

**改进**：只为图书馆根页引入 ChangeNotifier，集中场馆 / 当前预约快照、独立错误与加载、并发请求合并、提交状态和待核实动作；保留既有多层回调，将其统一接到强制回查队列。写前尚未完成的旧读取先结束，再发新读取，避免将旧请求合并误当成写后回查。页面销毁后停止通知，但完成已开始操作的回查；写请求仍只发一次。选择器 / 搜索 / 导航保留局部状态，不引入全局依赖。

**验收**：回归覆盖旧读取与写后回查重叠、重复触发只写一次、销毁后不通知且回查完成、待核实动作继续禁重发；原分区独立加载、失败保留和跨路由回查回归继续通过。

### 5. 状态颜色缺少统一语义

**定位**：[AppleDesign](../../flutter/lib/design/apple_design.dart)，签到 / 作业 / 图书馆 / CGYY 页面；[对比度回归](../../flutter/test/status_palette_test.dart)。

**校正**：旧分析所说“只有四个 token”已不符合基线，文件已有资源场景色；但多个业务状态仍在页面直接选 systemGreen / Orange / Grey，改进空间成立。

**改进**：集中 `statusSuccess / Pending / Uncertain / Danger / Inactive` 的浅 / 深色，页面按已有业务状态选择 token；不从颜色推导可预约或可签到。保留文字、图标与操作条件，表面色透明混合不降低文字阈值。

**验收**：深浅色、三类 Cupertino 系统表面和 8% / 12% / 20% 同色底，文字对比度均达到 4.5:1；原页面状态断言同步为语义 token。初次检测暴露浅色 pending 徽章约 4.4:1，调整配色后通过，未放宽阈值。这不是全模块读屏或真实设备验收。

### 6. 文档入口重复，旧统计与现状互相矛盾

**定位**：[现状](../MIRROR-IMPLEMENTATION.md)、[待办](../MIRROR-TODO.md)、[对照](../MIRROR-PARITY.md)、[历史索引](../archive/mirror/README.md)、仓库 / Flutter / Rust README、[TESTING](../TESTING.md) 与 fixtures README。

**改进**：三个稳定入口分别维护现状、待办与模块差距；旧计划、发布和验收记录归档保留，原先相互重复的 implementation / todo 快照也保留。更新相对链接、API 证据引用和首页说明入口。README 删除手工测试总数，修正“作业仍为合成、图书馆 / 签到未迁移”等明显过时描述。具体运行数量只在带日期的证据中出现。

**边界**：归档减少活跃维护面，不伪称文档字节数减少；历史证据不删除，其“当前”以原日期解释。[API](../API.md) 仍是上游协议事实源，本轮未修改协议规则。

### 7. 落地页中文辅助字号过小

**定位**：[landing.css](../landing.css) 的图注、元信息、脚注及手机覆盖规则。

**改进**：原有 9 / 10 / 11px 小字统一提高到 12px。保留既有字体回退、颜色、页面结构和免外部字体请求策略；不为修字号重做落地页。

**校正**：当前 hero 已有“选择你的平台”与四个平台提示，1440×900 下按钮位于约 y=542–590，390px 下同样可达；无需重复增加入口。移动长页面和本机字体跨平台差异仍存在，不能把字体声明当作字体实际已加载。

**验收**：Chromium 1440×900 / 390×844 内部读图，DOM 计算字号最低 12px，两宽度 scrollWidth 等于 viewport，无横向溢出。Serif Enforcer 0 违规 / 0 警告，既有六对配色检查通过。内部截图不提交；未做 Windows 浏览器字体人工验收。

## 保留为后续工作，未盲目照搬的意见

| 原意见 | 当前定位与取舍 | 完成条件 |
| --- | --- | --- |
| Swift 解析与网络未彻底分离 | LibraryClient、CheckInClient、CgyyClient 仍混合模型 / 请求 / 解析；问题成立。本轮优先加契约，未批量移动生产 Swift | 逐模块抽纯解析器并复用同源样例，两端编译 / 回归通过 |
| 三套 UI 与大文件带来重复 | macOS / iOS 壳不同且共享 Swift 业务层；Flutter 服务 Android / Windows。平台 UI 分开不是自动成立的缺陷 | 优先共享领域规则、测试与状态语义，按变化职责拆文件；不要求三端控件同源 |
| 生成代码稀释统计 | FRB 生成物占比随版本变化，不复用旧百分比 | 审查排除生成目录，修改 API 后检查生成漂移 |
| Flutter 无障碍不足 | Semantics / textScaler 次数只是线索；全量 TalkBack / VoiceOver、大字号 / 减少动态效果仍未闭环 | 按模块任务实测，不能用 palette 测试替代 |
| 桌面 / 手机完全不按宽度切换 | **已过时**：main.dart 的 LayoutBuilder 已按 760px 切换 | 本轮 Windows 宿主窄窗 / 回宽、独立详情栈与键盘基础已通过；完整平台验收仍有边界 |
| Android 仅 Alpha.1、作业等未接入 | **已过时**：仓库已有 Alpha.2 发布与多模块真实只读记录 | 源码、发布包、实网三者分开；最新认证失败不能抹掉，也不能隐瞒 |
| 只读成功不能证明写安全 | 采纳；已有单次写入 / 确认 / 回查，真实签到与预约尚未验收 | 人工逐次操作并回查，未知结果禁重发 |
| 缺高频提醒 / 后台 / 作业提交 | 当前 Flutter 仍有这些差距 | 按平台能力和真实协议逐项实现，不以 UI 对齐替代 |
| 首次登录解释不足 | Keychain、CAS、WebVPN 与路线切换确有多步门槛 | 就地说明依赖与失败后选择；不削弱会话或 Secure Cookie 约束 |
| Windows 构建“已通” | 工程、CI 和结构验证已有基础；这些结果不代替用户指定 PD 来宾上的交互验收 | 已使用 Parallels Windows 11 ARM 完成 x64 构建、保险库与合成集成；详见 Windows 记录，不宣称物理 x64 或真实业务通过 |

## 本轮自动化与人工检查

以下只属于此工作树和此次运行，不累加历史次数；无真实账号或上游写入。

| 检查 | 实际结果 |
| --- | --- |
| `cargo test --manifest-path rust/Cargo.toml --workspace --locked` | 核心 181 项、递归契约 1 项、bridge 1 项、doc-test 1 项通过 |
| `cargo clippy ... --workspace --all-targets --all-features --locked -- -D warnings` | 通过 |
| `cargo fmt --manifest-path rust/Cargo.toml --all --check` | 通过 |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub test` | 当次全量 91 项通过 |
| macOS `xcodebuild test` | 220 项通过，xcresult summary 确认 |
| iOS `xcodegen generate --spec project.yml` 后共享单元测试 | iOS 27.0 / Ginkgo iPhone 17 Pro：220 项通过，未运行 UI / live |
| `flutter build apk --debug --target-platform android-arm64 --no-pub` | 成功；含 aarch64 Rust 动态库。插件 NDK 28 提示仍存在，沿用项目 NDK 27，未为提示更换工具链 |
| Chromium / Serif Enforcer / 对比度 | 1440 / 390 检查通过；字体和宿主边界见上文 |

远端 CI 补充：运行 39581062229 的 Rust 契约、Android 构建、Windows 构建 / 测试 / 产物检查均通过；bindings 因 CI 未安装 rustfmt 而得到未格式化的 Rust 生成物，触发差异门禁。补装组件，并在生成脚本先检查 rustfmt；本地重新生成无差异，缺失工具的故障注入正确退出。修复后的远端结果另以对应 CI 运行记录为准。

随后生成门禁已通过，冷环境分析暴露 vendored Cargokit 独立 Dart 包未解析依赖；本地已有构建缓存曾掩盖此项。移开该包的 .dart_tool 可复现，执行其 dart pub get 后分析恢复通过。CI 与本地检查入口补齐这一准备步骤，不排除目录或降低诊断级别。

本轮未改 TLS 信任、平台 Keychain API、权限或上游写协议；身份锁重构仍需关注退出 / 切路线与业务凭据清理。Android 签名 Release、覆盖升级与合成设备测试见 [发布记录](../archive/mirror/MIRROR-ANDROID-ALPHA3.md)；Windows 主机两项集成、91 项 Flutter 回归、Rust 全量及 Debug / Release 已通过，证据与限制见 [Windows 记录](../archive/mirror/WINDOWS-2026-10-21.md)。
