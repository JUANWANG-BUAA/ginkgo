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
| 68 | §6 目录与本人借阅 | 旧域404被泛化为没有参考／不能进入里程碑 | 新站space.lib的公开search/hot1/new/books/holdings匿名code0；holdings是内嵌JSON字符串；本人loans仅成功空态，非空／资格仍待验 | [2026-10-23审计](_audit/2026-10-23-ibuaa-protocol-research.md) §5，原站JS hash与响应类型投影 |
| 73 | §6 公开查书目与馆藏（已接入只读，实机验证） | 只有空间预约；图书目录／馆藏无客户端 | 匿名只读检索与馆藏复本接入：POST `/opac/search`（page1/size20、`all` 词项、`idx.opac`）、GET `/opac/bibs/{bibId}/holdings`；`data.holdings` 的 JSON 字符串在 Rust 内二次解码并有大小／深度／条数上限；`code===0` 才算成功，非零码报业务拒绝而不是空列表；本人借阅／续借／预约仍不接入 | 本文件 §6.1；`codecs/library_books.rs`、`adapters/library_books_http.rs`、`services/library_books_service.rs` 与合成回归；该主机证书链不完整（缺 GlobalSign R3 中间证书），以**按主机作用域**方式补链（其他主机与全局信任库不受影响、可回滚），实机检索与馆藏均已通过；**真实字段完整性、状态码语义仍未验收** |
| 72 | §6B CGYY 协议对齐（合成回归） | mine 固定 page1/size20；草稿 `weekStartDate` 直接用预约当天；草稿响应丢弃；验证码坐标只接受 ≤310 的整数；回查仅比对 id | 官方静态证据落地为**有界分页**（首请求 page0/size5，最多 4 页，短页／重复 id／totalElements 即停）、`weekStartDate` 取 day 响应的 `reservationDateList[0]`（缺失则省略该字段）、保留草稿 `tradeNo`、坐标按 `310*x/width` 归一且保留小数、回查需 id＋预约日期（＋有值 tradeNo）同时匹配；验证后额外 day 若轮换 token 则在任何 POST 前终止 | 官方前端静态证据 [§6B.1](#6b1-2026-10-23-官方前端静态修订未执行写)；`cgyy_http::read_orders`/`week_start`/`protocol_point` 与写流程合成回归；**真实学校写操作仍未验收** |
| 69 | §6B CGYY官方前端 | mine page1、weekStartDate/JSON/captcha字段未有官方链对照 | 官方移动首page0、day首项日期、info响应传递、分支显式null、repCode与330→310坐标均静态定位；未改实现／未写 | 同审计§7，CM/CR/CO/CV源身份与偏移；服务端生命周期仍未知 |
| 70 | §6C 校车 | 仅公开时刻表，余票协议无线索 | 官方站ShiftsSearch构造及保留座位／摆渡分支已定位，用户查询页12班与差异余票；完整单次网络形状／身份资格未验 | 同审计§6；REA页面AX，未购票／退款 |
| 71 | §6D 阳光打卡 | 未区分新增入口读写 | 记录查询静态已见，get包装可转POST；追加体育/艺术字段、先上传后clockin、公开开关与详情回查静态证据；下一阶段明确手动提交，点赞／打卡／上传本轮未调用，不归入全局只读刷新 | 同审计§8；YM1172/YH7abe/YS73d6/YA4c28/YD2860；不是成功接口样本 |
| 67 | 镜像 CGYY 只读会话恢复 | 核对/选项页遇过期业务token后一直复用，不能页内重试恢复 | 强读GET的401在账号/身份代次校验下最多renew一次；仅影响读取，预约草稿、验证码验证、提交和取消POST仍不重放。无新增端点/参数/成功码 | §6B、修订53既有GET恢复规则；`cgyy_booking_service.rs`与合成token过期测试；[Alpha.7记录](_audit/2026-10-23-android-alpha7-release.md) |
| 66 | 镜像 CGYY 写入闭环 | 仅进程内待核实布尔值；核对动作后台拉取即解锁，审批信息不完整 | 沿用 §6B 端点和成功码；写异常（含 HTTP 200 业务码 500）不视作确定未提交。账号级最小落盘标记先于请求、重启保留；强读最近 20 条展示后，凭账号/身份代次绑定、120 秒内一次性核对 ID 解除。保留读解析 v1 分类/五字段契约，live 额外投影订单/审批状态和保守取消资格；受理/查回不称审批成功 | `CgyyModels.swift:131–195` 既有映射；`cgyy_booking_service.rs`、core `application/cgyy.rs`、`cgyy_pending_store.rs` 合成 HTTP/临时文件测试；[本轮记录](_audit/2026-10-22-android-cgyy-write-flow.md)。无新增上游端点或真实写入验收 |
| 65 | 镜像 CGYY 与提醒 | CGYY 仅查询；镜像无定时提醒 | 沿用 §6B 的直连、签名、草稿 / 验证 / 提交 / 取消；镜像采用手动拼图，不自动识别；POST 单次、回查和不确定保护。课前十分钟门禁及截止前 48 / 24 小时提醒是本地产品规则，不是新增上游协议 | `CgyyClient.swift:141–274` / UBAA 既有取证；`cgyy_booking_service.rs` / 合成 HTTP 回归；[Alpha.6 记录](archive/mirror/MIRROR-ALPHA6.md)，真实写入未执行 |
| 64 | SPOC 课程归属 | 直接取首个账号角色，通用课程上下文未区分学生与助教 | 优先名称明确的学生账号角色，按学校 SPA 的学生/助教列表 kcid 分类。学生优先，未知或归属读取失败保留原作业；页面可查看助教项，不按名称删除 | [E1/E2 静态代码取证](_audit/2026-10-21-spoc-course-roles.md)；真实身份列表与 iClass 归属待验收 |
| — | 镜像证据文档归档 | 验收记录位于 docs 根目录 | 将链接更新至 archive/mirror；不修改端点、请求、字段或成功码规则 | [历史索引](archive/mirror/README.md)，2026-10-21 |
| 63 | Apple UC 激活跳转兼容 | 已知 HTTP SSO GET 跳转仍被合并报为缺 Location | Swift 与 Rust 对齐：仅精确 sso.buaa.edu.cn /login 的 HTTP GET 跳转提升 HTTPS，保留原查询编码；未知不安全目标单独报错，密码 POST、TLS、Cookie 策略不变。无账号复查仍见同一跳转，不由此判断账号或 IP 限制 | [诊断追加](_audit/2026-10-21-auth-redirect-incident.md#再次报告与无账号复查)；CasClientTests 合成先红后绿；真实完整登录仍待用户复验 |
| 62 | UC 激活 HTTP SSO 跳转 | 假定认证跳转均为 HTTPS；桌面将不安全 scheme 同样报成缺 Location | 2026-10-21 真实单次登录及无账号 GET 均观察 UC 激活 302 到 http SSO /login；桌面 HTTPS guard 拒绝，镜像跟随 HTTP 后 UC status=10600。仅精确已知 CAS GET 地址提升 HTTPS，保留编码、Secure Cookie 和 TLS；不能据此归因早前 SPOC 500 或账号限制，修复后真实登录待验收 | [诊断记录](_audit/2026-10-21-auth-redirect-incident.md)；CasClient.swift::redirectURL；Rust auth/uc.rs / Cookie::matches |
| — | 镜像SPOC正文 | 对象/数组正文被按缺失展示 | zynr沿用原生String?契约，类型漂移拒绝并保留旧详情；缺失/null仍允许元数据与提交状态显示 | `SpocHomeworkClient.swift:42,216–233`；2份漂移契约、HTTP编码及应用缓存回归 |
| — | 镜像 2026-10-21 实网与详情类型 | 部分只读模块待真实账号；正文类型异常被当成缺正文 | Android 授权账号只读检查覆盖已接入模块及详情/历史/分段；空成绩、空已选/当前预约/订单保留空态。SPOC 正文对象/数组报结构错误并保留缓存；合法空正文不冒充请求失败 | [本轮验收](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md)；`SpocHomeworkClient.swift`、UBAA `LocalSpocAssignmentDetailRaw.zynr` 可空字符串；2 份类型漂移合成 fixture 和先红后绿缓存回归 |
| — | 镜像研究生展示 | 课程与报告元数据共用文字行 | 明确课程标记及可选学分/学期，未知完成值不删除课程，缺学分不伪造0；无新端点 | `GraduateAcademicClient.swift:220–265`；合成领域与契约验证，真实验收仍单列 |
| — | 镜像博雅学习记录 | 仅课程目录 | 已选记录与累计完成统计分别读取/缓存，按北京时间学期范围查询已选；缺范围保留未知，统计零要求不伪造成欠缺 | `BykcClient.swift:38–63,212–251`、`BykcSemesterPolicy.swift`；EDUCATION-DATA-MAP §2.3 既有协议；本次镜像实网⚠️待验收 |
| — | 镜像图书馆历史 | 镜像仅当前预约 | 接入member/seat只读分页，type=1、page、limit=40；token恢复一次、按页快照；分页矛盾/漂移报错 | `LibraryClient.swift:392–453`；UBAA e8a397f `LocalLibBookApi.kt:247–258`；合成契约，⚠️历史实网待登录 |
| — | 镜像签到历史 | iclass只提供当天入口 | 同一get_stu_course_sched只读GET接受所选上海日期dateStr；镜像按日期隔离五分钟缓存、失败保留、快速切换丢弃旧请求 | `CheckInClient.swift:92–94,225–230,667`；UBAA `LocalSigninApi.kt:88`仅佐证参数名，不佐证历史日期真实返回；历史实网⚠️待本机登录 |
| 镜像会话勘误 | WebVPN头/图书馆登录 | 请求URL映射而Origin/Referer未映射；并发CAS；有网关Cookie即跳过认证 | 对齐Apple路由头映射；图书馆异步登录锁与锁内检查；显式网关挑战不能被预登录Cookie跳过；认证失败保留快照 | `Core/Network/UpstreamRoute.swift:93–99`；UBAA e8a397f `LocalLibBookApi.kt:187,305–332,365–371`；Android授权只读复验成功，未放宽TLS |
| 镜像时间勘误 | GSMIS时间方案 | 仅外层JCFADM | skjcList条目的JCFADM优先，外层兼容；再按DM匹配 | UBAA e8a397f `GsmisSchedule.kt:35–39,74`；`ScheduleParser.swift:117–121,306–312`；合成回归与Android时间字段完整性检查 |
| 镜像 CGYY | 教学楼场馆只读 | 镜像未迁移 | 公开场馆/直连SSO/签名/时段/最近20条订单迁移；host公开7个site可读，账号链路⚠️待完成 | §6B、修订53；CgyyClient.swift / CgyySigner.swift；不含写接口 |
| 镜像通知 | 公开通知列表 | 镜像未迁移 | 按现有HTML字段迁移最新5条/摘要外链；Rust host公开5条可读，Android实网/外链⚠️待完成 | §7.3五条既有证据；CampusNoticesClient.swift |
| 镜像研究生 | 学籍/执行报告 | 尚未迁移 | 按code=1与zxbg层级迁移；学籍白名单；报告失败回退课程池 | §7.4；`GraduateAcademicClient.swift`；真实镜像验收⚠️待完成 |
| 镜像 BYKC | 博雅课程目录 | 镜像仅纯过滤规则 | 迁移CAS/加密/配置/课程分页，只读，真实验收⚠️待完成 | `BykcClient.swift`；`EDUCATION-DATA-MAP.md` §2既有实测 |
| 镜像 2026-10-20 | SPOC 真实只读迁移 | 镜像仅合成列表 | 按既有协议接通认证、上下文、列表与详情；真实验收待本机登录 | §7.1 2026-10-18 实测；`SpocHomeworkClient.swift`；合成契约不替代上游证据 |
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
| 43 | §1.6 CAS 登录 4xx 错误消费 | 非 401 的 4xx 直接显示为“认证服务暂时不可用”，丢弃页面错误信息 | 对 4xx 响应先尝试解析 `errorDiv` / `.errors` / `tip-text`；HTTP 483 无错误正文时提示学校认证服务拒绝本次登录；日志只记录状态与脱敏域信息。2026-10-18 模拟器真实账号尝试观察到 CAS POST 302，但 `uc.buaa.edu.cn` 对 `/`、`/api/login`、`/api/uc/status` 均返回 HTTP 483「访问策略禁止」，因此未能完成 UC 会话判据，不能据此判定账号密码错误或会话有效 | 模拟器真实账号尝试与未认证 UC GET（仅记录脱敏状态/可见错误文本）；`CasClientTests.test_login_withHTTP483_usesServerErrorMessage` |
| 44 | §0.3 / §1.7 全局 WebVPN 路线 | 主认证与主要业务请求固定直连；WebVPN 仅用于签到专用会话 | 新增自动/直连/WebVPN 路线。WebVPN 模式与 UBAA 一样将北航 URL 包装到 `d.buaa.edu.cn`，直连遇到 UC 483 时自动切换并重试；登录表单必须沿用页面 `action`，否则会丢失网关 service 上下文。真实账号已在 iPhone 17 Pro Simulator 完成 WebVPN CAS 登录，`uc/status` 返回 `code == 0 + data`。后续修复 `routedData` 重编码 POST body 后，WebVPN 下研究生课表读取 20 个学期、30 周、7 门课程；SPOC 读取 13 项作业；成绩、空教室、图书馆座位、校园通知和 iclass 只读查询也已实测。传输层必须原样转发请求 body，并让同一个 URLSession Cookie 会话完成 SPA→CAS→回调→业务 POST。 | `UpstreamRoute.swift`、`SpocHomeworkClient.swift`、`ScheduleClient.swift`、`AuthViewModel.swift`、`CasClient.swift`、`docs/ACCEPTANCE.md`（2026-10-18） |
| 45 | §5.2 §5.6 图书馆当前预约 | 只有 `member/seat` 历史分页，无法区分当前座位/研讨室/研修座位 | 新增 `index/subscribe` 读取当前记录，解析 `type` 与 `flag_in/flag_out/flag_leave/oksign`；历史列表继续只读。只有上游明确给出动作提示时才显示签到/暂离/完全离开/取消按钮 | H5 公开静态资源 `index.1780450282721.js`、`AppointmentItem.1780450282721.js`（2026-10-19 只读检查）；本项目 `LibraryClient.swift`、`LibraryView.swift`、`IOSLibraryView.swift` 与 `LibraryBookingLifecycleTests.swift` |
| 46 | §5.6 座位签到/临时离开/完全离开 | 只有预约与取消 | 前端静态取证 `space/signin`、`space/leave`、`space/checkout`：明文 `{id, points}`，按当天日期加密为 `aesjson`；`points` 可为空对象。客户端实现二次确认、空定位提交、提交后回查、不自动重试；**未对真实账号发送写请求**，成功语义与暂离时限仍待人工验收 | H5 `AppointmentItem.1780450282721.js`（2026-10-19 只读检查）；本项目 `LibraryClient.swift`、`LibraryView.swift` 与 `LibraryBookingLifecycleTests.swift` |
| 47 | §5.7 研讨室预约 | 只读空档；写接口已定位但字段未补全 | 前端静态取证 `seminar/members`、`seminar/confirm`、`seminar/submit` 请求体与 `earlierPeriods` 分支；客户端实现参与人解析、提交前空档复核、二次确认、不自动重试。`type_id == 5 && earlierPeriods == 3` 与要求附件的空间不提交。**未发送真实预约写请求**，成功语义/名额竞争/取消回查待验收。CGYY 教学楼系统含滑块验证码，按项目红线不接入 | H5 `apply.1780450282721.js`、`space.17804502827215.js`（2026-10-19 只读检查）；本项目 `SeminarModels.swift`、`SeminarViewModel.swift`、`SeminarView.swift`、`IOSSeminarView.swift` 与 `LibraryBookingLifecycleTests.swift` |
| 48 | §6B 教学楼研讨室（CGYY） | 只有图书馆 `v4/seminar/*`，且未接入 CGYY | 移植 UBAA 的 CGYY 登录、MD5 签名、场馆/时段/订单/门锁密码接口与滑块验证码图像匹配；按用户明确要求启用自动识别，写操作前仍需用户确认，失败不自动重发。**未完成真实预约/取消/门锁密码往返** | UBAA `LocalCgyyApi.kt`、`LocalCgyyCaptchaSupport.kt`、`LocalCgyySigner.kt`、`docs/features/cgyy.md`；本项目 `CgyyClient.swift`、`CgyyCaptchaSolver.swift`、`CgyyViewModel.swift`、`CgyyClientTests.swift`（2026-10-19） |
| 49 | §7.4 培养方案进度 | 把课程池全部学分相加，显示 114 学分和 0%，误以为每门课都必修；类别最低分只有网页可见 | 方案头部 `totalCredits` 是最低总学分（当前账号 32）；课程列表是课程池（合计 114）。新增 `zxbg/loadXspyfazxbgInfo.do` 读取执行报告：`zxbg` 返回 9 个类别及 `dxzList` 课组，带 `yqxf/yhxf/dkhxf`；页面显示“思想政治理论课 3、基础及专业理论核心课 9、综合素养课 5、培养环节 1”等要求及课组“数学课 3、当代科技 1”等。接口成功码为 `1`（不是 0），已单独处理；失败时回退总学分/课程池 | 2026-10-19 Edge 页面源码与 `wdpyfazxbg` 模块 `wdpyfazxbgBS.js`、`zxbgBuilder.js` 只读核对；真实账号执行报告接口返回；本项目 `GraduateAcademicClient.swift`、`GraduateProgress.swift`、`GraduateProgressTests.swift` |
| 50 | §7.4 研究生综合服务平台入口 | 只读取学籍/成绩/方案/课表，未盘点其他学生服务 | 平台首页可见：学籍管理、课程学习、培养环节、培养项目、学位管理、教育管理、学生活动、服务指南、教务系统；常用应用含我的培养方案执行报告、我的培养方案、我的成绩、我的日程、周课表、专业实践申请、教室借用申请、学生名单、政策文件。当前只读接入培养方案执行报告/成绩/学籍/课表；专业实践申请、教室借用申请、开题/中期/答辩等写工作流未取证，不接入 | 2026-10-19 平台首页只读 DOM 与 `yjsemaphome` 静态模块；不发送任何申请/借用写请求 |
| 51 | 培养方案执行报告语义 | 将 `XQLHKCXF` 标为论文环节，并以 `yxxf` 回退认定学分 | 更正为校企课程要求，补 `yhxqlhkcxf`；方案认定学分仅取 `yhpyfaxf`。要求与已获缺失时不推算缺口；严格验证执行报告成功码与层级结构 | [取证记录](protocol-evidence/GRADUATE-EXECUTION.md) E1–E6；`GraduateRequirementsTests`、`GraduateAcademicClientTests` |
| 52 | 图书馆与研讨室产品范围 | 历史取证中的图书馆 seminar 被当成产品预约能力 | 按维护者确认，图书馆仅提供座位预约（维护者已验证可行）；研讨室仅指教学楼 CGYY。图书馆 seminar 提交方法直接拒绝，保留历史解析材料不代表可用功能 | 2026-10-19 本轮维护者明确说明；`LibraryClient.submitSeminarBooking` |
| 53 | CGYY 路由与写入结果 | CGYY 跟随全局 WebVPN 路由；公开场馆可读但 SSO/业务会话失败 | CGYY 的 SSO Cookie 和全部业务请求固定直连，忽略全局 WebVPN 选择（与 UBAA 当前实现一致）；401 后仅 GET 可重新登录并重查，预约/取消写入不重发，未知结果进入待核实。当前轮未发送预约/取消请求 | [UBAA `LocalCgyyApi.kt`](https://github.com/BUAASubnet/UBAA/blob/main/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalCgyyApi.kt)、[UBAA CGYY 文档](https://github.com/BUAASubnet/UBAA/blob/main/docs/features/cgyy.md)；本项目 `CgyyClient.swift` |
| 54 | §5.5 Rust/Flutter公共统计 | 镜像未迁移 | 独立Cookie会话读取两校区人数/阅览室及资源余量，五分钟进程缓存，缺指标null，失败保留；不包含Apple端60天历史趋势 | `LibraryPublicStats.swift`、`LibraryPublicStatsParserTests.swift`、Rust四份合成契约与应用测试；2026-10-20 host正式Session/reqwest公开GET解析2校区 |
| 55 | §5.5 公开会话路线 | 复制学校Session已回退的有效路线 | 改为复制用户原始自动/直连/WebVPN偏好；不继承其他业务的自动回退状态，仍隔离Cookie | Android真实只读发现私有业务切网关后公开页失败；Session::activate_automatic_webvpn_fallback源码；应用回归覆盖自动偏好+已回退私有会话；修复后Android无账号真实GET解析2校区 |
| 56 | 镜像会话/只读刷新边界 | bridge读取与清理可能并发；认证恢复失败直接返回 | 不改变上游端点/参数/成功码；bridge并行读与身份/缓存变更互斥，恢复失败保留已有快照，显式退出清理保存账号 | Rust lifecycle/route logout/expired snapshot合成回归；macOS ScheduleViewModel/GradeViewModel generation与失败保留行为 |
| 57 | Android 更新 | macOS Releases 仅含 DMG/ZIP | 沿用官方 GitHub Releases GET，Android 使用独立 android-v 语义版本和 arm64 APK 资产；Cookie 隔离、正式/预发布渠道分离，无学校写操作 | Core/Update/UpdateChecker.swift；2026-10-20 公开 API 仅见 macOS 包；新增合成 updates.android 契约 |
| 58 | SPOC教师上下文 | 镜像忽略课程skjs | queryKclb现有响应中sskcid→kcid关联skjs，缺值保留None；不新增接口 | SpocHomeworkClient.swift:29,168–180；homework.course_context合成契约与缓存回归 |
| 61 | 图书馆加密范围与镜像状态 | §5.3仅confirm加密、镜像写入未实现 | 更正为预约及§5.6生命周期加密；更新镜像写入与真实验收边界；记录UBAA直连端口差异 | LibraryClient.swift / CheckInClient.swift；LocalSigninApi.kt:263–268；镜像提交9f2a8a0 |
| 60 | 镜像签到/图书馆写入 | 全部关闭 | 依现有源码接通手动签到、座位预约、类型匹配取消与生命周期；不重发、二次确认、提交后回查；真实写入待验收 | §5.3/§5.6/§7.2；CheckInClient.performSignIn、LibraryClient.reserve/perform/cancel；合成测试 |
| 59 | BYKC课程目录详情 | 镜像裁剪时间/人数/校区/简介 | 按BykcClient.course投影现有目录字段，详情无需新请求；签到配置仅布尔存在性 | BykcClient.swift:course；EDUCATION-DATA-MAP §2.3；目录契约/缓存隐私回归 |

## 0. 文档约定

### 0.1 证据分级

| 标记 | 含义 | 使用规则 |
|------|------|----------|
| ✅ 已验证 | UBAA 仓库有在用实现，且经真实账号端到端验收 | 可直接按此实现 |
| ⚠️ 待验证／部分证据 | 可已有官方静态实现或限定只读样本，但缺完整行为／权限／写入验收；不一律等于推测 | 逐断言写明静态、历史、受控读取及未知；**缺失行为须先取证**，不能把样本覆盖外推成已验收 |
| —— 中转 | UBAA 中转服务器路由 | 本项目（仅直连）不可用，本文档不展开 |

### 0.2 脱敏声明

本文档所有示例均使用合成数据：学号一律用 `sy2501001`，姓名用「李文」「张三」等通用占位，Cookie/token 值均为 `xxx` 形式占位。任何真实学号、姓名、Cookie、票据**禁止**写入本仓库（含测试快照与提交历史）。

### 0.3 通用请求约定

- 所有业务请求默认由共享 Cookie 的 `URLSession` 会话发出（Cookie 自动携带与保存）。
- 网络路线支持自动 / 直连 / WebVPN。WebVPN 模式按 UBAA 的 `d.buaa.edu.cn` 编码规则包装所有北航 URL，并使用独立进程内 CookieStorage；不实现 ServerRelay。
- 自动模式先直连；UC 返回非标准 HTTP 483 或访问策略页时，持久化切换到 WebVPN 并重新执行登录。
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

**2026-10-18 WebVPN 修复记录**：`code == "1"` 且 `jgList/rwList/jcfaList` 均为空数组，表示该学期尚未发布排课，是合法空课表；客户端返回空的周次/课程快照并显示“该学期暂无课表”，不再报“结构无法识别”。真实账号修复后成功读取 30 周、7 门课程。此前 WebVPN 模式下 `routedData` 对表单 body 重新打包，导致 `loadXskbData.do` 返回三个空数组；传输层现原样转发 `URLRequest.httpBody`，由同一个 URLSession 负责 Cookie 与重定向。

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

- 历史分页依据 `LibraryClient.swift:392–453`：列表为 `data.data[]` 或 `data.list[]`；页码 `current_page|page`、页长 `per_page|limit`、总数 `total|count`、末页 `last_page|lastPage`、下一页 `has_more|hasNextPage`。若有显式下一页标志，必须与总数/末页相容；缺少结束依据不能把任意短页当作末页。镜像每页40条，按页缓存；历史包含进行中/已结束/已取消记录，不将所有记录标为终态。⚠️ 镜像历史分页尚待真实账号响应核验。
- 响应外层 `{ code: Int, message|msg, data }`，**`code` 为 0 或 1 都算成功**（LLB:293-301）。
- 字段名大量存在 `snake_case`/`camelCase` 双写变体（表中用 `|` 列出），解析层两种都要接受。

> 镜像实现（2026-10-21）：上述只读链路已接入。按用户本轮授权，`space/confirm`、`space/signin`、`space/leave`、`space/checkout` 及类型匹配的取消已贯通 Rust/Flutter；逐次确认、单次提交、未知结果不重发、提交后回查。只读历史与新写入仍待真实账号复验，合成测试不替代上游验收。

### 5.3 预约请求加密（AES-CBC）

`space/confirm` 的预约明文如下（LLB:242）；签到/暂离/离馆也使用 AES-CBC，但明文与日期规则见 §5.6：

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

Rust/Flutter镜像采用借用共享transport的独立Session，复制用户原始路线偏好但隔离Cookie jar；五分钟进程快照、用户刷新失败保留旧结果。2026-10-20 host公开GET解析两校区通过，只记录状态/条数；镜像未迁移上述60天本地历史与趋势。

### 5.6 当前预约与座位状态操作（前端静态取证，写入未验收）⚠️

2026-10-19 对 `booking.lib.buaa.edu.cn` 的 H5 前端公开静态资源做了只读检查：主包 `/h5/assets/index.1780450282721.js` 及懒加载 chunk `AppointmentItem.1780450282721.js`、`apply.1780450282721.js`、`space.17804502827215.js`。以下端点、请求体与字段来自前端实际调用的 API 包装和页面动作逻辑；**没有使用真实账号发送签到、暂离或离馆请求**，成功语义、次数限制、定位要求和失败提示仍需人工往返验收。

| 端点 | 用途 | 请求体 | 关键说明 |
|------|------|--------|----------|
| `index/subscribe` | 当前进行中的预约 | `{}` | `data[]`；`type` 1=座位、2=研讨室、3/4=研修座位。只有当前记录带动作提示字段 |
| `space/signin` | 签到入座 / 暂离后返回 | 加密体 `aesjson`；明文 `{id, points}` | `id` 为预约记录 ID |
| `space/leave` | **临时离开** | 加密体 `aesjson`；明文 `{id, points}` | 保留座位；学校可能限制暂离时长，超时释放 |
| `space/checkout` | **完全离开** | 加密体 `aesjson`；明文 `{id, points}` | 结束本次座位使用，不可撤销 |
| `space/cancel` | 取消座位预约 | `{id}` | `type == 1` |
| `space/studyCancel` | 取消研修座位预约 | `{id}` | `type == 3/4` |
| `seminar/cancel` | 取消研讨室预约 | `{id}` | `type == 2` |

加密与 §5.3 相同，但密钥日期取**请求当天**：上游 `HY("encrypt", data)` 使用 `new Date()` 的 `YYYYMMDD` 加其反转；`space/confirm` 使用预约日。`points` 在前端是 `{lat, lng, time}`；浏览器定位不可用时提交 `{}`。客户端不申请系统定位权限，统一提交空 `points`，由学校接口决定是否接受。

当前记录的动作提示字段（均按 0/1 解析，历史 `member/seat` 不保证返回）：

| 字段 | 含义 |
|------|------|
| `flag_in` | 可签到入座 |
| `flag_out` | 可临时离开 |
| `flag_leave` | 当前处于临时离开，可返回入座 |
| `oksign` | 可取消预约 |

客户端行为：只在上游明确给出动作提示时展示按钮；临时离开与完全离开都需二次确认；提交后刷新 `index/subscribe`，结果不明确时只提示“待核实”，**不自动重发**。

### 5.7 研讨室预约写路径（前端静态取证，写入未验收）⚠️

`seminar/list`、`seminar/seminar`、`seminar/sift`、`seminar/siftdate` 的只读链路见 [EDUCATION-DATA-MAP.md](EDUCATION-DATA-MAP.md) §3。写入链路的请求体由 H5 `apply.1780450282721.js` 与 `space.17804502827215.js` 的 API 包装补全：

| 端点 | 用途 | 请求体 |
|------|------|--------|
| `seminar/members` | 解析参与人学号 | `{area_id, member_id, begin_time: "yyyy-MM-dd HH:mm", finish_time: "yyyy-MM-dd HH:mm"}`；返回成员对象（含 `id`） |
| `seminar/confirm` | 普通预约确认 | 见下；`earlierPeriods == 0` 时上游页面调用 |
| `seminar/submit` | 分段/提前时段预约 | 见下；`earlierPeriods != 0` 时上游页面调用 |
| `seminar/cancel` | 取消研讨室预约 | `{id}` |
| `seminar/signin` | 研讨室签到 | 页面包装存在，字段未在本轮展开 |
| `seminar/leave` | 研讨室离馆 | 页面包装存在，字段未在本轮展开 |

提交体（不加密）：

```json
{
  "area_id": "<空间 ID>",
  "start_date": "yyyy-MM-dd",
  "end_date": "yyyy-MM-dd",
  "title": "<申请主题>",
  "title_id": "<readonlyTitle 时的主题 ID，否则空串>",
  "content": "<申请内容>",
  "open": false,
  "team": "<参与人 member id，逗号分隔>",
  "mobile": "<11 位手机号>",
  "time": [{"start_time": "HH:mm", "end_time": "HH:mm"}],
  "file": []
}
```

上游页面在 `type_id == 5 && earlierPeriods == 3` 时还要求 `cate_id`；在 `isMouldShow == 1` 时要求上传附件。这两类空间当前客户端不提交，改为提示到学校原系统完成。

客户端行为：提交前重新读取一次 `seminar/seminar` 并核对空档、最短/最长时长和粒度；用户二次确认后才提交；不自动重试；成功后刷新列表并提示到“图书馆 → 我的预约”核对。**真实预约成功语义、名额竞争、参与人校验、取消回查仍未验收。**

> 产品范围勘误（2026-10-19）：本节是历史协议取证，不是当前功能承诺。图书馆仅提供座位预约；研讨室入口使用教学楼 CGYY（§6B）。图书馆 seminar 提交已停用。

---

## 6. 图书目录、馆藏与本人借阅（2026-10-23 部分只读验证）⚠️

新证据：[i 北航协议研究审计](_audit/2026-10-23-ibuaa-protocol-research.md) §4–5。历史 2026-10-13 对 `lib.buaa.edu.cn/opac/*` 的 404 仅对当时域名／路径成立，不否定现站 `https://space.lib.buaa.edu.cn`。BBAA 的 `LibBook` 是空间选座，不是这里的借阅实现。

### 6.1 共同契约与公开读取

同源基址 `/meta-local`；官方 LS/e650、74b9 与 LC/aacb 严格以**数值 `code===0`** 解 `data`；HTTP200 本身不够。前端使用运行态语言／CSRF头，报告不保存值。以下是官方脚本与本轮匿名 curl 的交集，不表示已接入本项目。

> **2026-10-23 实机发现与处置：`space.lib.buaa.edu.cn` 证书链不完整**。该主机只下发叶子证书 `CN=*.lib.buaa.edu.cn`，缺少中间证书 `GlobalSign GCC R3 DV TLS CA 2020`（`openssl s_client` 返回 `Verify return code: 21`）。macOS／浏览器靠系统验证器的 AIA 补链才能成功，rustls 不做 AIA，因此本项目直连曾报 `serviceUnavailable`。
>
> 处置：**不放宽全局 TLS、不改系统信任库、不绕 WebVPN**，改为**按主机作用域**加载该中间证书——`rust/certs/globalsign_gcc_r3_dv_tls_ca_2020.pem`（来自叶子证书 AIA 地址，`CN=GlobalSign GCC R3 DV TLS CA 2020`，签发者 GlobalSign Root CA - R3，`CA:TRUE, pathlen:0`，2029-03-18 到期）只加到 `space.lib.buaa.edu.cn` 专用 client；其他主机仍用默认信任库。回滚＝删除该文件与 `reqwest_transport.rs` 中的常量即可。2026-10-23 实机复验：检索返回真实 9 条结果、馆藏返回真实复本与“可借”状态。

> **2026-10-23 Android 只读接入（search 与 holdings）**：`POST /opac/search` 与 `GET /opac/bibs/{bibId}/holdings` 已进入 Rust 适配层，使用**隔离 Cookie 会话**（不带登录态），`code !== 0` 归为业务拒绝而不是空列表；`data.holdings` 的 JSON 字符串在 Rust 内二次解码，限制 512 KiB／深度 8／500 条。页面只做检索与复本展示，不提供续借、预约、委托或任何写操作，也不读取本人借阅。字段缺失保留空值，`callno` 兼收数组与字符串，馆藏状态只保留学校原文。**真实服务的完整字段、状态码映射与分页边界仍未验收。**

| 方法／路径（接基址） | 参数／形状 | 证据状态 |
| --- | --- | --- |
| POST `/opac/search?coverFirst=false&disable_facet=false` | JSON `page,pageSize,indexName,sortField,sortType,collapseField,queryFieldList,filterFieldList`；普通综合词项 `{logic:0,field:"all",values:[词],operator:"*"}` | 匿名 page1/size2 成功非空，code0；响应 data含 total/actualTotal/offset/limit/dataList/facetList/extraInfo |
| GET `/opac/search/search_confs`、`/opac/search/_suggest` | suggest参数 fieldName/query/size7；配置决定完整字段／排序 | 静态已见，未逐项实测 |
| GET `/opac/bibs/{编码bibId}/holdings?isMobile=0&relateStat=1` | 实测 `data.holdings` 是 JSON 字符串，二次解码复本数组 | 一条公开书目成功非空；状态映射、所有编码分支待验 |
| GET `/opac/commend/hot1?count=2` | data数组，含 bibId/rank/hotValue/title 等 | 匿名code0；统计公式、月份／校区范围未知 |
| GET `/opac/new/books?page=1&pageSize=2` | data.dataList 等；有 onSelfDate、书目／馆藏相关字段 | 匿名code0非空；不是热门榜 |
| GET `/opac/search/extend/{id}?coversOnly=true`；POST `/opac/search/extend3?coversOnly=true` | 批量 body `{isbns:[],bibIds:[]}`，按bibId取imageUrl | 仅静态；图片域名／非空／占位及白名单待验，不猜封面地址 |

默认 SearchParam 为 page1/pageSize20、idx.opac、relevance/desc、collapseField=groupId；列表 UI total 封顶10000而 maxTotal保留原值。实际样本 callno 在检索为数组、hot为字符串，ISBN/bibId/索书号/册条码不可互换。馆藏数组有 callNo/barCode/library/locationName/circStatus/itemStatus/status/itemsAvailable 等；不能凭字段名或数值猜可借状态。

分类榜静态 GET `/opac/commend/{sort}/byclass` 或 `/bysubject`，query dcpCode/page/pageSize；sort枚举 top/top_loans/top_favorites/top_scores，但实际render未呈现排序控件、未见月份／公式。dcpCode有预编码再URLSearchParams路径，不能擅自简化。端点存在≠完整榜单语义已验证。

### 6.2 本人借阅与隐私

官方 LL/02d9 固定 GET `/opac/users/loans?page=1&pageSize=100`，取 data.items；非空才同 query读 `/loan_max_renew_times`，按册条码合并 maxRenewTimes-renewTimes。本轮已登录本人页：loans HTTP200/code0、items=[]；分页键 currentPage/pageSize/total/items/totalPage。GET `/opac/users/loan_info` 同样成功，data为字符串，不是对象。**只验证成功空态，非空个人字段、分页完备性、会话过期未验收。**

非空字段 loanId/bibId/item.barCode/bibAttrs.title/author/callno/loanDate/dueDate/renewTimes/location/loanType/requestStatus/loanStatus 来自静态组件，不是本人的成功非空样本。剩余次数、按钮可见都不是服务端完整续借资格。

只识别未调用：POST `/opac/users/renew`、`/batch_renew`，预约／委托／取消／书架写。通知详情GET也可能写已读，不默认纳入只读刷新。本人记录主动打开、默认内存、离页／登出／切账号清除；读取记录并不授权持久化、到期通知或阅读画像。待办仍只记 MIRROR-TODO，不在本节另建清单。

---

## 6A. 空教室（源码已核对，真机待验收）

依据：2026-10-15 核对 UBAA main 的 `LocalClassroomApi.kt`、`model/dto/Classroom.kt` 与 `ClassroomViewModel.kt`。此分级仅表示源码证据，未宣称本应用真实账号验收完成。

1. GET SSO service：`https://app.buaa.edu.cn/a_buaa/api/cas/index?redirect=https%3A%2F%2Fapp.buaa.edu.cn%2Fsite%2FclassRoomQuery%2Findex&from=wap&login_from=`，SSO 查询包含 `noAutoRedirect=1`。使用共享 Cookie 激活业务会话。
2. GET `https://app.buaa.edu.cn/buaafreeclass/wap/default/search1?xqid=1&floorid=&date=yyyy-MM-dd`。注意路径为 **buaafreeclass**；旧 BACKLOG 少了一个 a。校区 `1=学院路 / 2=沙河 / 3=杭州`。Ajax 头与 Referer `https://app.buaa.edu.cn/site/classRoomQuery/index`。
3. 响应 `{e:0,m:"",d:{list:{楼栋:[{id,floorid,name,kxsds}]}}}`，`kxsds` 为逗号分隔空闲节次。非零 e、HTML 登录页、结构缺失均报错，不当作无空教室。

## 6B. 教学楼研讨室（CGYY，前端/UBAA 协议移植，真实写操作未验收）⚠️

基址 `https://cgyy.buaa.edu.cn/venue-zhjs-server/`。协议依据为 UBAA `LocalCgyyApi.kt`、`LocalCgyyCaptchaSupport.kt`、`LocalCgyySigner.kt`、`docs/features/cgyy.md`，并于 2026-10-19 在已登录浏览器中只读打开学校“培养方案管理应用”页面确认了上游网页结构；**尚未用真实账号完成预约、取消或门锁密码的端到端验收**。

1. **登录与路线**：GET `sso/manageLogin`（直连并跟随 SSO 重定向），从直连 Cookie Store 取 `sso_buaa_zhjs_token`；POST `/api/login`，头 `Sso-Token: <cookie>`，返回 `data.token.access_token`。后续请求头 `cgAuthorization: <token>`（原始 token，无 Bearer 前缀）。CGYY 的 SSO 和全部业务端点都固定直连，即使全局上游路线选择 WebVPN 也不包装到网关；与 UBAA 当前 `LocalCgyyApi` 一致。新版本仅做只读验收，未发送真实预约/取消写请求。
2. **签名**：所有请求带 `app-key`、`timestamp`（毫秒）、`sign`。签名原文为：
   ```
   <prefix><path><按 key 排序的 key+value 拼接><timestamp> <prefix>
   ```
   `prefix = c640ca392cd45fb3a55b00a63a86c618`，`app-key = 8fceb735082b5a529312040b58ea780b`；排除 `gmtCreate/gmtModified/creator/modifier/id/_index/_rowKey`；GET 额外加 `nocache=<timestamp>`；MD5 hex。
3. **只读端点**：
   - GET `/api/front/website/venues?page=-1&size=-1&reservationRoleId=3`：校区/场地/空间组。**2026-10-19 无 Cookie 直连实测为公开接口**，不发送 `cgAuthorization` 也返回 `code=200`；页面因此可以先展示场馆，不能因为后面的登录失败把整页判成“未登录”。
   - GET `/api/codes`：活动类型；未带 token 实测 `code=401 没有权限访问此接口`。
   - GET `/api/reservation/day/info?searchDate=yyyy-MM-dd&venueSiteId=N`：`spaceTimeInfo`、`reservationDateSpaceInfo`、可预约日期、`token`；未带 token 同样 401。
   - GET `/api/orders/mine`：我的预约。当前客户端固定 page1/size20 是实现事实；2026-10-23 官方移动端静态首请求明确 page0/size5，见 §6B.1，不把 page1 当学校起始页契约。
   - GET `/api/orders/lock/code`：门锁密码/二维码、有效期、预约详情。
4. **预约写路径**：
   - POST `/api/reservation/order/info`：`venueSiteId`、`reservationDate`、`weekStartDate`、`reservationOrderJson`（`[{spaceId,timeId,venueSpaceGroupId}]`）、`token`；项目称预约草稿，官方会将响应 tradeNo／详情／计时／isCaptchaCheck 等交给下一步；是否占槽及生命周期未实测。
   - GET `/api/captcha/get?captchaType=blockPuzzle&clientUid=slider-<ts>&ts=<ts>`：返回 `secretKey`、`token`、背景图、拼图 Base64。
   - POST `/api/captcha/check`：`pointJson`（AES-ECB PKCS5 加密的 `{"x":N,"y":5}`）、`token`。
   - POST `/api/reservation/order/submit`：草稿字段 + `captchaVerification`（AES-ECB 加密的 `<captchaToken>---{"x":N,"y":5}`）+ `token`。
   - POST `/api/orders/new/cancel/{orderId}`：取消。
5. **验证码**：UBAA 的做法是灰度边缘匹配求解滑块；本项目已按用户明确要求移植该算法。该行为会改动项目原先“不自动绕过验证码”的红线，使用者需自行承担上游使用条款与风控风险；实现中不保存验证码图片，只在内存中完成一次匹配。

2026-10-22 镜像实现：Rust 沿用本节端点与字段，验证码采用用户手动拖动，AES-ECB 与签名仍由 Rust 完成；学校 token、密钥、预约 token 不跨 FFI。草稿前、手动验证后均复核空档，未知单元格不可提交。提交 / 取消只发送一次；受理不等于成功，须查回匹配订单 / 取消状态。无明确结果时保持写入保护，用户先只读回查并确认已核对。该实现仅有合成与界面证据，不能标记为真实写入验收。

2026-10-22 本轮闭环补充（仅客户端行为，不改变上游协议）：预约/取消前写入本机账号摘要隔离的最小 pending 标记，内容只有版本与布尔值；无 token、表单或手机号，损坏/不可写拒绝继续写。正常入口 native gateway 绑定发起账号作为前置条件，身份仍由 Rust 会话派生。HTTP 错误、未知业务码、解析失败与认证失败都保留核实保护；`BusinessRejected` 只读 v1 分类不得用于证明写入未生效。显式强读的最近 20 条必须展示后再确认，一次性核对凭据绑定账号/身份代次且 120 秒内有效；不能用空列表证明没落单。订单审批码沿用既有 Swift/UBAA 映射，未知状态不推断通过；取消资格必须明确满足状态及开始前 4 小时限制，最终仍强读复核。共享解析 v1 五字段与历史错误契约不变，新增审批与资格只在 live 投影中提供。未增加分页/门锁码或自动验证能力。

> 图书馆空间预约系统（`booking.lib.buaa.edu.cn/v4/seminar/*`）是另一套系统，本页不再作为“研讨室”入口；其只读/预约代码保留在 `Features/Library/`，但与教学楼 CGYY 不可混用。

---

### 6B.1 2026-10-23 官方前端静态修订（未执行写）

来源与精确 hash/module/UTF-16偏移见[审计 §7](_audit/2026-10-23-ibuaa-protocol-research.md)。这些断言更新协议证据，**不能宣称故障根因或真实写入已验收**。

> **2026-10-23 Android 实现同步（仅合成回归）**：下列静态差异已在 Rust 侧按“有界、可回滚、不降低保护”的方式落地，Flutter 只改传参形态。真实学校写操作仍未执行。
> - `read_orders`：首请求 `page=0&size=5`（官方移动首请求），最多 4 页，遇短页／重复 id／`totalElements` 即停；返回可见行数而非宣称历史完整。
> - `week_start`：取 day 响应 `reservationDateList[0]`（回退 `ableReservationDateList[0]`，且必须是合法日期）；缺失时**省略** `weekStartDate`，绝不回填预约当天。
> - 草稿响应不再丢弃：保留 `tradeNo` 参与回查比对；草稿自身的 token 不覆盖 day 的 orderToken。
> - 验证码坐标：Flutter 传 `x`（滑块偏移）与 `width`（背景图宽），Rust 计算 `310*x/width`、保留两位小数并夹在 `[0,310]`；不再按原图像素直传。
> - 验证成功后额外 day 若返回**不同的** token，则在任何 POST 前返回 `notSubmitted`（既不盲删复核也不静默换 token）。
> - 提交回查：必须 id＋预约日期（且双方都有 `tradeNo` 时也要一致）才记 `accepted`，否则保持待核实。
> - 未落地（证据不足）：`spaceId/timeId` 是否应为字符串、`repCode`/`success` 双字段冲突处理、`reservationType==-1` 分支、持久 UUID 风格 `clientUid`；`venueSpaceGroupId` 继续显式 `null` 并已有字节级断言。

- 官方 `/mobileOrders` 模块 d119 发 `{page:currentPage-1,size:pageSize}`，初始 currentPage1/size5，非管理员走 `/api/orders/mine`；解 content/totalElements。首请求 page0 有直接静态依据；服务端排序／新单落页／异步可见仍未知，修订须有界翻页而非只换一个数字。
- day响应 `reservationDateList[0]||""`→weekStartDate；不是无条件预约当天，也不能凭名改成周一。day token→orderToken，info成功回调保留响应并覆盖其token为day值。
- info请求的spaceId/timeId来自split、为字符串；group不适用时显式null。最终submit值来自info响应，reservationType==-1分支group同样显式null。因此Rust null不能笼统判错，Swift nil省略也不能天然认定正确；两阶段类型与签名字节须分别验证。
- info响应被消费的字段含 tradeNo/orderDetailList/venueInfoBean/计时/isCaptchaCheck；现两端丢弃响应存在建模缺口，但静态读取不证明服务端必返／必填。验证码成功的这条官方链直接submit，没有额外day；再次day是否轮换token／info是否占槽仍未知，不盲删复核。
- 官方预约滑块 GET `/api/captcha/get` 带 captchaType/clientUid/ts，POST `/api/captcha/check` 带 pointJson/token，均按 `repCode=="0000"` 解 repData。现 success 解析需双字段兼容／冲突证据，不因静态不同就断言真实失败。
- 显示宽330px，协议 `x=310*parseInt(moveBlockLeft)/parseInt(setSize.imgWidth)`、y5，可小数；非天然图片像素。不能只把Rust整数上限从310放宽到1000。挑战secret存在才加密，未读任何实际挑战。
- isCaptchaCheck有条件分支，官方本地clientUid为持久UUID风格；均需成功样本才能调整。官方提交文案与审批分开；本项目强读、单写、未知核实、账号隔离不可降低。

## 6C. 智慧校车（脚本静态＋本人查询页面观察，未购票）⚠️

> **2026-10-23 Android 处置**：只接入**官方公开时刻表外链**（`https://www.buaa.edu.cn/info/1065/1762.htm`，`服务`页“校车时刻表”，二次确认后交给系统浏览器），并在对话框里写明“不代理购票、不显示实时余票（查询协议未取证）”。动态 `/wechat/ShiftsSearch` 不接入：缺完整单次事务形状、身份资格与退改语义证据，不摆空壳卡片、不把班次卡做成购票入口。

站点 `https://zhihuixiaoche.buaa.edu.cn/wechat/indexPage`。同页脚本：POST `/wechat/ShiftsSearch`，form字段 up_origin_name/up_terminal_name/shifts_date/act=search，动态CSRF头；按 data.success和list读取。用户查询后页面显示12班及差异余票，**尚未捕获该单次事务的完整网络字段形状，method/body来自脚本，不把UI成功等同完整协议验收**。

非摆渡余票先 open_seat_num-student_num-teacher_num，再按type/is_parttime/currentTime/ticket_all_minute/seat_retain_num分支扣保留，负数夹0；摆渡显示“摆渡车”，不显示计算值0。此为当前身份展示算法，匿名可见性、资格、票价、时间单位／时区、所有放票分支未验。时刻表通知发布日和适用日分开，不用计划人数代余票。POST退款、购票、订单、团体票等未调用。详见[审计 §6](_audit/2026-10-23-ibuaa-protocol-research.md)。

## 6D. 阳光打卡（官方静态；下一阶段手动提交需求，真实写未验收）⚠️

用户明确要求手动提交功能；本轮仅研究，不实现／不上传／不提交。完整原站hash与UTF-16偏移见[审计 §8](_audit/2026-10-23-ibuaa-protocol-research.md)；设计见[方案 §12.7](NEXT-STAGE-PLAN-2026-10-23.md)。不把阳光活动打卡与iClass课程签到混同。

- YM/1172：逻辑路径 `getList/getCount/get/clockin` 在 `/Front/Clockin/Clockin/` 下；上传 `/Front/Upload/File/post`。base由部署origin/path再拼api，**最终URL未实网确认**。get包装除登录外转POST并合并身份字段，code==1解包；不是HTTP POST即写。UTP重复合并的线缆编码仍待验证。
- 体育／艺术表单K共同字段 `start_time,end_time,place_type,place,isopen,form_time_fmt,images,classify_id,item_id,item_name`，艺术另 `thought,issync`。分类／子项目动态加载；moment X生成Unix秒字符串，时区、跨天、合法时长和补录政策仍未确认。
- 地点手填，place_type1校内/2校外；已读表单无坐标／定位SDK调用，不能凭整站阴性检索断言没有宿主安全校验，亦无依据现在申请定位权限。
- 至少1最多3张本人出镜图，JPG/JPEG/PNG、每张5MiB；多次FormData字段file上传→file_name数组JSON字符串→K.images，再一次clockin。上传本身为写；部分成功与提交未知要分别保护，不自动重传或删残留。
- 官网isopen默认1公开广场。方案建议新草稿向学校请求 `isopen=0`，上传前确认页醒目告知；这是客户端提议，服务端是否接受／私密是否真实生效必须实测。证据不足时不得把界面标成“已私密／不会公开”，并应阻断真实提交。首期不承诺艺术issync博雅同步（未见可达切换及完整协议）。
- clockin响应静态读取record_id、period_id/term_id、体育week_count/week_num或艺术month_count/month_num。周月超额／非周期提示来自**提交之后**，不是前置拒绝；已记录、有效计数和审核／考勤不可混同。
- YD/2860按record_id查询详情是回查候选，未实测；无ID超时用人工记录核验，不靠模糊列表或空列表自动判断结果。不照搬官网缺业务catch/finally／单飞门禁的行为。
- 下一阶段必须做到上传前本人确认、账号绑定、批次单飞、一次clockin、未知不重发、重认证不重放、失败清理敏感本地临时数据、按ID只读核验。照片处理／EXIF、上传残留权限、服务器幂等、所有字段规则尚未知；真实写须另明确授权。


---

## 7. 本期不接入的系统（中转接口说明）

旧版文档第 6-15 节（博雅 BYKC、SPOC、操场 CGYY、阳光打卡 YGDK、iHome、空闲教室、课程评价、iclass 签到、考试安排中转版）记载的 `/api/v1/*` 路径全部是 **UBAA Ktor 中转服务器的自有路由**（见 `BBAA/docs/tech/server-routes.md`），不是北航上游直连协议。本项目架构为仅直连（ARCHITECTURE.md §9.1.3），这些接口**无法使用**；上述系统若未来要接入，每个都需按 §6 的逆向流程重新取证（其中博雅/操场还涉及上游自定义加密，见 DEEP-ARCHITECTURE-REVIEW.md §3）。此处不再罗列。

### 7.1 BBAA 原版作业实现对照（2026-10-15）

BBAA 原版并非只有一个作业来源，而是同时实现了两套直连上游：

- **希冀 Judge**：`shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalJudgeApi.kt`。先访问 `sso.buaa.edu.cn/login?service=http%3A%2F%2Fjudge.buaa.edu.cn%2F` 激活 Cookie，再访问 `judge.buaa.edu.cn/courselist.jsp?courseID=0`、课程选择页和 `assignment/index.jsp`，解析 HTML 课程、作业和详情。原版列表缓存 TTL 为 5 分钟，详情缓存 TTL 为 2 分钟。

  **2026-10-16 更新**：本项目将 CAS 激活链接改为 `service=https%3A%2F%2Fjudge.buaa.edu.cn%2F`——照抄 `http` 会在 macOS ATS 下以 `-1022` 失败（明文跳转被拒），https 已验证能完成激活与后续读取。真实课程列表结构与客户端预期仍不一致，且当前验收账号没有希冀作业，因此希冀来源在本项目暂时下线（`HomeworkSource.enabled = [.spoc]`），作业页只展示 SPOC；代码、协议研究与测试保留，待真实页面脱敏样本补齐后重新启用。

Judge 作业详情页同时包含开始/截止时间、满分、题目表格、题目提交状态及得分。桌面端现按原版本地客户端解析题目行并显示整体进度和分数；读取详情前重新选择所属课程，避免依赖共享会话中偶然残留的当前课程。Judge 解析仅用于只读信息展示，不暴露作业提交操作。
- **SPOC**：`LocalSpocApi.kt` + `LocalSpocSupport.kt`。通过 `spoc.buaa.edu.cn/spocnewht/cas` 获取 token，再调用 `sys/casLogin` 获取 `RoleCode`；当前学期和课程来自 `inco/ht/queryOne`、`jxkj/queryKclb`，作业分页来自 `inco/ht/queryListByPage`。分页参数使用 AES-CBC（key `inco12345678ocni`，IV `ocni12345678inco`，零填充）后 Base64 编码。

  **2026-10-18 WebVPN 实测契约**：先 GET `/spocnew/` 预热 SPA，再一次性跟随 `/spocnewht/cas` 的完整重定向链（SSO → `/spocnew/cas?token=...&refreshToken=...`）；回调页即使返回 404 也必须访问，以建立后续请求依赖的会话。随后 POST `/spocnewht/sys/casLogin`，body 必须是原始 JSON `{"token":"..."}`，Header 使用 `Token: Inco-<token>`。成功响应为 `code == 200` 且 `content` 是对象；角色可从 `rolecode`、`jsdmList` 或 `role[].jsdm` 解析。不要把 body 解包后重编码，也不要手工覆盖 Cookie；必须让同一个 URLSession Cookie 会话贯穿 SPA、CAS 和业务 POST。按此修复后真实账号读取 13 项 SPOC 作业。

作业页时间字段：分页记录的 `zykssj` 是开始/发布时间、`zyjzsj` 是截止时间。UBAA 对 ISO-8601 毫秒与时区输入做归一化；Swift 客户端现按同类格式解析并在列表中分行展示发布与截止时间。某条记录若上游字段为空或无法解析，仍明确显示“未确认”，不伪造时间。

提交状态字段 `tjzt` 按已知字符串/代码映射为已提交或未提交；原实现对未知非空值保留 `UNKNOWN`，并由 `submissionStatusText` 附上原始文本。Swift 端同步保留可选 `statusDetail`，仅在状态未知时用于卡片/详情的“上游状态”说明，展示最多 48 个字符；该值缺失时仍显示“待确认”，不改变状态判断或筛选。

原版只读详情通过 `GET /spocnewht/kczy/queryKczyInfoByid?id=<assignmentId>` 获取作业正文、时间与分值，通过 `GET /spocnewht/kczy/queryXsSubmitKczyInfo?kczyid=<assignmentId>` 获取提交状态与提交时间；课程查询还提供教师 `skjs`，作业分页项提供课程标识 `sskcid`（BBAA 映射为 DTO `courseId`）。桌面端将该标识作为可选 `courseID` 保存到作业模型与缓存，老缓存缺失时仍可读取；这里只保留已观察字段，不推断任何提交请求参数。BBAA `SpocApiBackend` 接口只定义 `getAssignments()` 与 `getAssignmentDetail()`，`LocalSpocApi` 也只有这两条读路径。当前检查未发现 SPOC 作业上传/提交方法或可引用的上传端点；这只是对当前 BBAA 源码的限定性结论，不代表上游不存在该功能。桌面端详情查询据此按只读实现，上传仍等待正常浏览器操作的脱敏 HAR、字段/附件协议和人工确认。

2026-10-16 只读检查 SPOC 官网当前静态 SPA bundle `js/app.cf9bd4cf.js`，发现前端 API 模块声明 `POST /kczy/submitKcz2`，请求体通过导入依赖的 `stringify` 函数序列化并标注 `application/x-www-form-urlencoded`；同一模块还声明 `GET /kczy/queryFjList`（查询参数）及多个作业列表/详情方法。进一步检查该模块的定义、导出映射与函数引用：`submitKcz2`（局部函数 `E`）和 `queryFjList`（局部函数 `J`）均只见定义、未见模块内调用，也未导出。这是“静态 bundle 含未见调用的路由包装”证据，不能证明当前页面实际使用它们；仍未确认字段、权限角色、附件 ID 绑定、响应成功条件或提交后查询是否权威。bundle 中另出现 TinyMCE 编辑器使用的 `/fileManagerSystem/uploadFullfile`（multipart 字段 `file`）与 `/customFileManagerSystem/editorUploadFile`；前者在编辑器上传 handler 中被调用，二者当前只能标为通用编辑器上传链路，不能据此认定为学生作业附件上传。公开的同名 `.js.map` source map 返回 404，无法借助映射文件还原组件调用关系。BBAA `SpocAssignmentsResponse` 另含学期名称/代码，桌面端本轮开始保留这两个查询上下文字段用于界面提示；该学期信息不能替代来源完整性判断。桌面端继续保持只读，待正常网页操作的脱敏 HAR 或可关联的页面调用证据后再实现。

2026-10-16 CUA 运行态对一个列表作业打开详情，界面成功显示授课教师、提交状态、发布时间、截止时间和作业分值；该条目的正文未由上游返回，界面提示原站点检查。因系统窗口截图捕获当前不可用，本次 UI 证据来自应用无障碍树；这是已打开页面的状态证据，不代表正文字段对所有 SPOC 作业均为空。

`/api/v1/judge/*` 和 `/api/v1/spoc/*` 仍是 BBAA 服务端中转路由，本项目不调用它们。当前 Swift 工程保留 Judge 与 SPOC 两个直连 provider 和统一作业模型；SPOC AES-CBC 有 UBAA 黄金向量回归测试。2026-10-18 在 WebVPN 下按上述 SPA 预热/完整回调/原样 body 规则实测读取 13 项作业；SPOC 全课程完整性与发布字段逐条正确性仍需继续核对。希冀来源暂时下线（见上），当前真实账号请求仍在课程列表阶段报结构无法识别；重新启用 Judge 前必须取得脱敏页面样本并由本人逐项对照详情页提交状态。

### 7.2 iclass 签到状态与手动提交（写协议尚待真实验收）

候选流程最初来自 BBAA `LocalSigninApi.kt` 与模拟测试。2026-10-15 经用户授权的临时账号，通过北航 WebVPN 浏览器会话对真实服务进行了只读请求观察；没有执行签到提交，未保存原始响应或账号字段。

- 认证入口：`https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter`。正常 SSO 会话跳转后，最终 URL 查询中含 `loginName`；本项目从重定向 Location/最终 URL 提取，不记录该值。
- app session：GET `https://iclass.buaa.edu.cn:8347/app/user/login.action`，查询参数 `password`（空值）、`phone`（上一步 loginName）、`userLevel=1`、`verificationType=2`、`verificationUrl`（空值）。本次观察到 HTTP 200、`STATUS=0`，响应 `result` 含 `id` 和 `sessionId`；两值仅用于内存请求，不持久化。
- 当天列表：GET `https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action`，查询参数 `id`、`dateStr=yyyyMMdd`，请求头 `sessionId`。本次观察到 HTTP 200、`STATUS=0`、`total=2`、返回 2 条记录；字段名包括 `id`、`courseName`、`classBeginTime`、`classEndTime`、`signStatus` 等。脱敏观察到 `signStatus` 值 `0` 和 `1`；BBAA DTO 将其解释为未签到/已签到。
- 源码差异复核（2026-10-21）：当前 UBAA `LocalSigninApi.kt:263–268` 的签到辅助函数在直连采用 HTTP 8081（提交带 `/eschool/`），WebVPN采用 HTTPS 8347（提交不带该前缀）。Ginkgo macOS与Rust镜像沿用HTTPS 8347；尚无本轮直连写入实测，不宣称两条路线完全等价，也不自动降级到明文HTTP。
- 历史日期查询沿用同一 GET 与 `dateStr=yyyyMMdd`，依据当前 `CheckInClient.loadOnDate(account:date:)`（92–94行）与225–230行；返回字段/状态解析不变。镜像限制日期不晚于学校今天；同日期快照复用、跨日期隔离；无课程/未签到不推断缺勤。⚠️ 本次历史日期尚未真实账号验证，不能用先前当天响应替代。
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

> 镜像实现（2026-10-20）：Rust/Flutter 已接入入口 SSO、app login 与当天课程查询的只读链路，字段与状态语义按本节；STATUS=2 只对当天课程查询解释为空，其他非成功 STATUS 返回业务拒绝；重复记录按 id 或课程时间合并，状态冲突显示待确认。WebVPN 路由下，`session` 把网关响应的 final URL/Location 还原为上游 URL；直连不可达时只对有界安全 GET 回退。网关自身需要 CAS 会话，镜像仅在平台保险库保存了密码时自动建立，否则要求重新登录。镜像没有实现 `stu_scan_sign.action`，页面没有签到提交入口；共享 fixture 与 Android 合成设备测试不能替代真实签到状态验收。

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

### 7.3 2026-10-18 教育系统只读数据盘点

在用户明确授权的测试账号上，先完成 WebVPN CAS 登录，再逐项发起幂等 GET/查询请求；没有执行预约、取消、签到、评教或其他写入。结果如下：

| 系统 | 本次可读取的数据 | 结果 | 说明 |
|------|------------------|------|------|
| 研究生教务 | 学期列表、周次、课程排课 | 20 个学期、30 周、7 门课程 | 当前学期有数据；三个空数组也按合法空课表处理 |
| 成绩 | 学期成绩容器 | HTTP/解析成功，当前账号课程数为 0 | “0 条”是真实空结果，不代表接口不可用 |
| 空教室 | 楼栋、教室与空闲节次 | 3 栋、158 间 | 只读日期查询 |
| 图书馆座位 | 楼馆列表 | 3 个馆 | 未预约、未取消 |
| 图书馆公开人数 | 校区与阅览室人数 | 2 个校区 | 官网公开页面解析 |
| 校园通知 | 通知标题/日期/链接 | 5 条 | 仅列表读取 |
| SPOC | 当前学期、课程、作业列表 | 13 项作业 | 未读取或提交作业附件 |
| iclass | 当天课程与签到状态 | 查询成功，本次 0 门课 | 未调用签到写接口 |

### 7.4 培养方案执行报告（结构化类别/课组）

2026-10-19 从 `wdpyfazxbg` 微应用静态模块 `wdpyfazxbgBS.js` 定位到：

- POST `/gsapp/sys/wdpyfazxbgappbuaa/zxbg/loadXspyfazxbgInfo.do`，表单 `isShowSszxbg=0`，Referer `.../wdpyfazxbgappbuaa/*default/index.do`。
- 该端点成功码是 **`code == 1`**（页面脚本把 `code === 0` 当作“无数据/错误”），不能套用其他教务接口的 `code == 0`。
- 返回顶层：`fa.ZDXF` 总学分要求、`yhpyfaxf` 已获培养方案要求学分、`yxxf` 已修学分、`dkhxf` 待考核学分、`yhyjxf` 已获研究学分、`scxx` 分阶段学分；`zxbg` 是 **JSON 字符串**。
- `zxbg` 数组元素：`kclbdm/kclbmc` 类别，`yqxf/yhxf/dkhxf` 要求/已获/待考核，`dxzList` 多选课组，`kcList` 直接课程。课组字段 `dxzmc/yqxf/yhxf/dkhxf/kcList`；课程字段 `kcdm/kcmc/xf/sfwc/cjxsz/xnxqmc/kksx`。部分类别用 `kclbhbzyq` 记录“所属合并组：综合实践，最低学分要求：8.0”这类说明，客户端按说明展示，不把 8 分重复加到每个子类别。
- 本项目只读接入；页面按 `zxbg` 的类别/课组要求展示“要求/已获/待考核”，总学分仍以 `fa.ZDXF` 为准；接口失败时回退到方案头部与课程池，不伪造类别要求。

| UC | `userinfo` JSON | HTTP 200、合法 JSON | `userinfo` API 尚未接入产品 UI，不保存响应正文 |
| 希冀 Judge | 课程列表 | 结构无法识别 | 来源继续保持下线，需真实脱敏页面样本重新适配 |

UBAA 源码另提供操场 CGYY、阳光打卡 YGDK、iHome、课程评教、图书馆借阅等本地协议线索，但本次未逐项真实验收，不能因为源码存在就宣称“可读取”。其中评教/签到/预约还包含写路径，后续只能逐端点、只读优先接入，写入必须人工确认并回查。博雅 BYKC、研讨室和研究生教务的详细字段与 API 已另行记录在 [EDUCATION-DATA-MAP.md](EDUCATION-DATA-MAP.md)。

其中博雅课程库、研讨室空档和研究生教务摘要已完成共享客户端与原生 iOS 页面接入，并通过真实账号 live UI 测试；三者均为只读，不发送选课、预约、评教或提交请求。

---

## 附录 A：已验证 URL 总表

| 系统 | URL | 认证 | 数据格式 |
|------|-----|------|----------|
| SSO | `https://sso.buaa.edu.cn/login`（+`/captcha`、`/logout`） | 表单 CAS | HTML |
| UC | `https://uc.buaa.edu.cn/api/login`、`/api/uc/status` | SSO Cookie | JSON |
| 本科教务 | `https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/...`（`currentUser.do`、`student/schoolCalendars.do`、`getTermWeeks.do`、`student/getMyScheduleDetail.do`、`teachingSchedule/detail.do`、`student/exams.do`） | SSO Cookie | JSON |
| 研究生教务 | `https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/...`（`*default/index.do`、`modules/xskcb/kfdxnxqcx.do`、`bykb/loadXskbData.do`） | SSO Cookie | JSON |
| 成绩 | `https://app.buaa.edu.cn/buaascore/wap/default/index`（GET+POST 同址） | SSO Cookie | JSON |
| SPOC | `https://spoc.buaa.edu.cn/spocnew/`、`/spocnewht/cas`、`/sys/casLogin`、`/inco/ht/*`、`/jxkj/queryKclb` | CAS→Inco token+RoleCode | JSON |
| 希冀 Judge | `https://judge.buaa.edu.cn/courselist.jsp`、课程页、`assignment/index.jsp` | CAS Cookie | HTML（当前解析待适配） |
| 空教室 | `https://app.buaa.edu.cn/buaafreeclass/wap/default/search1` | SSO Cookie | JSON |
| 教学楼研讨室（CGYY） | `https://cgyy.buaa.edu.cn/venue-zhjs-server/`（`sso/manageLogin`、`/api/*`） | CAS Cookie → `sso_buaa_zhjs_token` → access_token + MD5 签名 | JSON |
| 图书馆座位 | `https://booking.lib.buaa.edu.cn/v4/...`（`login/cas`、`login/user`、`space/*`、`index/subscribe`、`member/seat`、`seminar/*`） | CAS→token | JSON |
| 图书馆公开人数 | `https://lib.buaa.edu.cn/engine2/buaa/...` | 公开页面 | HTML/嵌入数据 |
| 校园通知 | `https://news.buaa.edu.cn/tzgg.htm` | 公开页面 | HTML |
| iclass | `https://iclass.buaa.edu.cn:8346/`、`:8347/app/*` | CAS→loginName→sessionId | JSON |
| UC userinfo | `https://uc.buaa.edu.cn/api/uc/userinfo` | SSO Cookie | JSON |
| 图书目录／本人借阅（部分验证） | `https://space.lib.buaa.edu.cn/meta-local/opac/*`（§6） | 公开目录匿名成功；本人loans登录页成功空，认证完整链待验 | JSON；holdings内嵌JSON字符串 |
| 智慧校车（脚本＋页面） | `https://zhihuixiaoche.buaa.edu.cn/wechat/indexPage`（§6C） | 本人已登录页面观察，资格／匿名待验 | 查询事务形状待补 |
| 阳光打卡（静态） | `https://ygdk.buaa.edu.cn`（§6D）；完整api拼接待验 | 静态身份合并，真实写未验 | 静态JSON／multipart |

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
| 图书馆座位（booking.lib，§5） | `code ∈ {0, 1}` | Int；不得套用于OPAC |
| 图书OPAC（space.lib，§6） | `code === 0` | 数值；部分读取已实测 |
| 智慧校车（§6C） | `success`＋list按业务判断 | 静态消费；本轮列表UI非完整事务样本 |
| 阳光打卡（§6D） | `code == 1`解包，提交后record_id／周期／计数各分支 | 官方静态；真实响应类型／写成功待验，不等于有效考勤 |
| SPOC | `code == 200`，`content` 非空 | Int |

### 镜像实现记录（2026-10-20，§7.1）

✅ 协议依据保持为 §7.1 的 2026-10-18 WebVPN 实测和 `SpocHomeworkClient.swift`：镜像按相同 SPA→CAS→role→term→courses→page/detail 顺序接通真实只读。新增合成详情契约不构成新的上游实测证据；本轮镜像真实账号读取仍 ⚠️ 待本机登录验收。无新增写端点。


### Android 镜像更新源（2026-10-20）

`GET https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases?per_page=100`，Accept `application/vnd.github+json`，User-Agent `Ginkgo-Android-Update`。沿用 Apple UpdateChecker 的公开仓库来源；版本线为项目新增的 `android-v<semver>`，不是学校接口。草稿忽略，正式安装包排除预发布；`*-android-arm64.apk` 非零资产作为可用标志，发布页/资产必须是本项目 HTTPS GitHub URL。新建独立直接 Session，不带学校 Cookie，不使用学校 WebVPN。403/429与其他HTTP/解析失败均不冒充“已是最新版”。最多最近100条发布；尚未覆盖GitHub完整分页或应用内安装。字段依据官方 [Releases REST API](https://docs.github.com/en/rest/releases/releases#list-releases) 与现有 Swift 实现。

### 2026-10-21 镜像补充：研究生分区与数值进度

无上游端点变化。依GraduateAcademicClient/GraduateProgress及既有§7.4，将学籍/报告独立调用和缓存；progress来自fa.ZDXF/yhpyfaxf/dkhxf、类别/课组yqxf/yhxf/dkhxf，完成来自sfwc。缺失与非有限/负数指标不产生进度；不将待考核计入已获。

### 2026-10-21 镜像真实只读复验

Android 上经用户授权，通过实际登录表单及 Rust 会话读取今天、课表与另一周、成绩学期/成绩、三个校区空教室、当天/前一天签到、SPOC 列表/首条详情、博雅目录/已选/统计、研究生学籍/执行报告、图书馆场馆/预约/历史/区域/时段/座位、通知和 CGYY 场馆/当日/订单。均未返回失败码；空结果不构成非空路径验收，未执行任何上游写操作。详细设备、耗时与视觉边界见 [验收记录](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md)。

SPOC 抽样详情的发布时间、截止时间和分值有值，正文与提交时间为空，与 §7.1 的可空字段边界一致，不推广为所有作业均无正文。对 `zynr` 的对象/数组类型漂移现返回结构错误，防止以假空结果覆盖已有完整详情；没有新增端点或修改请求参数。
