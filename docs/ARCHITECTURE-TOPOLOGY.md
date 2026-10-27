# Ginkgo 架构拓扑与数据流

更新：2026-10-27。本文用图说明 **Android（Flutter + Rust）的调用拓扑与数据 IO**，配合 [接口索引](INTERFACE-INDEX.md) 使用：索引给出签名与位置，本文给出结构与走向。

图为 Mermaid，GitHub 原生渲染；依赖图由 `scripts/generate-interface-index.py` 从源码算出，不手绘。

## 1. 一眼看懂的五层

```mermaid
flowchart TB
  subgraph ui["① Flutter UI"]
    pages["features/*/ *_page.dart<br/>页面与域内组件"]
  end
  subgraph app["② 应用接口"]
    gateways["application/*.dart<br/>Gateway 接口 + 契约类型"]
  end
  subgraph adapter["③ 基础设施"]
    native["NativeMirrorService<br/>FRB 调用"]
    demo["DemoMirrorService<br/>合成数据"]
  end
  subgraph bridge["④ FFI 边界"]
    frb["api/live/*.rs<br/>粗粒度命令 + DTO"]
  end
  subgraph core["⑤ 应用编排"]
    ws["ginkgo_core<br/>Workspace 命令、账号隔离、本机存储"]
  end
  subgraph ports["⑥ 业务端口"]
    traits["ginkgo_domain::ports<br/>26 个 trait"]
  end
  subgraph up["⑦ 上游实现"]
    services["ginkgo_upstream::services<br/>会话、缓存、时序"]
    adapters2["adapters + codecs<br/>HTTP 与解析"]
  end
  school[("北航各系统<br/>CAS / BYXT / SPOC / iClass<br/>booking.lib / CGYY / OPAC")]

  pages --> gateways
  gateways -.注入.-> native
  gateways -.注入.-> demo
  native --> frb
  frb --> ws
  ws --> traits
  traits -.实现.-> services
  services --> adapters2
  adapters2 --> school
```

三条硬规则在此图中固化：

1. **页面只碰 ②**：页面拿到的是 `application/` 的接口，不 import 生成绑定。
2. **端口是唯一收口**：`core` 依赖 `traits`，学校实现从外部注入，因此换实现不影响业务规则。
3. **协议只在 ⑦**：URL、Cookie、token、成功码不出 `ginkgo_upstream`。

## 2. 调用拓扑：读操作 vs 写操作

只读与写入走同一条链，差别在**返回值语义**与**是否可能已改学校状态**。

```mermaid
sequenceDiagram
  autonumber
  participant P as 页面
  participant G as Gateway
  participant N as NativeMirrorService
  participant F as FRB 命令
  participant C as core 命令
  participant Pt as 端口 trait
  participant U as upstream 服务
  participant S as 学校系统

  P->>G: schedule(week: 7)
  G->>N: schedule(...)
  N->>F: load_schedule(...)
  F->>C: 读全局会话锁
  C->>Pt: load_schedule(input)
  Pt->>U: 实现
  U->>S: HTTP GET/POST
  S-->>U: 学校响应
  U-->>C: ScheduleOutcome{data, stale, failure}
  C-->>F: 领域投影
  F-->>N: ScheduleResponse DTO
  N-->>G: DTO
  G-->>P: 渲染或降级
```

**失败时的数据流**（读）：

```mermaid
flowchart LR
  req["本次读取"] --> ok{"成功?"}
  ok -- 是 --> fresh["新数据<br/>stale=false, failure=null"]
  ok -- 否 --> cached{"有旧快照?"}
  cached -- 有 --> stale["旧数据<br/>stale=true, failure=原因"]
  cached -- 无 --> err["无数据<br/>failure=原因"]
  fresh --> ui1["页面展示"]
  stale --> ui2["页面展示 + 旧缓存提示"]
  err --> ui3["页面空态 + 重试"]
```

关键：**失败不清空旧数据，也不延长原成功时间**。所以页面的三态（新、旧、无）必须分开呈现。

## 3. 写入的数据流与状态机

写操作多一层本地保护，因为「网络失败」不等于「学校没生效」。

```mermaid
flowchart TB
  start["用户明确触发<br/>（确认弹窗）"] --> guard{"本机标记<br/>是否存在?"}
  guard -- 存在 --> blocked["拒绝新写入<br/>只允许回查"]
  guard -- 不存在 --> mark["先写本机标记"]
  mark --> req["单次提交请求"]
  req --> resp{"响应可解析?"}
  resp -- 明确成功 --> accepted["accepted<br/>回查确认"]
  resp -- 明确拒绝 --> rejected["rejected<br/>清理标记"]
  resp -- 前置不满足 --> notsub["notSubmitted<br/>清理标记"]
  resp -- 超时/未知/结构变化 --> uncertain["uncertain<br/>保留标记"]
  accepted --> clear["清理标记"]
  rejected --> clear
  notsub --> clear
  uncertain --> review["仅允许回查<br/>用户核对后 acknowledge"]
  review --> clear
```

`MutationState` 只有四个终态，由 `ginkgo_domain::features::mutation` 定义：

```mermaid
stateDiagram-v2
  [*] --> 提交中
  提交中 --> accepted: 回查命中目标
  提交中 --> rejected: 学校明确拒绝
  提交中 --> notSubmitted: 前置条件不满足
  提交中 --> uncertain: 结果无法确认
  uncertain --> accepted: 回查命中
  uncertain --> rejected: 回查确认未生效
  accepted --> [*]
  rejected --> [*]
  notSubmitted --> [*]
```

**未在图上画出一条边**：`uncertain → 重新提交`。这条边在生产代码里不存在，也不应该存在。

## 4. 模块依赖图（生成）

完整图与循环检测结果见 [依赖图](interfaces/DEPENDENCY-GRAPH.md)。当前快照：26 个分组节点（其中 25 个有出向依赖）、143 条跨组依赖。

### 4.1 分层依赖方向

```mermaid
flowchart LR
  features["features/*"] --> application["application"]
  features --> widgets["widgets"]
  features --> design["design"]
  features --> shared["shared"]
  features --> platform["platform"]
  workspace["workspace"] --> features
  workspace --> application
  app["app"] --> design
  app --> platform
  infrastructure["infrastructure"] --> application
```

### 4.2 已存在的循环依赖（待收敛）

Dart 侧没有 Rust 那样的依赖方向门禁，因此目录级环不会被自动拦截。当前实测到 **25 个分组同属一个强连通分量**，其中最短的一条真实环是：

```mermaid
flowchart LR
  application -->|local_tasks.dart 用 school_timestamp| shared
  shared -->|reminders.dart 用 course_visibility| features_schedule["features/schedule"]
  features_schedule -->|页面用 contracts.dart| application
```

根因很具体：`flutter/lib/features/schedule/course_visibility.dart` 定义的是**跨域共享状态**（课程可见性），却被放在课表域内，于是 `shared/` 反向依赖了 `features/`。

> 这是本次可视化查出的真实问题，尚未修复。修法是把 `course_visibility.dart` 移到 `shared/`，但会牵动 `shared/`、`features/schedule/`、`features/checkin/`、`features/homework/` 的导入与若干测试，属于独立改动。

## 5. 数据 IO 契约图

### 5.1 统一信封

所有读取结果在 Rust 侧都是同一个形状，页面因此只需判断三件事。

```mermaid
classDiagram
  class DataOutcome~T~ {
    +T data
    +AppError failure
  }
  class AppError {
    +ErrorCode code
    +String detail
  }
  class ErrorCode {
    <<enumeration>>
    InvalidRequest
    ChangedResponse
    UnsupportedContract
    SessionExpired
    ServiceUnavailable
    CaptchaRequired
    InvalidCredentials
    BusinessRejected
    ...
  }
  DataOutcome --> AppError
  AppError --> ErrorCode
```

带缓存语义的读取还会带 `fetched_at`、`from_cache`、`stale`，这正是页面区分「新 / 旧 / 无」的依据。

### 5.2 一个功能的数据形状：课表

```mermaid
flowchart LR
  subgraph school["学校响应（upstream 内部）"]
    raw["BYXT / GSMIS JSON"]
  end
  subgraph domain["领域值（跨 FFI）"]
    sd["ScheduleData<br/>terms / weeks<br/>term_id / week_number<br/>courses / exams"]
    so["ScheduleOutcome<br/>data + fetched_at<br/>from_cache / stale / failure"]
  end
  subgraph dart["Dart 类型（页面消费）"]
    dto["ScheduleResponse<br/>Dart DTO"]
  end
  raw -->|codecs 解析| sd
  sd --> so
  so -->|bridge 映射| dto
```

**没有一步把原始 JSON 直接交给 Dart**。这条链上的每个箭头都是一次类型收窄。

### 5.3 各层的数据形态对照

| 层 | 数据形态 | 谁构造 | 谁消费 |
| --- | --- | --- | --- |
| 上游响应 | `serde_json::Value` | HTTP 传输 | codecs |
| 领域值 | `ginkgo_domain::features::*` 结构体 | codecs | core、upstream |
| 结果信封 | `DataOutcome<T>` / `*Outcome` | services | core |
| FFI DTO | `ginkgo_flutter_bridge::api::*` 结构 | bridge 映射 | Dart |
| Dart 契约 | `application/contracts.dart` 导出类型 | 生成绑定 | 页面 |
| 页面投影 | `*_models.dart` 类型值 | 模型函数 | 组件 |

这就是「载荷解码只允许在 `*_models.dart`」那条门禁的由来：前四层都在 Rust，第五层是类型转发，第六层是唯一允许 Dart 自己解码的地方——而它解码的是**已序列化的领域 JSON**，不是学校原始响应。

## 6. 能力地图

24 项能力如何分布到学校系统，见 [§2 能力总表](INTERFACE-INDEX.md#2-能力总表)。下面是同一份数据的关系视图。

```mermaid
flowchart LR
  subgraph auth["认证"]
    cas["CAS / UC"]
  end
  subgraph academic["学业"]
    byxt["BYXT 本科教务"]
    gsmis["GSMIS 研究生"]
    score["buaascore"]
    spoc["SPOC"]
  end
  subgraph space["空间资源"]
    booking["booking.lib 座位"]
    opac["OPAC 书目"]
    cgyy["CGYY 研讨室"]
    free["空教室"]
  end
  subgraph campus["校园"]
    iclass["iClass 签到"]
    bykc["BYKC 博雅"]
    news["新闻网"]
    bus["校车"]
  end

  session["session / auth-challenge"] --> cas
  schedule["schedule / today / exams"] --> byxt
  schedule --> gsmis
  grades["grades"] --> score
  homework["homework / homework-files"] --> spoc
  learning["learning"] --> spoc
  library["library 座位"] --> booking
  books["library-books / library-loans"] --> opac
  cgyyS["cgyy"] --> cgyy
  classroom["classroom"] --> free
  checkin["checkin"] --> iclass
  bykcS["bykc"] --> bykc
  notices["notices"] --> news
  shuttle["shuttle"] --> bus
```

## 7. 会话与缓存的位置

这两者是全局状态，理解它们的归属才能理解「为什么切账号要丢弃旧结果」。

```mermaid
flowchart TB
  subgraph rust["Rust 进程内"]
    identity["SchoolClient.identity<br/>account + generation"]
    cookies["Cookie 罐<br/>直连 / WebVPN 隔离"]
    tokens["业务 token<br/>SPOC / iClass / booking"]
    snaps["查询快照<br/>TTL 300s / 每缓存 32 键"]
    marker["CGYY pending marker<br/>无自动过期"]
  end
  subgraph platform["平台"]
    vault["系统保险库<br/>Android Keystore / Win CredMan"]
  end
  subgraph disk["本机文件"]
    tasks["tasks-hash.json<br/>按账号摘要命名"]
    prefs["显示 / 提醒 / 常用入口"]
  end

  identity -->|绑定| cookies
  cookies --> tokens
  identity -->|切换账号<br/>generation++| snaps
  vault -.仅勾选记住时.-> identity
  snaps -.清缓存不动.-> tasks
  marker -.清缓存不动.-> marker
```

要点：**清查询缓存不删个人待办，也不解锁 CGYY 保护**。这三类数据生命周期不同，不能一起清。

## 8. 如何保持这些图准确

| 图 | 来源 | 是否手绘 |
| --- | --- | --- |
| 分层拓扑、时序、状态机、数据形状 | 架构约定 | 手绘，随架构决策更新 |
| 目录依赖图与循环检测 | `scripts/generate-interface-index.py` 扫描 import | 生成，改代码后重跑 |
| 能力地图 | 与 [能力总表](INTERFACE-INDEX.md#2-能力总表) 同源 | 手绘，新增能力时同步 |

改完代码后：

```sh
python3 scripts/generate-interface-index.py          # 刷新接口清单与依赖图
python3 scripts/generate-interface-index.py --check  # 校验是否过期
```

本文只描述源码结构，不代表功能已发布或已通过真实账号验收。
