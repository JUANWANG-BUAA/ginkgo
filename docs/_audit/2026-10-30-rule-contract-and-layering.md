# 共享规则契约与页面分层清理（2026-10-30）

## 范围

本批处理 `docs/MIRROR-TODO.md` 中两项架构债：稳定业务规则在 Rust 与 Dart 各有一份实现；页面层可以直接组装适配器。只做规则归口与依赖收敛，不改变学校协议，不新增学校能力，不使用真实凭据，不执行学校写操作。

## 一、稳定业务规则的重复实现

### 现状

| 规则 | Rust | Dart |
| --- | --- | --- |
| 作业截止分类 | `ginkgo_domain::features::homework::classify_deadline` / `is_homework_overdue`（**此前无人调用**） | `features/homework/homework_projection.dart` 的 `classifyHomeworkDeadline` / `isHomeworkOverdue` |
| 签到窗口 | `ginkgo_domain::features::checkin::sign_in_window`（被上游写路径使用） | `shared/reminder_rules.dart` 的 `checkinWindowOpen`（被签到页使用） |

两套实现语义相同但语言不同：任何一侧被改动，另一侧不会变红。签到窗口尤其危险——Dart 决定是否给出签到按钮，Rust 决定是否接受这次提交，两边不一致时用户会点到一个必然被拒绝的按钮。

### 处理

沿用仓库既有的共享契约机制（`fixtures/` 信封 + Rust contract runner），新增 `fixtures/rules/` 两张规则表：

- `homework-deadline-v1.json`：15 组输入，覆盖空值与纯空白、日期型截止（当天 23:59:59 与次日 00:00 两个边界）、精确时刻、UTC 时刻、跨零点的午夜截止、无法解析的日期与时刻、垃圾字符串。
- `checkin-window-v1.json`：12 组输入，覆盖开放前一刻、开放瞬间、窗口内、关闭瞬间、关闭之后、次日同一时刻、课程不在查询日、结束早于开始、跨午夜课程、畸形时间、秒级格式、带时区偏移的完整时间戳。

Rust 侧新增 `rules.homework_deadline` 与 `rules.checkin_window` 两个契约分支，直接调用领域规则；`ginkgo_domain::features::homework` 的截止分类因此从死代码变成共享契约的一部分。Dart 侧新增 `flutter/test/rules_parity_test.dart`，读取同一份 `expected` 断言 Dart 实现。

### 验证

- Rust contract runner 递归执行全部 fixture，新表一次通过。
- Dart parity 测试两项通过（15 + 12 组）。
- 敏感性验证：把 Dart 签到窗口从“课前 10 分钟”改成“课前 5 分钟”，parity 测试在“开放瞬间”用例上先红；改回后转绿。

### 未完成

签到与作业提醒规则（`checkinReminders` / `homeworkReminders`）仍只有 Dart 实现，Rust 侧的提醒规划器只覆盖课程与本机待办。彻底只留一份实现还需要让上游 DTO 携带 Rust 计算的判定边界（日期型截止对应次日零点、精确时刻、签到开放与关闭时刻），Dart 只做呈现与比较；这会改动桥接 DTO 与相关 fixture，已在 TODO 记录路径。

## 二、页面自行组装适配器

### 现状

`infrastructure/service_factory.dart` 提供 `mirrorServiceFor(demo:)`，通知、待办、博雅、研究生教务四个页面在没有注入服务时用它兜底，自行组装 `NativeMirrorService` 或 `DemoMirrorService`。

风险与 CGYY 页面早已写明的注释一致：页面自行组装适配器会得到**自己的适配器实例**，因而绑定到与工作区不同的账号。仓库里 CGYY 的做法是页面只接收注入的 loader 或网关，缺失时抛出明确错误。

### 处理

- 删除 `flutter/lib/infrastructure/service_factory.dart`。
- 通知页与待办页：服务改为必填注入，去掉只用于兜底的 `demo` 参数。
- 博雅页与研究生教务页：保留既有 loader 注入口，服务可选；两者都缺失时抛出明确错误，不再兜底组装。
- `flutter/lib/mirror_service.dart` 的说明同步为“页面从工作区获得网关，不自行组合适配器”。
- 架构门禁新增规则：`features/` 与 `workspace/`（组合根 `workspace/workspace_shell.dart` 除外）不得导入 `package:ginkgo_mirror/infrastructure/`。学习课程页、作业文件面板与设置维护页仍以基础设施实现作为默认参数值，五个文件在门禁中显式列出，集合不能悄悄变长；自测覆盖规则生效、组合根豁免与清单固定。

### 验证

- `flutter analyze` 无问题；635 项 Flutter 测试通过。
- 门禁自测由 21 项增至 24 项并通过。
- 设备（Android API 37 模拟器）上的 `notices_test` / `bykc_test` / `tasks_test` / `graduate_test` 集成测试通过。

**设备复验发现的一处真实破坏**：博雅与研究生教务页保留了 loader 注入口，因此服务仍可缺省，而缺省时页面在运行时才报“无可用服务”。`bykc_test` 与 live 验收管线正是这样构造页面的，模拟器上直接失败——编译期检查不出来。已把这四处调用改为显式注入服务，并新增 `flutter/test/page_gateway_injection_test.dart` 锁定“无网关时报错而不是读成别人”。这说明可选服务 + 运行时错误不是好设计：改为必填服务更安全，剩余改动已记入 TODO。

## 未覆盖边界

- 真实账号、物理设备与学校写入未执行；规则表全部为合成样例。
- 提醒规则的 Rust 归口、五个待迁移文件的默认实现上移、共享规则表的 Swift 侧接入均未完成。
- 门禁中的待迁移清单是显式例外，不是豁免。
