# 接口索引（生成）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

按层与功能域拆分的全量接口清单。每个文件列出该层所有公开类型、函数与方法，含签名、源码位置与文档首行。

| 文件 | 内容 | 条目数 |
| --- | --- | --- |
| [领域业务端口（ginkgo_domain::ports）](rust-domain-ports.md) | `rust-domain-ports.md` | 91 |
| [领域值类型与纯规则（ginkgo_domain::features）](rust-domain-features.md) | `rust-domain-features.md` | 123 |
| [领域基础类型（ginkgo_domain）](rust-domain-foundation.md) | `rust-domain-foundation.md` | 18 |
| [应用编排（ginkgo_core）](rust-core-application.md) | `rust-core-application.md` | 89 |
| [上游适配器（ginkgo_upstream::adapters）](rust-upstream-adapters.md) | `rust-upstream-adapters.md` | 125 |
| [上游解析（ginkgo_upstream::codecs）](rust-upstream-codecs.md) | `rust-upstream-codecs.md` | 75 |
| [认证与会话（ginkgo_upstream::auth）](rust-upstream-auth.md) | `rust-upstream-auth.md` | 62 |
| [上游服务（ginkgo_upstream::services）](rust-upstream-services.md) | `rust-upstream-services.md` | 110 |
| [上游基础能力（ginkgo_upstream）](rust-upstream-foundation.md) | `rust-upstream-foundation.md` | 47 |
| [组装（ginkgo_runtime）](rust-runtime.md) | `rust-runtime.md` | 8 |
| [桥接（ginkgo_flutter_bridge）](rust-bridge.md) | `rust-bridge.md` | 375 |
| [Dart 应用接口（flutter/lib/application）](dart-application.md) | `dart-application.md` | 161 |
| [Dart 基础设施（flutter/lib/infrastructure）](dart-infrastructure.md) | `dart-infrastructure.md` | 47 |
| [跨域共享状态（flutter/lib/shared）](dart-shared.md) | `dart-shared.md` | 29 |
| [平台集成（flutter/lib/platform）](dart-platform.md) | `dart-platform.md` | 12 |
| [共享呈现组件（flutter/lib/widgets）](dart-widgets.md) | `dart-widgets.md` | 44 |
| [设计系统（flutter/lib/design）](dart-design.md) | `dart-design.md` | 8 |
| [应用外壳组件（flutter/lib/app）](dart-app.md) | `dart-app.md` | 4 |
| [工作区壳层（flutter/lib/workspace）](dart-workspace.md) | `dart-workspace.md` | 27 |
| [Flutter 功能域：academic](dart-feature-academic.md) | `dart-feature-academic.md` | 1 |
| [Flutter 功能域：auth](dart-feature-auth.md) | `dart-feature-auth.md` | 1 |
| [Flutter 功能域：bykc](dart-feature-bykc.md) | `dart-feature-bykc.md` | 10 |
| [Flutter 功能域：campus](dart-feature-campus.md) | `dart-feature-campus.md` | 1 |
| [Flutter 功能域：campus_card](dart-feature-campus_card.md) | `dart-feature-campus_card.md` | 1 |
| [Flutter 功能域：career](dart-feature-career.md) | `dart-feature-career.md` | 1 |
| [Flutter 功能域：cgyy](dart-feature-cgyy.md) | `dart-feature-cgyy.md` | 51 |
| [Flutter 功能域：checkin](dart-feature-checkin.md) | `dart-feature-checkin.md` | 4 |
| [Flutter 功能域：classroom](dart-feature-classroom.md) | `dart-feature-classroom.md` | 20 |
| [Flutter 功能域：grades](dart-feature-grades.md) | `dart-feature-grades.md` | 1 |
| [Flutter 功能域：graduate](dart-feature-graduate.md) | `dart-feature-graduate.md` | 23 |
| [Flutter 功能域：homework](dart-feature-homework.md) | `dart-feature-homework.md` | 25 |
| [Flutter 功能域：learning](dart-feature-learning.md) | `dart-feature-learning.md` | 13 |
| [Flutter 功能域：library](dart-feature-library.md) | `dart-feature-library.md` | 25 |
| [Flutter 功能域：notices](dart-feature-notices.md) | `dart-feature-notices.md` | 1 |
| [Flutter 功能域：reservations](dart-feature-reservations.md) | `dart-feature-reservations.md` | 2 |
| [Flutter 功能域：schedule](dart-feature-schedule.md) | `dart-feature-schedule.md` | 26 |
| [Flutter 功能域：settings](dart-feature-settings.md) | `dart-feature-settings.md` | 16 |
| [Flutter 功能域：shuttle](dart-feature-shuttle.md) | `dart-feature-shuttle.md` | 8 |
| [Flutter 功能域：tasks](dart-feature-tasks.md) | `dart-feature-tasks.md` | 6 |
| [Flutter 功能域：today](dart-feature-today.md) | `dart-feature-today.md` | 21 |

## 快速导航

- 新增接口先选模式：[接口设计模式](../INTERFACE-INDEX.md#11-接口设计模式)
- 从代码位置回查接口：[反向索引](REVERSE-INDEX.md)
- 分层说明、能力总表、模块 IO 与跨层不变量：[INTERFACE-INDEX.md](../INTERFACE-INDEX.md)
- 学校协议事实：[API.md](../API.md)
