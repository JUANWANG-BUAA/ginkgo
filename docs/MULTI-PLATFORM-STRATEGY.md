# 多平台路线与 Rust + Flutter 镜像准备

> 当前路线记录（2026-10-20，状态更新 2026-10-25）。Apple 产品继续使用现有 SwiftUI 应用并已冻结；Rust + Flutter 镜像项目范围冻结为 Android + Windows，Android 当前公开 Alpha.8（2026-10-25），Windows 当前公开 Alpha.6。Apple 端另有同号草稿包 `0.1.0-alpha.8`（2026-10-20），与 Android 的 Alpha.8 **不是同一产物**；公开状态与验收边界统一见 [镜像实施现状](MIRROR-IMPLEMENTATION.md) 与 [Windows 首发记录](archive/mirror/MIRROR-WINDOWS-ALPHA4.md)。
> 本文取代旧版 Kotlin/Compose 推荐方案。历史候选方案不再作为当前实施建议；Rust/Flutter 的具体边界以 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md) 为准。实施已启动，当前进度见 [MIRROR-IMPLEMENTATION.md](MIRROR-IMPLEMENTATION.md)。

---

## 当前开发范围（2026-10-24 决策）

> **唯一开发目标是 Android（Flutter + Rust）。macOS / iOS 暂时冻结。**

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| **Android** | **开发中（唯一）** | Flutter + Rust。全部功能开发、评审、发布排期都落在这里。 |
| Windows | 维护（不做功能） | 与 Android 共用同一 Flutter 工程（`flutter/windows/`）。**必须保持可编译**——`mirror.yml` 的 windows job 会验证；但不为它开发新功能或扩展桌面能力。 |
| macOS / iOS | **暂时冻结** | Swift/SwiftUI 应用保留在仓库中。**不做功能开发、不做跨端对齐、不为其排期**；只在影响 Android 构建、共享 fixture（`fixtures/`）或存在安全问题时被动修。 |

**为什么保留而不删除冻结端代码**：Swift 树里的 `LocalStore` / `SchoolTime` / `HTMLText` / `AESCipher` / `FormURLEncoding` 等仍是 Rust 侧的重写参照；`fixtures/` 的双端契约 runner 需要 Swift 侧存在；删除会产生一个巨大的纯删除 diff，且让"契约是否双端一致"这一检查失去意义。

**由此产生的确定性变化**：

1. **跨端一致性不再是目标**。Android 端不再需要与 macOS 对齐强调色、状态色、"今天"信息架构或控件形态；Flutter 的设计基线以 `flutter/lib/design/tokens/` 为唯一事实源。
2. **Rust/Dart 缺陷的权重全部上调**。此前"两个栈之一"的每个问题，现在直接命中 100% 的用户。
3. **发布链路出现单点**。macOS 与 Windows 都有自动发布 workflow，Android 没有——收窄后它是唯一发布路径。见 [综合评审 §10.1](_audit/2026-10-24-comprehensive-review.md)。
4. **文档与指令文件必须同步**，否则后续协作会继续为冻结端排期。见 [综合评审 §10.2](_audit/2026-10-24-comprehensive-review.md)。

**综合评审与 Android-only 重排**：[`_audit/2026-10-24-comprehensive-review.md`](_audit/2026-10-24-comprehensive-review.md)（2026-10-24）。其 §7 的 P0–P3 排序与 §10 的范围收窄影响，是当前待办排序的依据。

**以下内容是 2026-10-21 之前的历史路线记录，保留供追溯，不再作为当前实施建议。**

## 当前项目与迁移起点

Ginkgo 当前是 macOS + iOS 原生 SwiftUI 客户端，直连或经学校 WebVPN 访问上游，不运行自建 HTTP 中转服务。API 协议证据以 [API.md](API.md) 为准，平台行为与验收记录分别见 [IOS.md](IOS.md)、[ACCEPTANCE.md](ACCEPTANCE.md)。

截至 2026-10-20 的架构快照：

- Apple 两端共享大量 Swift 网络、解析、模型、缓存和应用逻辑；iOS 仍通过 XcodeGen 的源码包含/排除配置复用主源码树，尚未形成独立 Swift Package。
- 课表、考试、成绩、学校作业、空教室和 BYKC 已由 Repository 封装上游服务与快照存储；工作区负责默认组装。Repository 是 Swift 进程内边界，不是 Rust/Flutter API。
- 空教室过滤/排序已与 ViewModel 及界面标题分离；课表快照的已知周次合并/选择规则也已从 ViewModel 提取。它们由版本化 fixture 驱动测试，为跨语言契约提供小切片，但不能据此推断整个 Swift 核心已与 UI 解耦。
- BYKC 搜索/类别选择与学期选择规则已从网络和界面抽离；当前第一批共享 fixtures 覆盖 `classroom.filter`、`bykc.course_filter`、`school_time.beijing_day` 与 `schedule.snapshot_retained_weeks`。签到、校园通知、研究生教务仍未全部形成 Repository/领域规则边界。
- 既有 XCTest 是行为线索；可复用的跨语言验收依据应逐步沉淀为无个人数据的 JSON fixtures，而不是逐行翻译 Swift 实现。

## 镜像定义与实施启动决策

- **平台范围**：Android 与 Windows；macOS/iOS 继续由 SwiftUI 产品维护。跨端项目不替换 Apple 客户端，也不要求 Apple target 链接 Rust。
- **“镜像”的含义**：优先对齐核心用户任务、数据语义、权限提示与错误恢复，不追求像素级复制 Apple 控件。Flutter 按各平台交互惯例呈现同一领域状态。
- **运行边界**：Rust 在本地承载领域规则、协议、认证会话和缓存；Flutter 是 UI；没有自建远端后端。Dart 不持有学校 Cookie，也不逐请求控制 HTTP 或 WebVPN。
- **启动时机**：Apple 端 `0.1.0-alpha.8` 草稿包曾用于冻结 SwiftUI 基线（该路线已于 2026-10-24 冻结，当前仅被动维护）；镜像侧启动路径为 Rust workspace 与 fixture runner → 纯逻辑垂直切片，不必公开整个发布草稿，也不等待所有历史写操作验收。
- **MVP 优先级**：共享规则验证 → Rust/bridge/Flutter 双平台垂直切片 → mock HTTP 只读用例 → 认证与 WebVPN → 扩大只读模块；写操作排最后并逐项评审。

具体 crate、垂直切片验收标准、只读迁移顺序和完成定义见 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md)。

## 目标边界

```text
Flutter UI（导航、交互、本地化、无障碍、平台呈现）
        │ 粗粒度、可序列化的完整用例请求/结果
        ▼
Rust bridge（生成绑定；不承载业务规则）
        ▼
Rust application/domain
  ├── 用例编排与稳定错误码
  ├── 协议客户端、认证状态机、解析与领域规则
  ├── Repository 与本地快照/缓存策略
  └── ports：凭据保险库、通知、外链等平台能力
```

- 一次桥接调用应完成一个用户级用例，例如登录并确认 UC 会话、加载某学期成绩或刷新空教室结果。Dart 不逐条驱动 HTTP、重定向、Cookie 或缓存文件。
- Rust core 不依赖 Flutter。bridge 只暴露稳定 request/result、必要的进度事件和错误 code；本地化文案由 Flutter 呈现。
- Cookie、CAS 重定向链、WebVPN 路由、写操作回查都留在 Rust 侧完整执行。凭据通过平台适配器访问系统安全存储；Flutter 不接触 Cookie 或明文会话文件。
- 项目不新增自建服务端；Flutter/Rust 是本地应用内边界，不是网络后端。
- Android/Windows 是当前镜像准备范围，Apple 端继续由 SwiftUI 维护。Rust core 的数据契约可以和 Swift 测试共用 fixtures，但不要求 Apple 应用接入 Rust。

## 共享契约

1. [API.md](API.md) 是学校上游协议的唯一事实源；本文件只定义应用内部跨语言边界，不替代 API 证据。
2. `fixtures/` 保存 Swift 与未来 Rust 共用的合成或脱敏用例。每个样例包含 `contract`、整数 `version`、`source`、`input`、`expected`；原始上游响应与领域输入/输出分目录管理。
3. Fixture 不得包含真实学号、姓名、Cookie、票据、成绩或其他个人数据。真实账号验收与合成契约测试分开记录。
4. 枚举、错误和状态使用稳定 wire code，不传本地化 UI 文案。时间点使用带时区的 RFC 3339；学校日期、教学周和学期规则固定基于 `Asia/Shanghai`，不跟随设备时区；不透明 ID 按字符串处理。
5. 领域 fixture 至少覆盖正常、空结果、缺字段/类型漂移和错误；写操作另覆盖成功、拒绝、结果未知。结构变化不得被降级成空结果。

已有契约：[`classroom.filter` v1](../fixtures/classroom/filter-v1.json)、[`bykc.course_filter` v1](../fixtures/bykc/course-filter-v1.json)、[`school_time.beijing_day` v1](../fixtures/time/beijing-day-v1.json) 与 [`schedule.snapshot_retained_weeks` v1](../fixtures/schedule/week-snapshot-v1.json)。Swift 测试分别验证空教室筛选/排序、BYKC 搜索与类别选择、北京时间规则和课表快照的同学期周次保留；Rust 实现应读取相同文件，不复制 JSON 常量。

## 分阶段推进

1. **Rust workspace 与契约测试**：先落地最小 Cargo workspace 和 fixture runner；把 UI 文案与 wire code 分开，复用现有 JSON 文件。
2. **纯逻辑垂直切片**：从 `classroom.filter`、`school_time.beijing_day` 和课表快照开始，用 mock/fixture 数据打通 Rust → bridge → Flutter，并在 Android、Windows 各验收一次。
3. **只读真实用例**：先 mock HTTP 覆盖请求、解析、缓存回退、账号隔离和错误分类；再挑一个接口证据完整的模块做授权的真实只读验收。
4. **认证与会话**：CAS、UC、Cookie、WebVPN 路由在 Rust 内作为完整异步用例实现，之后暴露用户级 bridge；不先做逐请求 FFI。
5. **扩大只读范围**：按依赖和接口稳定性推进课表/考试、空教室、成绩、作业、BYKC；每个功能有独立 fixture、错误矩阵和双平台验收记录。
6. **最后评审写操作与分发**：预约/签到等写操作先满足协议证据、确认、回查和未知结果不重试；Android/Windows 的签名、安装、升级与隐私行为分别验收。

Rust workspace 的初始 crate 划分、FFI 约定及质量门槛见 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md)。创建工程后再按 Cargo、Flutter 与 bridge 工具链配置 CI；在此之前不把占位配置或空目录算作工程落地。

## Apple 侧并行整理

- Repository 继续负责客户端与缓存的组合；ViewModel 负责页面状态、刷新节流和错误呈现。纯业务规则尽可能从 SwiftUI 文件移出并做确定性测试。
- 稳定排序/状态等跨语言值留在 domain/result 层；标题、颜色、排序菜单等平台呈现放入 presentation adapter。
- `GinkgoCore` Swift Package 仍可作为 Apple 工程自身的模块边界改进，但它不是 Android/Windows Rust + Flutter 项目的前置条件，也不应承载跨语言契约。
- 每次抽象以可替换依赖、可独立测试或明确的责任边界为验收点；不为形式统一复制一套空 Repository/Service。

## 已评估但不再是当前路线的方案

| 历史候选 | 当前处理 |
|---|---|
| Swift + Kotlin/Compose 双核心、三端原生 UI | 旧版建议，已被 Rust + Flutter 镜像准备方向取代；不再按 Kotlin 开始实施。 |
| KMP/Compose 覆盖 Apple、Android、桌面 | 不作为当前计划；Apple 应用维持 SwiftUI。 |
| Apple 也迁移到 Flutter，或全平台统一重写 | 不在当前范围；需另行决策并评估现有 Apple 资产、发布与无障碍影响。 |

若平台范围或“镜像”的视觉/功能定义发生变化，应先更新本节及 [RUST-FLUTTER-PORT.md](RUST-FLUTTER-PORT.md)，再据此扩展实现，避免旧路线与新路线同时处于“推荐”状态。
