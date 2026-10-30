# 无障碍语义边界与模块级认证取证（2026-10-30）

## 范围

本批处理 2026-10-29 真实账号验收遗留的 F4、F5 与 F1。只做取证与代码层分离：不使用真实凭据、不执行学校写操作、不改变学校协议。工作树含未提交的 DTO 迁移，本批原地小步修改，不重置、不清理、不提交。

## F4：壳内文本输入触摸不聚焦 —— 不是应用缺陷

**结论**：课表搜索与查书目搜索的输入框在 API 37 模拟器上**确实获得了焦点并接受输入**；没有弹出的只是软键盘，原因是模拟器带硬件键盘且 `show_ime_with_hard_keyboard=0`。登录页（壳外）在同一模拟器、同一输入法配置下表现完全相同，因此不是壳层缺陷。此前“曾假设 `workspace_tab_transition.dart` 每帧 `setFirstFocus` 抢焦点并加回归测试，但该测试在修复前后均通过，假设不成立”的判断成立。

证据（emulator-5554，Android API 37 arm64，正常 main 入口 Debug 包）：

| 观测 | 结果 |
| --- | --- |
| 点击课表搜索框后 `dumpsys input_method` | `mInputShown=true`，`mServedInputConnection` 为 Flutter 的 `InputConnectionAdaptor` |
| `adb shell input text hello` | 搜索框出现 `hello` 与光标 |
| 截屏 | Gboard 悬浮工具条（麦克风/退格/放大镜/表情/菜单）浮在屏幕左侧，软键盘未弹出 |
| 登录页输入框 | 同样只有悬浮工具条，没有软键盘 |
| `settings get secure show_ime_with_hard_keyboard` | `0`（改为 `1` 并重启输入法后行为不变） |

放大招的根因：Gboard 在硬件键盘可用时只渲染悬浮工具条，该窗口浮在应用之上、覆盖屏幕左侧约 130px。课表搜索框左缘正好落在该区域内，按工具条覆盖位置点击会落到输入法而不是应用，看起来像“点击不聚焦”。这一行为由系统输入法决定，应用侧无法拦截。

**仍需真机确认**：物理设备的软键盘、TalkBack 焦点顺序与大字号下的输入框可见性未验收。

## F5：无障碍语义节点合并错乱 —— 已修复

**根因**：应用页面大量使用“普通 `Text` + `Column`/`ListView`”结构，没有任何显式语义边界。Flutter 的语义引擎会把没有自身语义属性的子树整体折叠成一个叶子节点：标签是所有后代文本的拼接，边界覆盖整棵子树。

证据：

- Flutter widget 语义树复现：`Column` 里两个 `Text` 合并为一个节点；`AppleSection` 下的标题、行、脚注合并为一个覆盖整张卡片的节点。
- 校园卡页面合并节点高度 194.5 逻辑像素（583.5 设备像素），与走查记录的 `[0,179][1080,763]`（高度 584 设备像素）一致。
- 设备无障碍树（修复前）：作业行是一个覆盖全屏宽度的节点 `('0','1512','1080','1844')`，标签为“作业一 / 已提交 · 截止 … / 已提交 / 软件工程 / 教师 · 张三”。走查据此误点到底部标签栏。
- 设备无障碍树（修复后）：作业行为 `('42','1512','1038','1843')`；校园卡“查询余额”按钮为 `('400','497','680','647')`，不再是覆盖整张卡片的节点。

**修复**（`flutter/lib/widgets/apple_surfaces.dart`）：

- `AppleSection` 整体成为语义边界并使用显式子节点（`Semantics(container: true, explicitChildNodes: true)`），标题另加 `header: true`。卡片不再把行、按钮、脚注揉成一个节点。
- `AppleListTile` 每行一个节点（`Semantics(container: true)`），标题与副标题读作一行，行自身的点击动作保留在该节点；行尾控件另起节点，避免行尾动作覆盖行本身的点击动作。

**验证**：新增 `flutter/test/accessibility_semantics_test.dart`，三项回归分别锁定“查询余额”按钮的节点边界、作业行节点边界与标题语义。修复前该测试先红（按钮与标题根本没有独立节点；作业行节点宽 360 而行宽 328），修复后转绿。设备无障碍树复验同上。

## F1：模块级认证反弹与全局会话失效的分离

**问题**：SPOC 作业详情被学校弹回登录页时，页面报“学校会话已失效，请重新登录”。同一时刻其他模块会话有效，说明故障范围被夸大；应用还会用记住的密码做一次全局静默重登，密码未保存时这条路径必然失败，用户看到的是“整个应用不可用”。

**修改**：

- domain 新增 `ErrorCode::ModuleAuthRequired`：某个模块要求自己的凭证，共享学校会话可能仍然有效。与 `SessionExpired`（共享会话本身失效）分开。
- upstream `auth::cas::module_refusal()` 统一判定：CAS 登录页 → 仍是全局 `SessionExpired`；模块自己的拒绝（401/403、非 CAS 的 HTML、SPOC 信封 401/403）→ `ModuleAuthRequired`。SPOC 作业、作业文件与 SPOC 学习三条链路改用该判定；CAS 回调拿不到 token 仍按全局会话失效处理，因为那说明 CAS 链没有走完。
- 服务层：模块级拒绝不再触发全局静默重登（重登修不好模块自己的凭证链，还会打断仍然可用的会话）。SPOC 信封的 401/403 不再让整个 homework 列表与详情判定为全局失效。
- bridge 新增 `FailureCode::ModuleAuthRequired` 并重新生成 FRB 绑定；`every_domain_error_code_keeps_its_own_failure_code` 覆盖新码。
- Dart 文案：“该服务要求重新验证身份，其他功能不受影响；请稍后重试”。不含“重新登录”“会话已失效”，不把读者引向仍然有效的会话。

**验证**：upstream 新增 `a_module_auth_refusal_never_relogins_the_shared_session`，断言模块级拒绝的码为 `ModuleAuthRequired` 且登录请求数不增加；改回旧分类时该测试先红。Dart `failure_message_test.dart` 新增“模块级要求不出现全局话术”一组，并保持“含‘重新登录’的话术只属于 `sessionExpired` 与 `captchaRequired`”。

**未解决**：学校跳转链本身（UC→HTTP SSO）仍需带真实凭据的协议级取证；本批只分离分类与话术，没有改变重定向行为，也没有关闭 `docs/MIRROR-TODO.md` 中“最近认证失败”一条。

## 门禁与证据

- `bash scripts/check-mirror.sh` 通过：Rust 全量、严格 Clippy、格式、架构门禁、design token 预算、接口索引同步、FRB 二次生成零漂移、Flutter 全量测试。
- 正常 `lib/main.dart` 入口的 Android ARM64 Debug APK 构建成功。
- 设备无障碍树复验（校园卡与作业页）如上。
- 未接触真实账号、真实学校写入与真实 WebVPN。

## 未覆盖边界

- 物理设备、TalkBack 全流程、预测返回、大字号与深浅色未验收。
- 真实账号下的模块级认证反弹未复验，本批结论基于 2026-10-29 走查记录与合成回归。
- Gboard 悬浮工具条遮挡输入框左侧是输入法行为，未在应用侧处理。
