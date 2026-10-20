# Rust + Flutter 镜像项目开发计划

> 状态（2026-10-20）：`rust/` workspace、FRB 桥接与 Flutter Android/Windows 工程已建立；认证核心（Cookie/CAS/UC/WebVPN/恢复）和今天/空教室/课表/成绩/作业五个离线页面切片已完成，16 类 58 份共享 fixture 由 Rust runner 消费。今天/课表/成绩/作业已过 Android 真实 FFI 设备测试，空教室部分通过。平台凭据 store、真实只读 bridge、研究生课表、BYKC/图书馆/场馆/通知、本地功能、Windows 实机与写操作仍未完成。Apple 继续使用 SwiftUI；进度与验收见 [MIRROR-IMPLEMENTATION.md](MIRROR-IMPLEMENTATION.md)。

## 目标边界

Flutter 只承担导航、页面布局、无障碍语义、本地化和用户交互；Rust 承担学校协议、认证会话、解析、领域规则、缓存与刷新策略。平台专属能力（凭据保险库、系统通知、外链打开）通过 Rust port/adapter 接入，不进入领域模块。

```text
Flutter 页面与状态呈现
        │ 粗粒度命令 / 结果 / 可选事件流
        ▼
Rust Flutter Bridge（生成绑定，不包含业务规则）
        ▼
Rust Application Use Cases
        ├── Domain：模型、规则、错误码
        ├── Repositories：账号快照与缓存策略
        └── Adapters：CAS、上游 HTTP、WebVPN 路由、解析、文件存储
```

一次 FFI 调用应完成一个用户级操作，例如登录及 UC 会话确认、加载某学期成绩或刷新图书馆快照。禁止让 Dart 逐个驱动 HTTP 请求、重定向或 Cookie；认证链与路由状态必须留在 Rust 内，避免把敏感会话拆散到 UI 层。

## 跨语言契约

- [API.md](API.md) 继续作为上游协议唯一事实源；本文件定义应用层边界，不替代协议证据。
- `fixtures/` 是 Swift 与 Rust 共用的黄金样例库。每个 fixture 使用 `contract`、整数 `version`、`source`（`synthetic` / `redacted-upstream`）、`input` 和 `expected` 字段。协议原始响应样例与领域输入输出样例应分目录保存。
- Fixture 不得包含真实学号、姓名、Cookie、票据、成绩或其他个人数据。无法脱敏的真实响应不得入库；live 验收记录保留在既有受控流程中。
- 跨语言枚举使用稳定、非本地化的 wire code（如 `availability`），UI 展示文案独立本地化。错误同样传稳定 `code` 与可选的脱敏上下文，不把中文文案从 Rust 传给 Flutter。
- 时间点统一用带时区的 RFC 3339 表示；学期、教学周和日期规则固定使用 `Asia/Shanghai`，不继承设备时区。学号、门户 ID、上游不透明键均按字符串传递。
- 每个领域规则至少有正常、空结果、缺字段/类型漂移、错误四类合成样例；写操作额外覆盖成功、拒绝、结果未知。Rust 不得把结构变化解释为空结果。

当前跨语言 fixtures 包含 [`classroom.filter` v1](../fixtures/classroom/filter-v1.json)、[`bykc.course_filter` v1](../fixtures/bykc/course-filter-v1.json)、[`school_time.beijing_day` v1](../fixtures/time/beijing-day-v1.json) 和 [`schedule.snapshot_retained_weeks` v1](../fixtures/schedule/week-snapshot-v1.json)。Swift 测试直接读取这些合成文件，验证筛选/排序、BYKC 搜索与分类选择、北京时间语义和学期内已知周次保留；Rust 契约测试应加载相同文件，而不是复制 JSON 常量。

## 启动阶段与首个里程碑

镜像按“先证明契约可复用，再接真实上游”的顺序实施，不以一次性重写全部功能为目标。Swift 继续作为 Apple 产品和行为参照；新工程通过共享 fixture 对齐行为，不把 Swift 实现逐行翻译成 Rust。

### 阶段 1：工程骨架与 fixture runner

- 在 `rust/` 创建 Cargo workspace，首批只建 `ginkgo_core` 与桥接 crate；领域/应用/平台适配边界按下文结构落地，不提前复制所有 Swift 文件。
- 建立 fixture 加载器，让 Rust 测试从仓库根目录读取 `fixtures/`，禁止把 JSON 再复制成测试常量。
- 配置格式、lint、测试与 CI 入口；固定实际采用的 Rust、Flutter 和绑定生成工具版本，并记录升级方式。
- 这一步不接真实账号、不写入真实缓存、不改 Apple target，也不引入自建服务器。

### 阶段 2：第一个跨端垂直切片

以 `classroom.filter` 为首个切片：Rust 实现稳定 wire code、筛选/排序规则和 typed 请求/结果；Flutter 经粗粒度 bridge 调用；Android 与 Windows 页面用相同合成数据呈现结果。随后接入 `school_time.beijing_day` 与 `schedule.snapshot_retained_weeks`，确认时区和课表快照规则没有语言漂移。此里程碑不依赖登录或真实上游网络，重点验证 Rust—bridge—Flutter 的边界、错误传播和两端交互。

**阶段 2 验收条件**：

- Swift 与 Rust 对同一批 fixtures 得到完全一致的稳定结果；差异有明确的 contract 版本升级，而不是隐式改预期值。
- Flutter 不含筛选、时区或快照领域规则，不接触 Cookie、HTTP 重定向和 Swift 缓存文件。
- Android 与 Windows 均可构建并完成筛选、空结果、错误态的 UI 冒烟验收；平台控件可以不同，但用户任务与语义一致。
- Rust 核心测试、格式与 lint 在本地及 CI 可重复运行；桥接生成步骤有文档和可复现命令。

### 阶段 3：只读真实用例 MVP

垂直切片通过后，再选择一个认证依赖最少、上游证据完整的只读功能做端到端接入；先用 mock HTTP 验证请求和解析，再由用户授权做真实账号只读验收。扩展顺序建议为课表/考试、空教室、成绩、作业、BYKC；顺序可依据依赖和接口稳定度调整，并在开始每个功能前补齐对应 fixtures 与失败分类。认证、UC/WebVPN 会话状态留在 Rust application/adapters 内，Flutter 仅展示加载进度、结果和可操作错误。

图书馆预约、签到提交、CGYY 预约等写操作不属于 MVP；只有在只读版本稳定、协议有证据、结果回查和“未知结果不重试”都通过测试后才进入单独评审。

## 里程碑完成定义

一个功能只有同时满足以下条件才算完成跨端迁移，而不是“页面已出现”：

1. `API.md` 有对应协议证据，领域输入/输出和错误码有版本化 fixture。
2. Rust 有领域规则、应用用例、mock 网络测试；Dart 不复制业务规则或持有认证状态。
3. Android 和 Windows 都完成构建及关键用户流程验收，平台差异记录在测试文档。
4. 账号隔离、日志脱敏、缓存迁移/清理和失败恢复行为有测试；不把真实个人数据放进 fixture。
5. 文档记录尚未覆盖的功能与风险；Apple 端仍可独立发布，不被 Rust 工程改动阻塞。

## Rust 工程建议结构

创建 Rust 项目时再落地 Cargo workspace，避免 Swift 主仓库被过早绑定到 Flutter 工具链。建议初始边界如下：

```text
rust/
  Cargo.toml                         # workspace
  crates/ginkgo_core/
    src/foundation/                  # time, encoding, crypto, storage, network
    src/auth/                        # CAS、UC、会话恢复
    src/features/                    # schedule、grades、homework、classroom…
    src/application/                 # 面向 UI 的完整用例
    src/ports/                       # credential、notification、external-link traits
  crates/ginkgo_flutter_bridge/      # 仅绑定 application API
```

`ginkgo_core` 不依赖 Flutter/Dart；bridge 只暴露 typed request/result 和稳定错误码。网络传输、缓存和账号选择由 core 管理，Flutter 不持有学校 Cookie，也不直接读取/写入 Core 缓存文件。

## 工程质量门槛

每个 Rust 阶段至少要求 `cargo fmt --check`、`cargo clippy --all-targets --all-features`、`cargo test`；桥接生成也须纳入可重复的 CI。跨语言规则要求 Swift 与 Rust 对同一 fixture 得到相同结果。mock/fixture 测试、真实上游只读验收和人工 UI 验收分别记录，不能互相替代。涉及写操作时，另须有 API.md 证据、二次确认、提交后回查和未知结果不重发测试。

## 当前 Swift 侧准备状态

- 课表、考试、成绩、学校作业、空教室和 BYKC 已有 Repository 接口，默认组装集中在 `WorkspaceCoordinator`；这些边界仍是 Swift 进程内依赖，不是跨语言 API。`BykcRepository` 封装 `BykcServing` 与按账号隔离的快照缓存，`BykcCourseCatalog` 和 `BykcSemesterPolicy` 则是独立于请求和界面的纯规则。
- BYKC 类别筛选使用 `all` / `named` / `unclassified` 稳定语义，并由 `fixtures/bykc/course-filter-v1.json` 固定；空教室筛选/排序逻辑已脱离 ViewModel，排序 wire code 位于结果层，本地化标题单独放在 presentation adapter。
- 课表快照的“切换到已缓存周次”与“同学期保留已知周次”策略已从 `ScheduleViewModel` 提取为纯值操作；它们由共享 fixture 覆盖，不依赖网络、缓存或界面状态。
- 签到、校园通知、研究生教务 ViewModel 仍有直接客户端/缓存依赖；按“领域规则先稳定、再抽用例边界”的顺序继续迁移，不为形式统一制造空壳 Repository。
- 第一批纯规则抽取集中在空教室筛选/排序、BYKC 搜索/学期策略、北京时间语义与课表快照合并；认证状态机、网络路由、解析器契约和写操作语义尚未形成 Rust 实现。
- Swift 代码继续服务 Apple 产品；不引入 Rust 运行时依赖，不改变现有协议、存储格式或写操作行为。
