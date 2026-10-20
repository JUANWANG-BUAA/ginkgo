# Rust + Flutter 镜像实施与验收

> 2026-10-20 启动。Android 以 iPhone SwiftUI 为视觉参照，Windows 以 macOS SwiftUI 为参照；按模块迁移，每个已迁移用例都要覆盖正常、空态、失败与恢复。完整产品范围见 RUST-FLUTTER-PORT.md。

## 当前边界

已创建 `rust/` Cargo workspace 与 `flutter/` Android/Windows 工程。Rust 核心、生成桥接、Flutter 页面形成真实进程内调用链，不是 Dart 仿造 Rust 返回值。

当前可执行的是**五个离线切片**：今天、空教室、课表、作业、成绩。它们都经过 Rust bridge 与 Flutter 页面，其中今天/课表/成绩/作业已在 Android 实机通过真实 FFI 测试；空教室前 3 项设备测试通过，后续校区/日期/错误流程在测试框架内卡住，未标记全绿。所有页面仍使用共享合成 fixture，不连接真实学校账号。

Rust 侧已补齐认证核心：进程内 Cookie jar、CAS 登录页解析与表单提交、手动重定向与错误分类、UC 激活/会话校验、自动/直连/WebVPN 路由隔离、过期会话的单次恢复，以及基于 `reqwest + rustls` 的真实传输（已在 macOS 编译、Android aarch64 交叉检查通过）。当前仍**未接入平台凭据存储、Flutter 登录页面或真实账号只读验收**；空教室 bridge 继续使用合成仓库。演示缓存不落盘，不读取 Apple 缓存。整个镜像项目尚未完成。

课表模块已开始 P2：Rust 已迁移学期、教学周、本科周课表与考试响应的严格解析，补齐请求构造（门户探测、Ajax 头、表单参数、考试专属 Referer）与 mock HTTP 测试；Flutter 增加课表页、周次切换、周网格/列表双视图、考试区和移动端底部 Tab。当前仍使用共享合成 fixture，未接真实账号。

成绩模块已开始 P3：Rust 迁移 buaascore 学期码归一化（本科 `YYYY-YYYY-S` 与研究生 `YYYYYS`）、成绩响应解析、学分/成绩类型漂移处理与加权平均/绩点汇总；Flutter 增加成绩页、汇总卡和课程分数列表，并接入第三个移动 Tab 与桌面侧栏。实机测试 `grades_test.dart` 已通过真实 FFI。

今天页已开始迁移：Rust 迁移 BYXT 当天教学安排（`rq`/`lxdm=student`）的请求与解析，Flutter 增加“今天”Tab、日期/星期和课程时间线。实机测试 `today_test.dart` 已通过真实 FFI。

作业模块已开始迁移：Rust 迁移 SPOC 分页参数 AES-CBC/零填充/Base64（与 Apple 黄金向量一致）与作业页解析；Flutter 增加“作业”Tab、状态筛选和只读列表。实机测试 `homework_test.dart` 已通过真实 FFI。SPOC token/CAS 登录链与作业详情尚未迁移。

## 完成度快照（2026-10-20）

| 能力 | 状态 | 证据 |
| --- | --- | --- |
| Rust workspace、FRB 桥接、Flutter Android 壳 | 完成 | `scripts/check-mirror.sh` 通过；`mirror.yml` 已入库 |
| 共享契约与 fixture | 16 类、58 份 | Rust runner 递归执行全部 fixture |
| 认证核心（Cookie/CAS/UC/WebVPN/恢复） | 离线与 mock 完成 | 认证单元/流程/mock HTTP 测试 |
| 真实传输（reqwest + rustls） | 编译验证完成 | macOS 编译、Android aarch64 交叉检查 |
| 平台凭据 store + bridge 登录 | 未开始 | 目前只有 `CredentialSource` trait |
| 今天 / 空教室 / 课表 / 作业 / 成绩页面 | 5 个合成切片完成 | Flutter 11 项 widget 测试；5 个底部 Tab |
| Android 实机验收 | 4 个模块通过，空教室部分通过 | 今天/作业在当前五 Tab 外壳通过；课表/成绩在四 Tab 外壳通过，页面代码未变；空教室前 3 项 |
| 真实账号只读 bridge | 未开始 | bridge 仍只暴露 `load_demo_*` 与演示查询 |
| Windows 构建与实机 | 未开始 | 只有工程与 CI 入口 |
| 研究生课表、BYKC、图书馆/研讨室/场馆/通知 | 未开始 | 仅有 BYKC 纯规则与现有文档 |
| 本地待办/设置/账号切换/通知 | 未开始 | — |
| 写操作与发布 | 未开始 | — |

### 距离目标还差什么（按阻塞顺序）

1. **真实登录链路**：Android Keystore / Apple Keychain 的 `CredentialSource`、bridge 登录/登出/会话对象、验证码图片与输入页面。没有这一步，所有模块都只能停在合成 fixture。
2. **真实只读 bridge**：把今天、空教室、课表、成绩、作业从 `load_demo_*` 切到真实 Rust use case，并补持久化缓存、账号隔离、会话失效恢复和“失败保留旧结果”。
3. **P2 剩余**：研究生 GSMIS 课表、学期切换、缓存周次刷新与旧快照保留的设备验收。
4. **作业剩余**：SPOC token/CAS 登录链、课程/学期上下文、只读详情；希冀来源继续关闭。
5. **P3 其余模块**：BYKC、图书馆、研讨室、场馆、校园通知（只读优先）。
6. **P4 本地能力**：本地待办、设置、账号切换、缓存清理、通知权限、外链与日志脱敏适配器。
7. **Windows 主机构建与实机验收**；当前没有任何 Windows 通过记录。
8. **视觉与可访问性闭环**：每个模块的固定视口浅色/深色/大字号截图、TalkBack/VoiceOver、减少动态效果；当前只有外壳和部分页面。
9. **写操作**：签到、预约、取消、选课等，逐项协议证据、二次确认、提交后回查与“未知结果不重发”。
10. **发布**：Android/Windows 安装、升级、签名、隐私说明与发布流水线。

## 工程入口

| 层 | 路径 | 责任 |
| --- | --- | --- |
| 领域与基础规则 | `rust/crates/ginkgo_core/src/features/`、`foundation/` | 教室规则、BYKC 分类、IANA 上海时区、课表周次 |
| 应用用例 | `rust/crates/ginkgo_core/src/application/` | typed 输入校验、合成查询、缓存策略 |
| 桥接 | `rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs` | DTO、稳定错误枚举与映射 |
| Flutter 绑定 | `flutter/lib/src/rust/` | FRB 2.12.0 自动生成 |
| 页面与外观 | `flutter/lib/classroom_page.dart`、`classroom_detail.dart`、`schedule_page.dart`、`schedule_grid.dart`、`apple_widgets.dart`、`apple_design.dart` | 页面状态、导航、周网格/列表、样式和交互 |
| 设备测试 | `flutter/integration_test/mirror_test.dart`、`schedule_test.dart`、`support.dart` | 真实 Rust 动态库 + Flutter UI；按模块拆分的快速设备用例 |
| 截图驱动 | `flutter/test_driver/integration_test.dart` | 保存 PNG；不把截图成功误报为相似度通过 |
| 认证 | `rust/crates/ginkgo_core/src/auth/` | `cas` 解析、`login` 登录链、`uc` 会话校验、`session` Cookie/路由 |
| 真实传输 | `rust/crates/ginkgo_core/src/adapters/reqwest_transport.rs` | 30 秒超时、禁用自动重定向、Android/macOS 编译验证 |

工具版本和运行命令见 [Flutter README](../flutter/README.md)。`scripts/check-mirror.sh` 运行 Rust 格式、Clippy、契约及 Flutter 检查；`scripts/generate-mirror-bridge.sh` 生成绑定。CI 配置见 `.github/workflows/mirror.yml`，远端结果必须单独确认。

## 用例覆盖矩阵

| 用例 | Rust | Flutter widget | Android 设备 |
| --- | --- | --- | --- |
| 共享契约，含正常/空结果/结构漂移/无效输入 | 16 类 58 份 fixture runner | — | 今天/教室/课表/成绩/作业切片经过真实 FFI |
| 校区 1/2/3、无效校区、无效日期 | repository 单元测试 | 浮动校区菜单 | 查询范围流程 |
| 日期选择、今天/明天、跨北京时间午夜 | 学校日期与 repository 测试 | 初始加载 | 日期流程 |
| 1–14 节、全部最少/连续空闲选项、三种排序 | shared fixtures + typed 校验 | 最新结果优先 | 逐选项及组合流程 |
| 搜索、清空搜索、零匹配、清除全部筛选 | fixture | 过期响应丢弃 | 搜索及恢复流程 |
| 详情的 14 节、空闲/未标空闲语义 | Rust 提供完整 section states | — | 逐节与返回导航 |
| 五分钟缓存、过期、日期隔离、强制刷新 | 可控缓存时间测试 | — | 缓存复用、工具栏刷新、下拉刷新 |
| 稳定错误码、重试、旧结果保留 | 无效 typed 请求 | 失败恢复、销毁后响应 | 原生错误与重试 |
| 深色、放大文字、宽屏导航、页面过渡 | — | 外观、菜单语义、导航字体回归 | 深色放大文字流程 |
| CAS 登录页/验证码/提示解析 | 2 份共享 auth fixture + 单元测试 | — | — |
| CAS→UC 登录、错误分类、重定向上限 | mock HTTP 流程测试 | — | — |
| Cookie 域/路径/过期、直连与 WebVPN 隔离 | jar 与会话测试 | — | — |
| 会话过期单次恢复 | mock HTTP 端到端 | — | — |
| 学期/教学周/本科课表/考试解析 | 7 份共享 schedule fixture + 契约测试 | — | 课表 Tab 经真实 FFI |
| 课表请求构造与门户判定 | 6 个 mock HTTP 测试 | — | — |
| 周次切换与未缓存周次 | —（Rust 快照规则已有测试） | 课表页 widget 测试 | 课表 Tab 流程 |
| 课表周网格/列表、课程详情 | — | 网格块点击与 sheet、列表回退 | `schedule_test.dart` 实机流程 |
| 成绩学期码/成绩解析/汇总 | 6 份共享 grades fixture + 契约测试 | — | 成绩 Tab 经真实 FFI |
| 成绩请求构造与会话激活 | 4 个 mock HTTP 测试 | — | — |
| 成绩汇总与课程分数 | 汇总公式单元测试 | 成绩页 widget 测试 | `grades_test.dart` 实机流程 |
| 今天课程请求/解析 | 3 份 today fixture + mock HTTP | — | 今天 Tab 经真实 FFI |
| 今天日期/课程时间线 | — | 今天页 widget 测试 | `today_test.dart` 实机流程 |
| SPOC 分页加密（AES-CBC/零填充/Base64） | 黄金向量 + 契约测试 | — | 作业 Tab 经真实 FFI |
| SPOC 作业页解析与状态映射 | 3 份 homework fixture | 作业页筛选 widget 测试 | `homework_test.dart` 实机流程 |
| SPOC token/CAS 登录与作业详情 | — | — | 未迁移 |

设备执行结果、截图与视觉差异见 [视觉审查](MIRROR-VISUAL-AUDIT.md)。测试覆盖的是当前离线切片，不代表真实学校查询已验收。

## 整体迁移清单

| 模块 | 状态 | 下一步 |
| --- | --- | --- |
| 核心/桥接/Android 壳 | 已创建；正在按设备结果完善 | 保持可重复生成与构建 |
| 空教室 | 离线规则与 UI 切片；HTTP/会话恢复已有 mock 测试 | 真实只读 bridge 与用户授权验收 |
| 学校时间 | 当前 fixtures 已对齐 | 扩展学期/教学周日期边界 |
| 课表 | 学期/周次/本科课表/考试解析 + mock HTTP + 周网格/列表页面 | 真实账号只读、研究生课表、缓存周次刷新 |
| BYKC | 搜索与类别过滤规则 | 学期策略、客户端与页面 |
| 成绩 | buaascore 请求/解析/汇总 + 合成页面 | 学期切换、缓存与真实账号只读 |
| 今天 | BYXT 当天课程解析 + 时间线页面 | 跨午夜日期切换、真实账号只读 |
| CAS / UC / WebVPN | Cookie 会话、登录链、UC 校验、路由与恢复已迁移并通过 mock 测试 | 平台凭据 port、验证码 UI、真实账号只读验收 |
| 凭据与账号缓存 | 仅定义 `CredentialSource` port | Android Keystore/Apple Keychain 实现与 bridge 登录入口 |
| 学校作业 | SPOC 分页加密/列表解析 + 合成页面 | token/CAS、详情、希冀来源与真实账号只读 |
| 研究生教务（GSMIS） | 未移植 | 学期/周次/课表解析与页面 |
| 图书馆 / 研讨室 / 场馆 / 校园通知 | 未移植 | 优先只读数据与失败分类 |
| 签到 / 本地待办 / 设置 | 未移植 | 区分本地操作与上游写操作 |
| Windows | 工程与 CI 入口已创建 | Windows 主机构建/实测及 macOS 布局对齐 |
| 完整导航外壳 | 手机五 Tab（今天/空教室/课表/作业/成绩）与桌面侧栏已接入 | 图书馆/更多、视觉与可访问性闭环 |

预约、取消、选课、签到提交继续按 COLLABORATION.md 的独立写操作评审与人工触发规则执行。

## 已知工程限制

- 复杂 Unicode 房号的本地化排序还需要更广的共享 fixtures；当前自然排序验证覆盖样例中的数字/拉丁房号，不能推断所有 Apple locale 排序已一致。
- 新增的错误码 fixtures 目前由 Rust 应用边界消费；Swift 已有四份起始黄金样例的对应测试，不能把 Rust 错误边界结果算作 Swift 也已验收。
- Windows CI 尚无远端通过记录；macOS 本地检查不代替 Windows 构建与交互验收。
- 当前展示材质由 Flutter 实现，未调用 Apple 原生 Liquid Glass。视觉相似度必须通过截图与交互复核，不能用组件名称或构建成功宣称接近 100%。
- 认证链目前只有 mock HTTP 与编译级真实传输验证；没有平台凭据 store，因此 bridge 尚未开放真实登录。`reqwest` 传输不得在 Dart 侧持有 Cookie。
- 验证码只返回挑战对象，尚无图片展示/输入页面；真实风控触发时的 UI 仍是未完成项。
- 课表当前只迁移本科 BYXT；研究生 GSMIS 仍缺解析与页面。
- 成绩当前只有合成学期与一门演示学期；学期切换、成绩缓存和真实账号验收仍未完成。
- 作业当前只有 SPOC 分页加密与列表解析；token/CAS 登录链、课程/学期上下文、只读详情、希冀来源和真实账号验收均未完成。
- 今天/课表/成绩/作业都没有持久化缓存或账号隔离；页面每次只读取合成 fixture。空教室只有进程内演示缓存。
- bridge 尚未暴露真实会话对象、登录、登出或任一真实只读用例；真实传输虽已编译，但还没有从 Flutter 到学校上游的完整链路。
- 视觉只完成了外壳和部分页面截图复核；iOS/macOS 每个模块的固定视口、深色、大字号与 TalkBack/VoiceOver 闭环仍未完成。

维护边界、fixture 治理、桥接演进与各层证据要求见 [MIRROR-MAINTENANCE.md](MIRROR-MAINTENANCE.md)。
