# BUAA Assistant - 接口文档（直连验证版）

> **修订说明（2026-10-13）**：本版重写了旧版接口文档。旧版混杂了三类不可靠内容：
> (1) 把 UBAA 中转服务器的 `/api/v1/*` 路由当成了北航上游直连接口——本项目仅直连，这些接口全部不可用；
> (2) 若干端点（byxt `courseTable.do`、byxt `grade.do`、`opac/api.php`、`uc/api/uc/userinfo`）在任何已知实现中都不存在；
> (3) 部分字段名与真实响应不符。
> 本版所有 ✅ 标记的内容均从 UBAA（BUAASubnet/BBAA）仓库的**在用代码**逐条核对重写，行号引用以该仓库为准。
> **仓库名说明（2026-10-14）**：GitHub 实际仓库为 `BUAASubnet/UBAA`，本仓库文档沿用的「BBAA」是它的简称，二者为同一仓库；行号以 2026-10-13 核对的 main 分支为准，上游演进可能造成偏移（否定性断言尤其脆弱，见 §0.0 第 18 条）。

### 0.0 修订对照记录（旧版 → 本版）

| # | 条目 | 旧版内容 | 本版内容 | 证据 |
|---|------|----------|----------|------|
| 1 | GSMIS 课表请求体 | `ZC=10&XNXQDM=2025-2026-1&XH=<学号>&XQDM=1` | `ZC=&XNXQDM=<学期码>&XH=&XQDM=`（仅学期码有值） | `GraduateScheduleUpstream.kt:50-55` |
| 2 | GSMIS 学期码格式 | `2025-2026-1` | `\d{4}[123]`（如 `20251`），代码强校验 | `GsmisSchedule.kt:16` |
| 3 | GSMIS 用户探测 | `getUserInfo.do` | 删除（全仓库无此请求，身份判定由 byxt §2.1 完成） | 全仓 grep |
| 4 | 本科课表端点 | `GET courseTable.do?xnxqdm=` | `POST student/getMyScheduleDetail.do`，表单 `termCode/type=week/week` | `LocalScheduleApi.kt:106-121` |
| 5 | 本科学期列表字段 | `XNXQDM/XNXQMC/DQZC` | `itemCode/itemName/selected/itemIndex` | `Schedule.kt:13-19` |
| 6 | 成绩端点 | byxt `grade.do`（JSON） | buaascore GET+POST 同址，POST 表单 `xq/year`，响应 JSON `e/m/d` | `LocalGradeApi.kt:33-79`、`Grade.kt:57-73` |
| 7 | 成绩数据源 A | byxt 大写拼音 DTO | 该 DTO（`cxwdcj`/WID/KCM）为死代码，唯一在用源是 buaascore | `GradeService.kt:119` |
| 8 | 图书馆借阅 | `opac/api.php?url=loan`（当作可用） | 降级为 ⚠️ 待验证探索项 | 全仓无 borrow/loan 实现 |
| 9 | 第 6-15 节九大系统 | UBAA `/api/v1/*` 中转路由 | 全部移除并说明（§7），直连需另行逆向 | `BBAA/docs/tech/server-routes.md` |
| 10 | SSO 验证码 | 未记载 | 补全（§1.3：检测正则、图片端点、`captcha`+`captchaResponse` 双字段同值） | `LocalConnectionAuth.kt:832-834,629-636,935-948` |
| 11 | SSO 密码过期页 | 未记载 | 补全（§1.5：`_eventId=ignoreAndContinue`，仅跳过一次） | `LocalConnectionAuth.kt:894-907` |
| 12 | 图书馆鉴权头 | `Authorization: Bearer <JWT>`（想当然的标准格式） | `Authorization: bearer<token>`（小写、无空格） | `LocalLibBookApi.kt:275` |
| 13 | 研究生课表数据格式 | HTML 表格 | JSON（`jgList/rwList/jcfaList`，成功码 `"1"`） | `GsmisSchedule.kt:24-37` |
| 14 | **保留** | GSMIS 基址 `gsapp/sys/wdkbapp`、buaascore URL、图书馆 CAS 入口与 v4 端点、`ZZWBKJ_ZHIHUAWEI` 加密方案、CAS 表单流 | 原样保留，仅补齐细节 | 各对应文件 |
| 15 | SSO 登录表单字段 | `rememberMe=false`（硬编码） | 实测无此字段；改为「页面隐藏字段全量回传」通用策略 | 2026-10-13 登录页实测（§1.2 注记） |
| 16 | 图书馆加密密钥示例 | `"20261013" + "31016020"` | `"20261013" + "31016202"`（`20261013` 的逐字符反转，此前示例为笔误） | 反转逐字符核算；与 DEEP-ARCHITECTURE-REVIEW.md §3.4 一致（2026-10-14 勘误） |
| 17 | §1.2 注记 Swift 编码建议 | 「`URLComponents.queryItems` 默认行为即正确」 | queryItems **不**把 `+` 编成 `%2B`（`+` 是 RFC 3986 query 合法字符，原样保留；表单解码端当空格）——须组好 query 后对 `percentEncodedQuery` 再做 `+`→`%2B` 替换，或对值预编码 | Swift 行为实测 + RFC 3986（2026-10-14 勘误，原说法是错的） |
| 18 | §1.8 注记 userinfo 端点 | 「UBAA 代码中不存在调用（只有 status 与 login）」 | 上游 2026-10-14 HEAD 已新增调用（`LocalConnectionAuth.kt:765` `LocalUserServiceBackend.getUserInfo()`，直连链路在用）——否定性断言须注明核对日期 | GitHub main 分支复核（2026-10-14） |
| 19 | §3.1 注记 getUserInfo.do | 「UBAA 代码中无此请求」 | 限定为「**客户端直连链路**无此请求」；服务端 `ByxtService.kt:34` 预热逻辑会请求它 | 同上 |
| 20 | §3.3 学期起点反推引用 | 「GSU:42-68」 | `GsmisSchedule.kt:42-68`（GSU 的 42-68 行是请求构造，系文件误标） | GitHub 仓库复核（2026-10-14） |
| 21 | §5.3 Swift 实现注意 | 「kCCModeCBC 需手动处理填充」 | `CCCrypt` 直接开 `kCCOptionPKCS7Padding`（与上游手动 PKCS7+NoPadding 产出等价密文），无需手写填充 | CCCrypt 官方文档（2026-10-14） |
| 22 | §7.1 本项目作业 provider 状态 | Judge 已接入、SPOC 待实现 | 两个直连 provider 已接入；CUA 实测 SPOC 返回作业列表。当前希冀请求受 ATS `-1022` 阻断，SPOC 完整性和 Judge 仍待分别验收 | 本项目运行态与脱敏日志（2026-10-15） |
| 23 | §7.2 iclass 签到状态预研 | 仅 BBAA 代码参考 | 通过授权账号在 WebVPN 浏览器会话内观察只读 app 登录与当天课程查询：HTTP 200、业务状态 0，共 2 条记录，字段及 signStatus 取值已脱敏记录；原生直连跳转仍待验证 | 2026-10-15 浏览器只读观察；未保存原始响应 |
| 24 | §7.2 本项目签到状态实现 | 尚无客户端 | 新增只读状态客户端、按学号隔离的内存 session、业务拒绝时刷新并重试幂等 GET、阶段化脱敏日志、失败保留旧数据、今天页状态卡片、约 30 秒检查、状态变化提示与用户授权的系统通知；真实系统通知投递未验收 | `Features/CheckIn/*`、`TodayView.swift`、`MainView.swift`（2026-10-15） |
| 25 | §7.2 iclass 网络路线 | 只读状态查询仅直连 | 默认直连；遇到 TLS 握手失败时，按 UBAA 固定向量编码回退至北航 WebVPN。固定编码和模拟请求链有回归测试；2026-10-15 CUA 初次运行收到网关 HTTP 200 但未提取 loginName，2026-10-16 显式重建后 CAS 验证通过并读取到当天空课程状态；没有执行签到写入 | `WebVPNRouter.swift`、`CheckInClientTests.swift` 与脱敏运行日志（2026-10-16） |
| 26 | §7.2 iclass 手动签到 | 本项目未实现写操作 | 按 BBAA `LocalSigninApi.kt` 移植服务器时间、表单提交及 `stuSignStatus=1` 判定；新增独立侧栏入口、逐课程人工二次确认、提交后立即 GET 回查；代码级 mock 覆盖通过。**未对真实账号发送签到写请求**，上游参数/成功语义仍待人工真实往返验收；不自动重发 | `CheckInClient.swift`、`CheckInSummaryView.swift`、`MainView.swift`、`CheckInClientTests.swift`（2026-10-15） |
| 27 | §7.1 SPOC 作业时间 | Swift 未读取发布时间，截止解析不支持毫秒时区 | 对齐 BBAA `zykssj`（发布/开放）与 `zyjzsj`（截止）字段；时间解析增加带毫秒时区 ISO-8601 与本地日期格式。CUA 运行态中截止时间已恢复显示；新增解析与字段解码回归测试 | `SpocHomeworkClient.swift`、`HomeworkModels.swift`、`SpocHomeworkClientTests.swift`（2026-10-15） |
| 28 | §7.1 SPOC 作业详情与提交能力边界 | 本项目仅有摘要列表；提交路径未知 | 按 BBAA 原实现补齐只读详情：正文、教师、作业分值、发布/截止时间、提交状态/时间；接口契约仅暴露列表和详情。CUA 实测详情读取成功并显示教师、分值与日期；抽样作业正文为空，上游详情页明确提示查看原站点。未在原版 LocalSpocApi/SpocApiBackend 中发现作业上传/提交方法，故不臆造写接口，需以本人正常网页操作的脱敏 HAR 继续取证 | `BBAA/shared/.../api/feature/SpocApi.kt:11-15`、`LocalSpocApi.kt:34-38,202-220`、`LocalSpocSupport.kt:188-209`；本项目 `HomeworkViewModel.swift`、`HomeworkView.swift` 及只读 CUA 运行态（2026-10-16） |
| 29 | §2.6 考试安排实现状态 | 接口已记录，客户端未实现 | 新增本科考试安排查询、字段解析与课表内入口；研究生入口隐藏；mock 覆盖数字/字符串字段、排序、空列表和业务错误。尚待真实本科账号验收 | `ScheduleClient.swift`、`ScheduleParser.swift`、`ExamScheduleSection.swift` 与 `ScheduleParserTests.swift`（2026-10-16） |
| 30 | §7.1 希冀作业详情数据 | 客户端只提取截止时间和粗略提交提示 | 对齐 BBAA 详情页解析，读取开始/截止时间、满分、得分、题目级状态/分数及整体进度；多课程 mock 验证切课后详情归属与 query 参数；未触发写操作 | `JudgeHomeworkClient.swift`、`LocalJudgeApi.kt:268-280,743-822` 与 `JudgeHomeworkClientTests.swift`（2026-10-16） |
| 31 | §7.1 SPOC 提交/附件静态线索 | 仅知 BBAA 读接口，推定上游写协议未知 | 当前 SPOC SPA 静态 bundle 含 `POST /kczy/submitKcz2`（`application/x-www-form-urlencoded`）、`GET /kczy/queryFjList` 的 API 包装定义，以及编辑器通用上传路由。进一步静态检查未找到两个作业包装函数的页面调用：`submitKcz2` 与 `queryFjList` 只见定义、未见模块内调用，也不在该模块导出映射中。具体作业页面调用关系、字段、文件绑定与成功回查仍未确认；不发请求、不实现写入 | `https://spoc.buaa.edu.cn/spocnew/js/app.cf9bd4cf.js`（2026-10-16 公开静态资源，只读检查） |
| 32 | §7.1 SPOC 学期上下文 | 桌面端只保留作业项，查询后丢弃学期名称/代码 | 保留当前学期 `dqxq`（名称）与 `mrxq`（查询代码）到统一作业快照和本地缓存，并在页面显示。该上下文来自列表所用的当前学期查询，不单独用于推断学期是否完整 | BBAA `LocalSpocApi.kt:40-42,75-78`、`Spoc.kt:13-19`；本项目 `SpocHomeworkClient.swift` 与 `HomeworkModels.swift`（2026-10-16） |
| 33 | §7.1 SPOC 作业课程上下文 | 列表只解析课程 ID 用于课程名关联，随后丢弃 | 将列表记录 `sskcid` 保存为统一作业项可选 `courseID`，并纳入缓存；旧缓存缺该字段可继续解码。仅保留上游已返回的标识，不推断其为提交接口必需参数 | BBAA `LocalSpocApi.kt:50-62`、`Spoc.kt:21-34`；本项目 `SpocHomeworkClient.swift`、`HomeworkModels.swift` 及兼容性测试（2026-10-16） |
| 34 | §7.2 WebVPN 临时会话恢复 | 网关页返回后只能手动重启 App/重新登录 | 明确 WebVPN 会话仍只保存在进程内；iclass 回退识别到网关登录页时将会话状态标为不可用。仅在 Keychain 已有用户选择保存的凭据时显示显式重建按钮；无已存凭据不发认证请求，提示用户重新登录。无协议变更、不持久化 Cookie | `AppState.swift`、`CheckInViewModel.swift`、`CheckInSummaryView.swift`、`MainView.swift` 与回归测试（2026-10-16） |
| 35 | §7.1 SPOC 未知提交状态 | 列表将未识别 `tjzt` 映射为“待确认”后丢弃原值 | 保持 `UNKNOWN` 状态语义，同时将非空原始 `tjzt` 作为可选 `statusDetail` 缓存；卡片及详情展示限长来源状态，旧缓存无此字段仍可解码 | BBAA `LocalSpocSupport.kt:80-99`；本项目 `SpocHomeworkClient.swift`、`HomeworkModels.swift` 与测试（2026-10-16） |
| 36 | §7.2 iclass 当天课程空结果 | 所有非 `0` `STATUS` 都清除 iclass session 并重试，导致 `STATUS=2` 被显示为会话拒绝 | 仅在当天课程查询端点把字符串或整数 `STATUS=2` 映射为空课程快照，不刷新 session；其他业务状态仍按拒绝处理。UBAA 本身未区分状态码 `2`，此映射依据公开 iclass 用户脚本的解析注释，并与 2026-10-16 本机只读请求观察到的 `STATUS=2` 相符；不是官方协议确认 | `LocalSigninApi.kt:93-103`；[公开用户脚本解析](https://greasyfork.org/zh-CN/scripts/553469-%E4%B8%8D%E6%99%BA%E6%85%A7%E6%95%99%E5%AE%A4/code)；本机脱敏日志与 `CheckInClientTests.swift`（2026-10-16） |
| 37 | §7.2 签到重复响应与并发读取 | ViewModel 可被多个入口同时刷新，解析器也保留重复课程 ID | 在 ViewModel 层跳过并发刷新；课程列表按上游 `id` 去重。同 ID 记录的课程信息或状态冲突时标为待确认，不允许误触发签到。此为客户端健壮性处理，不代表上游保证 ID 唯一 | 本项目 `CheckInViewModel.swift`、`CheckInClient.swift` 与合成响应回归测试（2026-10-16） |
| 38 | §5.5 官网图书馆实时空间数据 | 只有预约端可用/总座位，没有在馆人数 | 官网公开只读页面返回学院路、沙河校区在馆人数；另有沙河特色阅览室人数与座位/研讨间/寄存柜余量。客户端按字段语义分别解析并以独立无 Cookie 会话读取；本机按校区/日期/小时保存聚合样本 | 官网公开页 `/engine2/buaa/more/1082575?websiteId=113745&pageId=208561&wfwfid=16662`（2026-10-16 无认证 GET）；`LibraryPublicStats.swift`、`LibraryPublicStatsParserTests.swift`、CUA 无障碍树运行态 |
| 39 | §5.2 图书馆预约状态与取消 | 文档只列预约记录字段，未说明终态不可取消 | 保留 `status/status_name`；状态码 `6/8`、文案含“取消/结束/已完成/过期/失效”或记录结束时间已过时隐藏取消动作，历史记录仍只读显示。预约列表按上游页码读取，客户端每页请求 40 条 | BBAA `LibBook.kt:104-119`、`LibBookBookingStatusTest.kt:8-39`；当前项目 `LibraryClient.swift` 与回归测试（2026-10-16） |
| 40 | §3.3 研究生周次推算 | 任一教学班缺少排课行或 SCSKRQ 解析失败即判定“上游结构变化” | 对齐 UBAA `parseGsmisSchedule`：无法参与推算的教学班跳过，仅当所有任务都无法推算、或有效任务给出的开学日期不一致/不是周一时才报结构变化 | 2026-10-16 本机脱敏诊断（37 个排课行、9 个教学班中 3 个不可推算）与修复后真实刷新成功（第 6 周）；BBAA `GsmisSchedule.kt:24-70`；`ScheduleParserTests.swift` |
| 41 | §7.1 希冀 CAS 激活 | `service=http%3A%2F%2Fjudge.buaa.edu.cn%2F` | 改为 `service=https%3A%2F%2Fjudge.buaa.edu.cn%2F`。明文 http 跳转会被 ATS 以 `-1022` 拒绝；https 已验证可完成 CAS 激活并读取后续页面 | 本项目真实运行日志（修复后 `-1022` 消失）与 `JudgeHomeworkClientTests.swift` 回归（2026-10-16） |
| 42 | §7.1 希冀来源启用范围 | 客户端始终同步 Judge 与 SPOC 两来源 | Judge 来源暂时下线（`HomeworkSource.enabled = [.spoc]`）：真实课程列表结构与客户端预期不一致，且当前账号无该来源作业。代码、协议研究与测试保留，待真实页面脱敏样本后重新启用；这是产品取舍，不是上游协议变更 | 本项目 `HomeworkClient.swift`、`HomeworkView.swift`、`HomeworkViewModelTests.swift` 与 [RELEASE-NOTES.md](RELEASE-NOTES.md)（2026-10-16） |

## 0. 文档约定

### 0.1 证据分级

| 标记 | 含义 | 使用规则 |
|------|------|----------|
| ✅ 已验证 | UBAA 仓库有在用实现，且经真实账号端到端验收 | 可直接按此实现 |
| ⚠️ 待验证 | 无任何在用实现参考，属推测 | **必须先抓包验证**，验证前不得写实现代码 |
| —— 中转 | UBAA 中转服务器路由 | 本项目（仅直连）不可用，本文档不展开 |

### 0.2 脱敏声明

本文档所有示例均使用合成数据：学号一律用 `sy2501001`，姓名用「李文」「张三」等通用占位，Cookie/token 值均为 `xxx` 形式占位。任何真实学号、姓名、Cookie、票据**禁止**写入本仓库（含测试快照与提交历史）。

### 0.3 通用请求约定

- 所有业务请求默认由共享 Cookie 的 `URLSession` 会话发出（Cookie 自动携带与保存）。
- 需要「Ajax 风格」的接口（各节单独注明）统一附加：
  ```http
  Accept: application/json, text/javascript, */*; q=0.01
  X-Requested-With: XMLHttpRequest
  Referer: <对应系统入口页，各节注明>
  ```
- 超时建议：连接 10s / 请求 30s（对齐 UBAA `LocalConnectionAuth.kt:314-317`）。
- **重定向策略**：认证链路上的请求必须用不自动跟随重定向的会话手动逐跳处理（见 §1.6）；业务数据请求可自动跟随。

---

## 1. 统一认证（SSO + UC）✅

对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalConnectionAuth.kt`（988 行，下称 LCA）。

### 1.1 流程总览

```
┌────────────┐
│ 1. GET /login │──3xx──→ 已有会话 ──→ 4. 激活 UC ──→ 5. 验证会话 ──→ 完成
│ (禁自动重定向) │
└─────┬──────┘
      └──200──→ 解析登录页：execution / 验证码 / 提示文字
                    │
              2. (如需) 拉取验证码图片
                    │
              3. POST /login 提交表单（隐藏字段全量回传）
                    │
              3.5 (如遇) 密码过期跳过页 → POST ignoreAndContinue
                    │
              3.6 手动跟随重定向 + 错误检测
                    │
              4. 激活 UC ──→ 5. 验证会话 ──→ 完成
```

要点：**不需要手动管理 TGT/ST**。CAS 票据流转完全由 Cookie（`CASTGC` 等）+ 重定向链自动完成，客户端唯一要做的是持有 Cookie 并手动跟随重定向。仅图书馆（§5）需要手动从 URL 中提取票据。

### 1.2 获取登录页

```http
GET https://sso.buaa.edu.cn/login
```

- 使用**不跟随重定向**的请求（Swift: `URLSession` 配置 delegate 拦截重定向，或逐跳手动请求）。
- 响应 3xx → 已存在有效会话（Cookie 中已有 CASTGC），直接跳到 §1.7 激活 UC。
- 响应 200 → HTML 登录页，解析以下三样：

| 目标 | 提取方式 | 对照 |
|------|----------|------|
| `execution` 令牌 | 正则 `<input[^>]*name=["']execution["'][^>]*value=["']([^"']+)["']` | LCA:824-828 |
| 验证码配置 | 正则 `config\.captcha\s*=\s*\{\s*type:\s*['"]([^'"]+)['"],\s*id:\s*['"]([^'"]+)['"]` | LCA:832-834 |
| 预登录提示 | `div.tip-text` 内容（如「账号已锁定」），有则直接报错终止 | LCA:836-841 |

> **2026-10-13 实测记录**（无认证 GET，7195B）：`execution` 字段存在，值为 **JWT 三段结构**，含 `+` 与 `/` 字符——**表单提交时必须正确 percent-encode**。**注意（2026-10-14 更正）**：Swift 的 `URLComponents.queryItems` **不会**把 `+` 编码为 `%2B`——`+` 是 RFC 3986 的 query 合法字符，会被原样保留，而 x-www-form-urlencoded 解码端把字面 `+` 当空格。正确做法：组好 query 后对 `percentEncodedQuery` 再 `replacingOccurrences(of: "+", with: "%2B")`，或对值预编码；纯手工拼接同样必错（原注记称 queryItems「默认行为即正确」，是错的，见 §0.0 第 17 条）。默认页**无** `config.captcha`（验证码仅风控触发，与 §1.3 一致）；表单 input 实测共 6 个：`username/password/submit/type/execution/_eventId`，**没有 `rememberMe`**（旧版文档硬编码 `rememberMe=false` 无依据，见 §0.0 表第 15 条）。CasPageParser 三条正则与实测页面匹配。

### 1.3 验证码（旧版文档缺失，本节补全）

北航 SSO 在风控触发时要求验证码。**这是登录模块的硬需求，不是可选项。**

1. **检测**：登录页 HTML 中出现 `config.captcha = { type: '...', id: '...' }` 即需要验证码（§1.2 正则）。
2. **获取图片**：
   ```http
   GET https://sso.buaa.edu.cn/captcha?captchaId=<id>
   ```
   返回 JPEG 二进制，客户端转 Base64 内嵌展示（LCA:629-636）。
3. **提交**：登录表单中 `captcha` 与 `captchaResponse` **两个字段都填同一个用户输入值**（LCA:935-948）。只填一个会失败。
4. 若已检测到需要验证码但用户未输入，直接返回「需要验证码验证」错误并附上图片，不发起登录请求（LCA:484-493）。

### 1.4 提交登录

```http
POST https://sso.buaa.edu.cn/login
Content-Type: application/x-www-form-urlencoded
```

表单字段（LCA `buildCasLoginParameters`，909-933 行）：

| 字段 | 值 | 说明 |
|------|-----|------|
| `<页面全部隐藏字段>` | 原值回传 | **通用收集策略**：解析登录页所有 `<input>`，`type=hidden` 的全部按 name=value 回传；勾选的 checkbox 也回传。不要硬编码字段清单，上游加字段时自动兼容 |
| `username` | 学号 | |
| `password` | 密码 | |
| `submit` | `登录` | |
| `_eventId` | `submit` | 页面已有则用页面值 |
| `type` | `username_password` | 页面已有则用页面值 |
| `captcha` / `captchaResponse` | 用户输入 | 仅验证码场景（§1.3） |

### 1.5 密码过期跳过页（容易遗漏的分支）

提交后可能落在「密码过期 / 账号存在安全风险」提示页，页面特征：含 `continueForm`、`ignoreAndContinue` 字样或「密码过期」文案（LCA:894-899）。处理：重新提取该页 `execution`，POST：

```http
POST https://sso.buaa.edu.cn/login
execution=<新execution>&_eventId=ignoreAndContinue
```

（LCA:903-907）。此跳过只做一次，再次遇到同样页面视为登录失败。

### 1.6 手动跟随重定向与错误检测

提交登录后，用不跟随重定向的会话**逐跳** GET `Location`（相对路径按当前 URL 拼接，LCA:688-704）。每跳结束检查最终响应：

| 特征 | 判定 | 对照 |
|------|------|------|
| 最终 URL 含 `exception.message=` | 其后内容即上游错误消息 | LCA:670-673 |
| HTTP 401，或页面重新出现 `execution` 输入框 | 账号或密码错误 | LCA:674-681 |
| `div#errorDiv`、`.errors`、`tip-text` 有内容 | 其文本即错误消息 | LCA:843-869 |

### 1.7 激活 UC 会话

登录链走完后，必须访问一次 UC 激活地址，否则 `uc/status` 不认会话：

```http
GET https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin
```

（LCA:753-756）

### 1.8 会话验证（登录成功的唯一判据）

```http
GET https://uc.buaa.edu.cn/api/uc/status
Accept: application/json, text/javascript, */*; q=0.01
X-Requested-With: XMLHttpRequest
```

响应：

```json
{
  "code": 0,
  "data": { "username": "sy2501001", "name": "李文", "schoolid": "sy2501001" }
}
```

判定规则（LCA:333-366）：

- `code == 0`（**Int 比较**）且 `data != null` → 有效，`data.schoolid`/`data.name` 即用户信息；
- 非 200、body 以 `<` 开头（HTML）、`code != 0`、`data == null` → 会话无效；
- **5xx 是暂时性错误，不得清除本地会话**（上游抖动会误杀登录态）。判定无效后先别急着清 Cookie：UBAA 的做法是「业务系统报未登录 → 复核 `uc/status` → 复核确认无效才清」（LCA:369-384），建议照抄这个两步确认。

> ⚠️ `uc.buaa.edu.cn/api/uc/userinfo` 端点：**2026-10-13 核对时** UBAA 代码中无调用（只有 `status` 与 `login`）；**2026-10-14 复核发现上游已新增**（`LocalConnectionAuth.kt:765` 的 `LocalUserServiceBackend.getUserInfo()`，直连链路在用）——否定性断言对上游演进脆弱，本条已被证伪（§0.0 第 18 条）。旧版文档所载响应结构仍未取证，如需用户详情（院系/邮箱），先抓包确认再实现。

### 1.9 登出

```http
GET https://sso.buaa.edu.cn/logout
```

无论成败，清空本地会话与 Cookie（LCA:613-622）。

### 1.10 业务系统「未登录」通用判定模式

所有业务系统共用这套判定（课表/成绩/图书馆各自的实现里都有一份）：

```
未登录 ⇐ HTTP 401
      ‖ 最终落在 sso.buaa.edu.cn（URL 判断）
      ‖ 响应是 HTML 且含 input[name=execution] 或「统一身份认证」字样
```

触发后走 §1.8 的复核流程再决定是否清会话、要求重新登录。

---

## 2. 课表 — 本科生（BYXT）✅

基址 `https://byxt.buaa.edu.cn`，认证 = 共享 Cookie 会话（登录后首次访问会经 CAS 302 自动建立 JSESSIONID，无需手动处理票据）。
对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalScheduleApi.kt`（下称 LSA）。

### 2.1 门户探测与身份判定

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/currentUser.do
```

响应分类（LSA:337-394），**这一步同时完成登录探测和本科生/研究生判定**：

| 响应特征 | 判定 | 后续 |
|----------|------|------|
| 401 / 落在 SSO / HTML 含 execution | 未登录 | 走 §1.10 |
| 200，body JSON，最终 URL 含 `/jwapp/sys/byrhmhsy/` | 研究生账号落在研究生门户 | 改走 §3 GSMIS |
| 200，body 以 `{` 或 `[` 开头 | 本科生就绪 | 继续 §2.2 |
| 200，body 是 HTML（其他情况） | 上游不可用 | 报业务错误 |

### 2.2 学期列表

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/schoolCalendars.do
```

Ajax 头 + `Referer: https://byxt.buaa.edu.cn/jwapp/sys/homeapp/index.html`（LSA:206-213）。

响应（`code` 是**字符串** `"0"`，LSA:227-228）：

```json
{
  "code": "0",
  "msg": null,
  "datas": [
    { "itemCode": "2025-2026-1", "itemName": "2025-2026学年第1学期", "selected": true, "itemIndex": 1 }
  ]
}
```

> 旧版文档写此接口返回 `XNXQDM/XNXQMC/DQZC`——**不正确**，真实字段为 `itemCode/itemName/selected/itemIndex`（`BBAA/.../dto/Schedule.kt:13-19`）。`DQZC`（当前周次）不存在于此接口，周次信息走 §2.3。

### 2.3 周次列表

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/getTermWeeks.do?termCode=<itemCode>
```

响应 `datas: [Week]`，`Week` 字段：`startDate, endDate, term, curWeek, serialNumber, name`。当前周 = `curWeek == true` 的项。

### 2.4 周课表（核心）

```http
POST https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/getMyScheduleDetail.do
Content-Type: application/x-www-form-urlencoded

termCode=2025-2026-1&type=week&week=10
```

> 旧版文档的 `courseTable.do?xnxqdm=` **不存在**。真实端点是 `getMyScheduleDetail.do`，POST 表单，参数名 `termCode/type/week`（LSA:106-121）。

响应 `datas` 为 `WeeklySchedule`：

```json
{
  "code": "0",
  "datas": {
    "arrangedList": [{
      "courseCode": "CS101",
      "courseName": "算法设计与分析",
      "courseSerialNo": "01",
      "credit": 4.0,
      "beginTime": "08:00",
      "endTime": "09:35",
      "beginSection": 1,
      "endSection": 2,
      "placeName": "新主楼A101",
      "weeksAndTeachers": "1-16周 张三",
      "teachingTarget": null,
      "color": "#4A90D9",
      "dayOfWeek": 1
    }],
    "code": "sy2501001",
    "name": "2025-2026学年第1学期",
    "sectionTimes": [{ "section": 1, "start": "08:00", "end": "08:45" }]
  }
}
```

字段注意：

- `datas.code` 本科接口返回的是**学号**而非学期码（研究生适配才填学期码，见 `Schedule.kt` 的 `WeeklySchedule` 注释）——不要拿它当学期标识，也是 PII，展示层注意裁剪；
- `dayOfWeek` 是 1-7 整数；节次由 `beginSection/endSection` 给出（闭区间）；`beginTime/endTime` 为 `HH:mm`；
- `credit` 在 DTO 中按 `String?` 接收（上游数字/字符串不定，宽松解析）；
- `weeksAndTeachers` 是展示用文本，**周次规则以选周查询为准**（逐周拉取或自行解析）。

### 2.5 今日课表

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/teachingSchedule/detail.do?rq=2026-10-13&lxdm=student
```

`rq` 为 `yyyy-MM-dd`，`lxdm` 固定 `student`。响应 `datas: [ { bizName, place, time, shortName } ]`（LSA:131-140）。

### 2.6 考试安排

```http
GET https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/exams.do?termCode=<itemCode>
```

注意 Referer 与其他接口不同，多一级 `/home/`：`https://byxt.buaa.edu.cn/jwapp/sys/homeapp/home/index.html`（LSA:215-222）。
响应 `datas: [Exam]`，字段：`courseName, courseNo, examTimeDescription, examDate, startTime, endTime, examPlace, examSeatNo, week, examStatus, examType, taskId`。
**研究生账号访问直接 403**（错误码 `unsupported_portal`，LSA:144-148），客户端要按身份隐藏入口。

---

## 3. 课表 — 研究生（GSMIS）✅

基址 `https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp`（旧版文档注明的「非旧版 /pyxx/kb/」正确）。
对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/feature/GraduateScheduleUpstream.kt`（下称 GSU）+ `model/dto/GsmisSchedule.kt`。

> 旧版与 TESTING 旧版均把研究生课表当成 HTML 表格解析——**错误**，GSMIS 课表是纯 JSON。

### 3.1 进入门户（会话探测）

```http
GET https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/*default/index.do
```

未登录判定（GSU:120-141）：401；或最终 URL 的 host+path 为 `sso.buaa.edu.cn/login`；或 body 含 `<title>CAS Login</title>` / `name="execution"`。

> 旧版文档的 `yjsemaphome/modules/pubWork/getUserInfo.do`「用户信息探测」：UBAA **客户端直连链路**无此请求，GSMIS 链路只有本节及 §3.2/§3.3 三个请求（且有测试断言不得请求它）；服务端 `ByxtService.kt:34` 的预热逻辑会请求它（2026-10-14 核对，此前「全仓库无此请求」的表述不严谨，见 §0.0 第 19 条）。研究生身份判定由 §2.1 的 byxt 探测完成。

### 3.2 开课学期查询

```http
POST https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do
```

无请求体；Ajax 头 + `Referer: .../wdkbapp/*default/index.do`（GSU:33-41）。

响应（`code` 为字符串 `"0"`，数据在 `datas.kfdxnxqcx`，GSU 模型 `GsmisSchedule.kt:7-22`）：

```json
{
  "code": "0",
  "datas": {
    "kfdxnxqcx": {
      "totalSize": 1,
      "rows": [{ "XNXQDM": "20251", "XNXQDM_DISPLAY": "2025-2026学年第1学期" }]
    }
  }
}
```

注意：GSMIS 的学期码格式是 `\d{4}[123]`（如 `20251`），**与 BYXT 的 `2025-2026-1` 不同**，两套体系不要混用。

### 3.3 课表数据（核心）

```http
POST https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/bykb/loadXskbData.do
Content-Type: application/x-www-form-urlencoded

ZC=&XNXQDM=20251&XH=&XQDM=
```

四个参数全部传**空字符串**（除学期码），即返回全学期课表（GSU:44-61）。响应必须是 JSON（body 以 `{` 开头）。

**成功码是字符串 `"1"`**（注意与 §3.2 的 `"0"` 不同，`GsmisSchedule.kt:31`——上游自身不一致，实现时勿抽象成常量）。

响应三个顶层数组：

**`jgList[]` 排课行：**

| 字段 | 含义 | 备注 |
|------|------|------|
| `BJDM` | 教学班代码 | 与 rwList 关联键 |
| `KCDM` / `KCMC` | 课程代码 / 课程名 | |
| `XNXQDM` | 学期码 | 必须等于所查学期（校验点） |
| `XQ` | 星期 1-7 | |
| `KSJCDM` / `JSJCDM` | 起止节次 | 数字 |
| `ZCBH` | 周次位图 | 每字符 `'0'`/`'1'`，下标+1=周次 |
| `JASMC` | 教室名 | |
| `JGJSXM` | 教师姓名 | |
| `JCFADM` | 节次方案代码 | 关联 jcfaList |
| `KSSJ` / `JSSJ` | 起止时间 | 数字 HHmm（如 `800`），由节次方案回填 |

**`rwList[]` 课程任务：** `BJDM`、`XNXQDM/XNXQMC`、`XF`（学分）、`SCSKRQ`（首次上课日期，用于反推学期起点，见下）。

**`jcfaList[].skjcList[]` 节次方案：** `JCFADM`、`DM`（节次号）、`KSSJ/JSSJ`。

**学期起点反推**（`GsmisSchedule.kt:42-68`）：用 `SCSKRQ` 减去最早排课的周偏移，推算开学日期；结果必须唯一且为周一，否则视为上游数据异常。这个算法建议原样移植——它是处理上游不给开学日期的必要补丁。

---

## 4. 成绩（buaascore）✅

基址 `https://app.buaa.edu.cn/buaascore/wap/default/index`（GET 与 POST 是**同一个 URL**）。
对照实现：`BBAA/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalGradeApi.kt`（下称 LGA）。

> 旧版文档给出的 byxt `grade.do` JSON 接口**不存在**。UBAA 的 `Grade.kt` 中确有一套 `WID/XNXQDM/KCM/XSZCJ` 大写拼音字段的 DTO，但它是**死代码**（全仓库无引用，`cxwdcj` 结构仅存在于 DTO 文件内）；服务端与本地两条链路（`server/.../grade/GradeService.kt:119`、LGA:117）都只用 buaascore。

### 4.1 会话激活（GET）

```http
GET https://app.buaa.edu.cn/buaascore/wap/default/index
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
```

此请求只为激活上游会话 + 登录探测（判定规则同 §1.10），返回的 HTML **不解析**（LGA:33-34, 109-114）。

### 4.2 成绩查询（POST）

```http
POST https://app.buaa.edu.cn/buaascore/wap/default/index
Content-Type: application/x-www-form-urlencoded
Accept: application/json, text/javascript, */*; q=0.01
X-Requested-With: XMLHttpRequest
Referer: https://app.buaa.edu.cn/buaascore/wap/default/index

xq=1&year=2025-2026
```

`termCode` 拆分规则（`Grade.kt:77-85`）：`^(\d{4}-\d{4})-(\d+)$`，如 `2025-2026-1` → `year=2025-2026`、`xq=1`。

> **研究生注意（2026-10-13 查漏发现）**：GSMIS 学期码是 `20251` 形式（§3.2），本接口只接受 `2025-2026-1` 形式，调用前必须归一化：取前 4 位为学年起（`20251` → year `2025-2026`、xq `1`；`20252` → xq `2`）。UBAA 原工程**没有**做这个转换（`GraduateSchedule.terms()` 原样透传 `20251`，`parseBuaaScoreTermCode` 收到即抛错，server 中转 `GradeService.kt:54` 同样如此）——研究生直连查成绩在原工程是不可用的，这是本项目要明确补上的缺口。

> 返回是 **JSON，不是 HTML**（旧版文档写「响应：HTML 页面」，错误）。

### 4.3 响应结构

外层是单字母封装：

```json
{
  "e": 0,
  "m": "",
  "d": {
    "xxx-1": {
      "kcmc": "算法设计与分析",
      "kch": "CS101",
      "xf": 4.0,
      "kccj": 92,
      "fslx": "百分制",
      "kclx": "必修"
    }
  }
}
```

- `e` 是 **Int**，`0` 为成功（与 BYXT 的字符串 `"0"` 又不一样——再次提醒勿统一抽象）；
- `d` 是 `Map<String, BuaaScoreCourse>`（key 为课程标识，无业务含义，遍历即可）；
- **`xf`（学分）与 `kccj`（成绩）类型不稳定**：同一字段有时是数字有时是字符串。Swift 侧建议先以 `JSON` 原始值接收，再 `asText` 转 `Double?`（`Grade.kt:87-98` 的做法）；
- `gradePoint`（绩点）上游**不提供**，客户端自行按成绩制映射（TESTING.md §2.2 的映射表需先与学校公布的等级制核对）。

---

## 5. 图书馆座位（booking.lib v4）✅

基址 `https://booking.lib.buaa.edu.cn`。
对照实现：`BBAA/shared/.../local/LocalLibBookApi.kt`（下称 LLB）、`LocalLibBookCrypto.kt`、`LocalLibBookHttpClient.kt`。

### 5.1 CAS 登录链（与 §1 不同，需要手动提取票据）

1. 用**不跟随重定向**的会话 GET：
   ```http
   GET https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbooking.lib.buaa.edu.cn%2Fv4%2Flogin%2Fcas
   ```
2. 手动逐跳跟随 302（**最多 8 跳**），每跳从「当前请求 URL」和「Location 头」提取 `cas` 参数；正则 `[?&#]cas=([^&#]+)`，**查询串和 fragment（`#cas=...`）都要兼容**（LLB:334-399）。
3. 拿到 cas 令牌后换业务 token：
   ```http
   POST https://booking.lib.buaa.edu.cn/v4/login/user
   Content-Type: application/json

   { "cas": "<cas令牌>" }
   ```
   响应 `data.member.token` 即业务 token；缺失则登录失败（LLB:323-330）。
4. **后续所有业务请求的鉴权头**（LLB:275，逐字符对齐）：
   ```http
   Authorization: bearer<token>
   ```
   小写 `bearer`，**与 token 之间没有空格**。这不是标准 Bearer 方案，用通用 HTTP 库默认行为会拼出 `Bearer <token>` 而鉴权失败。
5. 登录失效判定：响应 `message`/`msg` 含「登录失效」「请重新登录」「未登录」→ 清 token 重新走 CAS，**重试一次**，仍失败才报错（LLB:280-292）。

### 5.2 业务端点（全部 POST JSON）

公共头：`Accept: application/json, text/plain, */*`、`X-Requested-With: XMLHttpRequest`、`Origin/Referer: https://booking.lib.buaa.edu.cn`，外加浏览器 UA（Chrome 桌面版，LLB:415-416）。

| 端点 | 用途 | 请求体关键字段 | 响应关键路径 |
|------|------|----------------|--------------|
| `space/pcTopFor` | 楼馆列表 | `day` | `data.list[]`：`id,name,free_num,total_num,children[]` |
| `space/pick` | 分区列表 | `premisesIds`（**字符串**，单个楼馆 ID）、`categoryIds:[]`、`storeyIds:[]`（可选单元素）、`boutiqueIds:[]`、`date` | `data.area[]`：`id,name,premises_id|premisesId,storey_id|storeyId,free_num,total_num` |
| `Space/map` | 分区详情/时段 | `id` | `data.area.{id,name}`；`data.date.list[].{day|date, times[].{id,start,end}}` |
| `Space/seat` | 座位列表 | `id,day,label_id:[],start_time,end_time,begdate:"",enddate:""` | `data.list[]`：`id,name,no,status,status_name`；`status=="1"` 可用 |
| `space/confirm` | **预约（加密，§5.3）** | `aesjson: <密文>` | `data.bookInfo{...}` |
| `member/seat` | 我的预约 | `type:"1",page,limit` | `data.data[]|data.list[]` + 分页字段 |
| `space/cancel` | 取消预约 | `id` | 看 code/message |

- 响应外层 `{ code: Int, message|msg, data }`，**`code` 为 0 或 1 都算成功**（LLB:293-301）。
- 字段名大量存在 `snake_case`/`camelCase` 双写变体（表中用 `|` 列出），解析层两种都要接受。

### 5.3 预约请求加密（AES-CBC）

仅 `space/confirm` 需要（LLB:242）：

```
明文 JSON：{ "seat_id": ..., "segment": ..., "day": "2026-10-13", "start_time": "", "end_time": "" }
密钥：取 day 中的 8 位数字 + 其反转拼接（"20261013" + "31016202"）= 16 字节
IV：固定 "ZZWBKJ_ZHIHUAWEI"
填充：手动 PKCS7 到 16 字节倍数（算法本身 NoPadding）
算法：AES-CBC-NoPadding → Base64 → 作为 aesjson 字段提交
```

（`LocalLibBookCrypto.kt:12-46`）

**Swift 实现注意**：CryptoKit **不支持 AES-CBC**（只有 GCM/ChaChaPoly）。需用 CommonCrypto 的 `CCCrypt`：AES-CBC 为默认模式（不传 `kCCOptionECBMode` 即 CBC），填充直接开 `kCCOptionPKCS7Padding`——与上游「手动 PKCS7 + NoPadding」产出等价密文，无需手写填充（2026-10-14 放宽，见 §0.0 第 21 条）。ARCHITECTURE.md §2 的「仅 CryptoKit」口径已按此修订。

### 5.4 TLS 证书链问题（macOS 风险点）

`booking.lib.buaa.edu.cn` 呈现的证书链不被 JVM/Android 信任，UBAA 在这两个平台对该域名做了**仅限图书馆客户端**的放宽信任（`LocalLibBookHttpClient.kt` 注释 + jvm/android actual）。**iOS/macOS（Darwin 引擎）没有做任何放宽**——可能系统信任该链，也可能同样失败。macOS 首次联调时把这一项列为必测项；若失败，处理方案与安全代价需单独评估（不建议静默全站放宽）。

### 5.5 官网实时空间数据（公开只读）

北航图书馆公开网站的“空间实时数据”组件链接到一个无需图书馆登录的 HTML 页面：

```http
GET https://lib.buaa.edu.cn/engine2/buaa/more/1082575?websiteId=113745&pageId=208561&wfwfid=16662
```

官网主页面通过空间数据组件（应用 ID `1082607`）展示该入口。详情页按 `t_xylxq`、`t_shxq` 分隔学院路与沙河数据，列表中 `图书馆 N 人` 是当前在馆人数；沙河还列出特色阅览室 B1/B2 人数。`预约座位`、`研讨间`、`寄存柜` 的“空闲/总计”字段表示资源余量，不是实时人数或占用率。页面没有公开逐层、逐楼的完整人数分布。

客户端通过不共享校园 Cookie 的 ephemeral `URLSession` 发起 GET，只保存解析后的数字，不保存网页正文。图书馆页面打开时读取并每 30 分钟更新；本机以“校区 + 日期 + 小时”为键保留最近 60 天、最多 4,000 条人数样本，同一小时的重复刷新会替换旧值。趋势按小时汇总；时段估算取最近 60 天内同星期、同小时的样本均值，至少有 3 个历史日才显示。它是本机历史均值，不是官网预测，也不能推断官网没有提供的楼层人数。

---

## 6. 图书馆借阅查询 ⚠️（待验证，探索性目标）

**现状**：UBAA 没有借阅查询功能（全仓库无 borrow/loan/续借 相关实现），旧版文档的 `lib.buaa.edu.cn/opac/api.php?url=loan` 已于 **2026-10-13 实测证伪**（`/opac/`、`/opac/api.php`、`/opac/user/loans` 均返回 404；lib 官网首页为 JS 渲染的 SPA 壳，静态 HTML 无目录系统入口）。本功能无任何参考实现，列为探索项，验证完成前不进入正式里程碑。

验证清单（按 COLLABORATION.md 的逆向流程执行）：

- [ ] 浏览器登录图书馆 OPAC（lib.buaa.edu.cn），确认借阅页真实 URL 与是否独立于 booking.lib 的会话；
- [ ] 抓取 HAR，定位借阅列表 XHR（若为前端渲染）或服务端渲染 HTML 结构；
- [ ] 确认续借操作的端点、方法与 CSRF 要求（写操作，验证时只用本人账号只读部分）；
- [ ] 产出 `_audit` 取证文档（格式参照 `BBAA/docs/_audit/2026-09-17-ihome-api.md` 的证据分级写法）后再更新本节。

---

## 6A. 空教室（源码已核对，真机待验收）

依据：2026-10-15 核对 UBAA main 的 `LocalClassroomApi.kt`、`model/dto/Classroom.kt` 与 `ClassroomViewModel.kt`。此分级仅表示源码证据，未宣称本应用真实账号验收完成。

1. GET SSO service：`https://app.buaa.edu.cn/a_buaa/api/cas/index?redirect=https%3A%2F%2Fapp.buaa.edu.cn%2Fsite%2FclassRoomQuery%2Findex&from=wap&login_from=`，SSO 查询包含 `noAutoRedirect=1`。使用共享 Cookie 激活业务会话。
2. GET `https://app.buaa.edu.cn/buaafreeclass/wap/default/search1?xqid=1&floorid=&date=yyyy-MM-dd`。注意路径为 **buaafreeclass**；旧 BACKLOG 少了一个 a。校区 `1=学院路 / 2=沙河 / 3=杭州`。Ajax 头与 Referer `https://app.buaa.edu.cn/site/classRoomQuery/index`。
3. 响应 `{e:0,m:"",d:{list:{楼栋:[{id,floorid,name,kxsds}]}}}`，`kxsds` 为逗号分隔空闲节次。非零 e、HTML 登录页、结构缺失均报错，不当作无空教室。

## 7. 本期不接入的系统（中转接口说明）

旧版文档第 6-15 节（博雅 BYKC、SPOC、操场 CGYY、阳光打卡 YGDK、iHome、空闲教室、课程评价、iclass 签到、考试安排中转版）记载的 `/api/v1/*` 路径全部是 **UBAA Ktor 中转服务器的自有路由**（见 `BBAA/docs/tech/server-routes.md`），不是北航上游直连协议。本项目架构为仅直连（ARCHITECTURE.md §9.1.3），这些接口**无法使用**；上述系统若未来要接入，每个都需按 §6 的逆向流程重新取证（其中博雅/操场还涉及上游自定义加密，见 DEEP-ARCHITECTURE-REVIEW.md §3）。此处不再罗列。

### 7.1 BBAA 原版作业实现对照（2026-10-15）

BBAA 原版并非只有一个作业来源，而是同时实现了两套直连上游：

- **希冀 Judge**：`shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalJudgeApi.kt`。先访问 `sso.buaa.edu.cn/login?service=http%3A%2F%2Fjudge.buaa.edu.cn%2F` 激活 Cookie，再访问 `judge.buaa.edu.cn/courselist.jsp?courseID=0`、课程选择页和 `assignment/index.jsp`，解析 HTML 课程、作业和详情。原版列表缓存 TTL 为 5 分钟，详情缓存 TTL 为 2 分钟。

  **2026-10-16 更新**：本项目将 CAS 激活链接改为 `service=https%3A%2F%2Fjudge.buaa.edu.cn%2F`——照抄 `http` 会在 macOS ATS 下以 `-1022` 失败（明文跳转被拒），https 已验证能完成激活与后续读取。真实课程列表结构与客户端预期仍不一致，且当前验收账号没有希冀作业，因此希冀来源在本项目暂时下线（`HomeworkSource.enabled = [.spoc]`），作业页只展示 SPOC；代码、协议研究与测试保留，待真实页面脱敏样本补齐后重新启用。

Judge 作业详情页同时包含开始/截止时间、满分、题目表格、题目提交状态及得分。桌面端现按原版本地客户端解析题目行并显示整体进度和分数；读取详情前重新选择所属课程，避免依赖共享会话中偶然残留的当前课程。Judge 解析仅用于只读信息展示，不暴露作业提交操作。
- **SPOC**：`LocalSpocApi.kt` + `LocalSpocSupport.kt`。通过 `spoc.buaa.edu.cn/spocnewht/cas` 获取 token，再调用 `sys/casLogin` 获取 `RoleCode`；当前学期和课程来自 `inco/ht/queryOne`、`jxkj/queryKclb`，作业分页来自 `inco/ht/queryListByPage`。分页参数使用 AES-CBC（key `inco12345678ocni`，IV `ocni12345678inco`，零填充）后 Base64 编码。

作业页时间字段：分页记录的 `zykssj` 是开始/发布时间、`zyjzsj` 是截止时间。UBAA 对 ISO-8601 毫秒与时区输入做归一化；Swift 客户端现按同类格式解析并在列表中分行展示发布与截止时间。某条记录若上游字段为空或无法解析，仍明确显示“未确认”，不伪造时间。

提交状态字段 `tjzt` 按已知字符串/代码映射为已提交或未提交；原实现对未知非空值保留 `UNKNOWN`，并由 `submissionStatusText` 附上原始文本。Swift 端同步保留可选 `statusDetail`，仅在状态未知时用于卡片/详情的“上游状态”说明，展示最多 48 个字符；该值缺失时仍显示“待确认”，不改变状态判断或筛选。

原版只读详情通过 `GET /spocnewht/kczy/queryKczyInfoByid?id=<assignmentId>` 获取作业正文、时间与分值，通过 `GET /spocnewht/kczy/queryXsSubmitKczyInfo?kczyid=<assignmentId>` 获取提交状态与提交时间；课程查询还提供教师 `skjs`，作业分页项提供课程标识 `sskcid`（BBAA 映射为 DTO `courseId`）。桌面端将该标识作为可选 `courseID` 保存到作业模型与缓存，老缓存缺失时仍可读取；这里只保留已观察字段，不推断任何提交请求参数。BBAA `SpocApiBackend` 接口只定义 `getAssignments()` 与 `getAssignmentDetail()`，`LocalSpocApi` 也只有这两条读路径。当前检查未发现 SPOC 作业上传/提交方法或可引用的上传端点；这只是对当前 BBAA 源码的限定性结论，不代表上游不存在该功能。桌面端详情查询据此按只读实现，上传仍等待正常浏览器操作的脱敏 HAR、字段/附件协议和人工确认。

2026-10-16 只读检查 SPOC 官网当前静态 SPA bundle `js/app.cf9bd4cf.js`，发现前端 API 模块声明 `POST /kczy/submitKcz2`，请求体通过导入依赖的 `stringify` 函数序列化并标注 `application/x-www-form-urlencoded`；同一模块还声明 `GET /kczy/queryFjList`（查询参数）及多个作业列表/详情方法。进一步检查该模块的定义、导出映射与函数引用：`submitKcz2`（局部函数 `E`）和 `queryFjList`（局部函数 `J`）均只见定义、未见模块内调用，也未导出。这是“静态 bundle 含未见调用的路由包装”证据，不能证明当前页面实际使用它们；仍未确认字段、权限角色、附件 ID 绑定、响应成功条件或提交后查询是否权威。bundle 中另出现 TinyMCE 编辑器使用的 `/fileManagerSystem/uploadFullfile`（multipart 字段 `file`）与 `/customFileManagerSystem/editorUploadFile`；前者在编辑器上传 handler 中被调用，二者当前只能标为通用编辑器上传链路，不能据此认定为学生作业附件上传。公开的同名 `.js.map` source map 返回 404，无法借助映射文件还原组件调用关系。BBAA `SpocAssignmentsResponse` 另含学期名称/代码，桌面端本轮开始保留这两个查询上下文字段用于界面提示；该学期信息不能替代来源完整性判断。桌面端继续保持只读，待正常网页操作的脱敏 HAR 或可关联的页面调用证据后再实现。

2026-10-16 CUA 运行态对一个列表作业打开详情，界面成功显示授课教师、提交状态、发布时间、截止时间和作业分值；该条目的正文未由上游返回，界面提示原站点检查。因系统窗口截图捕获当前不可用，本次 UI 证据来自应用无障碍树；这是已打开页面的状态证据，不代表正文字段对所有 SPOC 作业均为空。

`/api/v1/judge/*` 和 `/api/v1/spoc/*` 仍是 BBAA 服务端中转路由，本项目不调用它们。当前 Swift 工程保留 Judge 与 SPOC 两个直连 provider 和统一作业模型；SPOC AES-CBC 有 UBAA 黄金向量回归测试，CUA 实测列表返回 13 项且时间修复后可见截止时间。希冀来源暂时下线（见上），SPOC 全课程完整性与发布字段逐条正确性仍需真实账号继续核对；重新启用 Judge 前必须由本人逐项对照详情页提交状态。

### 7.2 iclass 签到状态与手动提交（写协议尚待真实验收）

候选流程最初来自 BBAA `LocalSigninApi.kt` 与模拟测试。2026-10-15 经用户授权的临时账号，通过北航 WebVPN 浏览器会话对真实服务进行了只读请求观察；没有执行签到提交，未保存原始响应或账号字段。

- 认证入口：`https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter`。正常 SSO 会话跳转后，最终 URL 查询中含 `loginName`；本项目从重定向 Location/最终 URL 提取，不记录该值。
- app session：GET `https://iclass.buaa.edu.cn:8347/app/user/login.action`，查询参数 `password`（空值）、`phone`（上一步 loginName）、`userLevel=1`、`verificationType=2`、`verificationUrl`（空值）。本次观察到 HTTP 200、`STATUS=0`，响应 `result` 含 `id` 和 `sessionId`；两值仅用于内存请求，不持久化。
- 当天列表：GET `https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action`，查询参数 `id`、`dateStr=yyyyMMdd`，请求头 `sessionId`。本次观察到 HTTP 200、`STATUS=0`、`total=2`、返回 2 条记录；字段名包括 `id`、`courseName`、`classBeginTime`、`classEndTime`、`signStatus` 等。脱敏观察到 `signStatus` 值 `0` 和 `1`；BBAA DTO 将其解释为未签到/已签到。
- 此次真实请求经官方 WebVPN 网关转发。当前开发环境直连 iclass 时 TLS 握手失败；本项目因此仅为只读 iclass 查询增加窄范围回退：直连遇到 `secureConnectionFailed` 后改由 `d.buaa.edu.cn` 转发，并按 BBAA `LocalWebVpnSupport.kt` 的 URL 编码和重定向规则处理。固定向量和模拟请求链测试通过；2026-10-15 CUA 实测收到 WebVPN 网关 HTTP 200 页面，但尚未提取到 loginName。当前错误会明确提示 WebVPN 尚未返回 iclass 认证信息，不能据此宣称签到状态已成功读取。
- WebVPN CookieStorage 为隔离的进程内临时存储，不写入文件或 UserDefaults。若只读回退收到网关登录页，ViewModel 将暴露 WebVPN 认证不可用状态；UI 在 Keychain 有用户选择保存的凭据时提供显式会话重建按钮，未保存凭据时提示重新登录，不会自动读取/保存新的密码。该恢复按钮仅重建现有 WebVPN CAS 会话，不发送签到写请求；重建成功仍需 iclass 回查成功才算状态已确认。
- UBAA 原版 `LocalSigninApi.kt` 按学号隔离 iclass session，并在课程查询业务状态拒绝时刷新 session 后仅重试一次幂等 GET（第 38-40、71-103、188-218 行）；本项目现已对齐这两项行为。参考实现将部分其他 HTTP/业务异常转换成成功空列表；本项目仍把失败与真实空列表分开，保留最后成功快照并显示最后核对时间。未识别的 `signStatus` 映射为“状态待确认”。
- 2026-10-16 运行截图显示 WebVPN CAS 已验证，但课程列表的 iclass `STATUS` 被拒绝。旧 UI 曾把连续业务拒绝错误显示为“学校会话已失效”；现改为单独的 iclass 未确认错误。HTTP 401/SSO 跳转时先清除旧 iclass session 并重建、重试一次；若主学校会话复核仍有效，再进行一次有界状态回查。已保存凭据的用户还可显式重建临时签到会话。没有改写协议，也没有自动重试签到写请求。
- 2026-10-16 CUA 只读复测中，WebVPN CAS 已验证，课程查询连续返回 `STATUS=2`。BBAA 原实现会把所有非成功状态刷新一次后再返回空列表，无法区分无课和认证错误；公开 iclass 用户脚本明确将当天课程查询的 `STATUS=2` 解析为空结果。桌面端现仅对该查询状态返回空课程快照，并避免无意义的 session 刷新；其他端点和未知业务状态仍保持错误处理。该状态码含义有第三方代码佐证和本机运行态吻合，但尚无官方协议文档确认。
- 页面出现、定时轮询和会话状态变化可能同时请求签到状态；实现现跳过进行中的刷新，并折叠重复课程 ID。若重复 ID 的字段或签到状态不一致，将显示待确认且不提供签到按钮。该处理有合成响应回归测试，不代表已观察到真实响应含重复 ID。
- 本项目对 SSO 跳转、app 登录和课程查询分别记录脱敏 OSLog 阶段、HTTP/业务状态或网络错误域/码；日志不得包含 loginName、sessionId、Cookie、查询串或响应正文。重定向诊断仅记录状态码与 Location 形态，不记录 Location 内容。
- BBAA `LocalSigninApi.kt` 的写请求为先 GET `https://iclass.buaa.edu.cn:8347/app/common/get_timestamp.action`，再 POST `https://iclass.buaa.edu.cn:8347/app/course/stu_scan_sign.action`，查询参数 `courseSchedId`、`timestamp`，表单字段 `id`，请求头 `sessionId`。BBAA 以 `STATUS` 成功且 `result.stuSignStatus == 1` 判定提交成功。本项目现按此实现手动操作；这些写请求尚未由本项目对真实上游实测，故不把源码对照标成协议验收。
- 界面仅在用户逐课程点击并确认后发送写请求；不自动签到、不自动重发。收到成功响应后立即再次读取当天课程，只有回查到 `signStatus == 1` 才显示绿色“签到成功，课程状态已回查确认”；提交超时、回查失败或状态未变化时保留“结果待确认”并提供刷新，不宣称成功。
- 本项目对 SSO、app 登录、课程查询、服务器时间和提交阶段分别记录脱敏 OSLog；日志不得包含 loginName、sessionId、Cookie、查询串或响应正文。应用内状态变化提示与用户授权后的通用 macOS 通知已接入；真实写入往返、通知投递、后台/休眠行为仍待人工验收。

只读字段以真实 WebVPN 转发响应为据；本轮 CUA 已验证当前 App 经 WebVPN CAS 读取当天无课状态。提交协议目前仅以 BBAA 源码为参考，真实签到写入、通知投递和后台/休眠行为仍待验收。

---

## 8. 统一错误处理

```swift
enum APIError: Error {
    // 网络
    case noConnection, timeout, tlsFailure
    // 认证（判定依据见 §1.10，勿只看单一状态码）
    case sessionExpired      // uc/status 复核确认无效
    case invalidCredentials  // 登录页错误特征（§1.6）
    case captchaRequired(CaptchaChallenge)  // §1.3，附图片
    case passwordExpiryPage  // §1.5，可自动跳过一次
    // 业务
    case upstreamError(Int, String?)   // 各系统 code!=成功值
    case graduatePortalUnsupported     // §2.6 研究生访本科考试
    // 解析
    case unexpectedResponse            // 结构与本文档不符 → 触发快照回归排查
}
```

错误处理策略保持旧版框架（sessionExpired → 刷新会话重试一次；captchaRequired → 弹验证码；upstreamError → 展示上游消息），但**会话过期的判定必须走 §1.8 的两步确认**，避免上游 5xx 抖动导致误登出。

## 9. 请求拦截器

旧版的 RetryInterceptor/CookieInterceptor 思路保留，修订两点：

1. **自动重试只对幂等 GET 开启**。POST（尤其预约、选课类写操作）不自动重发——上游切换语义下重发会反向操作（教训见 `BBAA/docs/features/ihome.md` 的写操作约束）。
2. Cookie 注入交给 `HTTPCookieStorage`（或独立 `URLSession` 的默认行为），**不要**手拼 Cookie 头——图书馆 CAS 链依赖 Set-Cookie 的域/path 语义，手拼容易丢 `HttpOnly` 标记的票据。

---

## 附录 A：已验证 URL 总表

| 系统 | URL | 认证 | 数据格式 |
|------|-----|------|----------|
| SSO | `https://sso.buaa.edu.cn/login`（+`/captcha`、`/logout`） | 表单 CAS | HTML |
| UC | `https://uc.buaa.edu.cn/api/login`、`/api/uc/status` | SSO Cookie | JSON |
| 本科教务 | `https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/...`（`currentUser.do`、`student/schoolCalendars.do`、`getTermWeeks.do`、`student/getMyScheduleDetail.do`、`teachingSchedule/detail.do`、`student/exams.do`） | SSO Cookie | JSON |
| 研究生教务 | `https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/...`（`*default/index.do`、`modules/xskcb/kfdxnxqcx.do`、`bykb/loadXskbData.do`） | SSO Cookie | JSON |
| 成绩 | `https://app.buaa.edu.cn/buaascore/wap/default/index`（GET+POST 同址） | SSO Cookie | JSON |
| 图书馆座位 | `https://booking.lib.buaa.edu.cn/v4/...`（`login/cas`、`login/user`、`space/*`、`member/seat`） | CAS→token | JSON |
| 图书馆借阅 | 待验证（§6） | ? | ? |

## 附录 B：Cookie / Token 清单

| 名称 | 归属 | 说明 |
|------|------|------|
| `CASTGC` | sso.buaa.edu.cn | CAS TGT，HttpOnly，登录态根凭据 |
| `JSESSIONID` | byxt / gsmis / app | 各业务系统会话，CAS 首跳自动建立 |
| （图书馆）member token | booking.lib | §5.1 换取，使用方式 `Authorization: bearer<token>`（无空格） |

## 附录 C：各系统成功码速查（勿统一抽象）

| 系统 | 成功判定 | 类型 |
|------|----------|------|
| UC | `code == 0` | Int |
| BYXT | `code == "0"` | String |
| GSMIS 学期 | `code == "0"` | String |
| GSMIS 课表 | `code == "1"` | String |
| buaascore | `e == 0` | Int |
| 图书馆 | `code ∈ {0, 1}` | Int |
