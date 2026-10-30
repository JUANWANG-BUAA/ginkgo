# 真实账号只读验收与重大问题修复：2026-10-29

授权：账号本人明确要求使用其真实账号测试全部功能与页面。全程**只读**：未提交签到、预约、作业、校园卡等任何学校写操作；图书馆选座确认框仅打开即取消（沿用既有验收管线的做法）。凭据只经进程环境变量与 loopback 临时通道下发，未写入仓库、日志或提交；含真实姓名/学号的截图仅存于本机 `/tmp/ginkgo-live-harness/`，不入库。

环境：macOS ARM64 宿主 + Android API 37 arm64 模拟器（`Medium_Phone_API_37.0`，`emulator-5554`），工作树为 Beta.2（`0.1.0-beta.2+12`）之后的未发布改动。本地全量门禁 `bash scripts/check-mirror.sh` 于 14:05 通过（Flutter 624 项、Rust 全量、严格 Clippy、FRB 一致性）。

方法：两条独立证据链。
1. 既有 opt-in 管线 `integration_test/live_acceptance_test.dart --dart-define=GINKGO_LIVE_ACCEPTANCE=true`：真实登录表单 + 35 项读接口 + 页面渲染，报告与截图经 `adb reverse tcp:18764` 回传临时接收器。
2. 人工式 UI 走查：安装正常入口 Debug APK，经无障碍树与坐标驱动真实界面，逐页截图并记录用户可见文案（`/tmp/ginkgo-live-harness/walk1-6.txt`、`ui/*.png`）。

## 读接口与页面结果

| 模块 | 结果 | 证据 |
| --- | --- | --- |
| 登录（CAS 表单） | 通过，真实会话建立 | 管线 `login-form signedIn=true`；UI 工作台出现真实课表/作业 |
| 工作台 / 课表 / 签到 | 通过（真实数据：今日 1 节课、已签到 1 未签到 1） | walk1；耗时页 iclass 0.22s |
| 作业列表 / 详情头 | 列表通过（待完成 2、已截止 4）；详情见 F1 | walk1/walk4 |
| 成绩 | 通过（本学期空，符合一年级进度） | walk1 |
| 博雅 / 研究生教务 / 学分图 | 通过（106 门课程；方案 0/32 学分） | walk1/walk4；耗时页执行报告 10.14s |
| 图书馆在馆 / 座位 | 通过（学院路 1579/2269） | walk3 |
| 空教室 / 研讨室 | 通过（158 间 4 页；场馆列表真实） | walk3 |
| 校车静态时刻表 | 通过（实时余票按设计未接通，文案诚实） | walk1 |
| 校园卡余额 | 通过（金额按设计遮挡，15:38 读取成功） | ui/campus-card-after-query.png |
| 待办（本机） | 通过（空态正确） | walk4 |
| 设置及自检 / 耗时 / 更新 | 通过（自检 4 项全过；更新检查返回 Beta.2） | walk5/6；管线 `update` |
| 校园通知 | **失败**：`serviceUnavailable`，UI"学校服务暂时不可用" | 管线 + walk1；见 F2 |
| 图书馆公开在馆统计 | **间歇失败**：管线 `serviceUnavailable`(6.1s)，同时刻自检与耗时页通过 | 管线 vs walk6；见 F2 |
| 本人借阅 | 失败（已知 G10 认证循环，复现） | walk1 |
| SPOC 作业详情 | **间歇失败**：报"学校会话已失效"且重试不自愈，同时刻其他模块会话有效 | walk4 + 耗时页对照；见 F1 |

## 缺陷清单

### F1（P0，待修）单模块认证反弹被报成全局会话失效，且重试不自愈
登录后 1–20 分钟内，签到首跳或 SPOC 作业详情被学校弹回 CAS 登录页时，页面报"学校会话已失效，请重新登录"。关闭"记住密码"时静默重登无凭据，全 App 立刻不可用且"重试"无效；开启时签到可自愈，但作业详情"重试"仍失败，而同一时刻设置页"学校接口耗时"强制刷新 5 个模块全部成功（iclass 0.22s、研究生学籍 0.30s、执行报告 10.14s），证明会话并未全局死亡。即：错误文案夸大了故障范围，且 SPOC 详情的静默重登链对学校当前跳转行为不可靠。这是 [2026-10-21 认证事故](2026-10-21-auth-redirect-incident.md)（UC→HTTP SSO 跳转）在 Beta.2 上的真实复现，对应 `docs/MIRROR-TODO.md` P0 未闭环项。未做半吊子修复：根因在学校跳转链与静默重登范围，需带真实凭据的协议级取证。

### F2（P1，本轮已修，待真机复验）公开匿名读取继承 WebVPN 路线必败
`send_anonymous` 原样采用传入路线；会话一旦切到 WebVPN，校园通知、图书馆公开统计等"同主机 HTTPS 校验"的公开读取只能拿到网关主机或登录重定向，校验必败（通知 117ms 即败，符合"立即被重定向"的特征）。匿名传输不携带网关 Cookie，网关路线对公开页在现实中不可能成功。修复：`session.rs` 的 `send_anonymous` 将 `WebVpn` 归一为 `Direct`；新增回归 `notices_stay_direct_when_the_session_route_switched_to_webvpn`（修复前红、修复后绿）；同步修正 shuttle 两个把"匿名走网关"当预期的旧测试。上游 376 项测试通过。

### F3（P2，待修）登录页"记住密码"默认开启
与仓库安全约定"密码只在用户选择记住密码后写平台保险库"不符；且结合 F1，多模块可用性实际隐式依赖存密码。修复：默认改为关闭，新增 `login_layout_widget_test.dart` 断言开关初值为关。

### F4（P0/P1，待真机复核）壳内页面文本输入无法触摸聚焦
课表搜索框、查书目搜索框在模拟器上点击不聚焦、软键盘不弹、`input text` 不进入；同页按钮/排序点击正常，登录页输入框正常。曾假设 `workspace_tab_transition.dart` 每帧 `setFirstFocus` 抢焦点并加回归测试，但该测试在修复前后均通过，假设不成立，已撤销改动与测试，不做假修复。现有 widget/integration 测试用 `enterText` 绕过真实焦点，抓不到此类缺陷。需在物理设备与不同 AVD（软/硬键盘）上复核后定位。

### F5（P2，待修）无障碍语义节点合并错乱
校园卡"查询余额"按钮的语义节点覆盖整张卡 `[0,179][1080,763]`；作业行文本被并入底部标签栏节点 `[0,2214][1080,2400]`（本次走查因此误点到标签栏）。TalkBack 与自动化定位会点错目标。触摸命中本身正常（几何点击可打开作业详情）。

### F6（P2，本轮已修）live 验收管线页面阶段长期中断
`live_acceptance_test.dart` 取 `homework.items.first` 定位行，但页面默认收起"归属已确认的助教课程"，首条读取项可能没有渲染行，`show()` 滚不到目标后抛 `StateError: No element`，导致 bykc/图书馆/空教室/通知/研讨室/待办/设置/工作台的真实页面断言与截图自某次改版后从未执行（35 项读接口仍全通过）。修复：改取"第一个真实渲染的行"。

### F7（信息）本人借阅仍为已知 G10 认证循环；Android 包 User-Agent 为 macOS Safari 串（`reqwest_transport.rs`），library_stats 又覆盖为 `Ginkgo/1.0`，平台身份不一致。

### F8（信息）就业活动、学术文化不在移动端服务目录，仅经本地服务搜索（`service_search_page.dart`）可达；是否为有意设计待确认。

## 本轮修复与验证

| 修复 | 文件 | 验证 |
| --- | --- | --- |
| 匿名公开读取不再继承 WebVPN 路线 | `rust/.../auth/session.rs` | 新回归先红后绿；`cargo test -p ginkgo_upstream` 376 通过；fmt/clippy 干净 |
| shuttle 旧测试改为直连预期 | `rust/.../adapters/shuttle_http.rs` | 同上 |
| 记住密码默认关闭 | `flutter/lib/features/auth/login_page.dart` | `login_layout_widget_test.dart` 新断言通过；`flutter analyze` 无问题 |
| live 管线取首个渲染行 | `flutter/integration_test/live_acceptance_test.dart` | 待下次真机验收复跑确认页面阶段不再中断 |
| core 回归 | — | `cargo test -p ginkgo_core --no-default-features` 通过 |

事故记录：修复过程中一次 `git checkout -- <file>` 丢弃了 `session.rs` 中用户未提交的在制改动；已从 dangling stash 提交 `efd65e8` 完整恢复（含在制测试模块），并确认恢复后 diff 与事故前一致。后续对该工作树不再使用丢弃式 git 命令。

## 未覆盖边界

学校写操作全部未执行；作业附件下载、SPOC 公告/资源列表、加密学习快照导入导出、WebVPN 路线实网、物理设备/TalkBack/大字号/帧率、Windows 主机均未验收。模拟器结论（尤其 F4）不等于真机结论。合成与模拟器通过不等于真实业务验收。
