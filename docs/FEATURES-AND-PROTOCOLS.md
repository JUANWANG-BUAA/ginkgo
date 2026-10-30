# 功能和接口协议

更新：2026-10-29。本文是 **Android 当前源码的功能入口与本地应用契约索引**，用于长期维护，不是发布公告或验收报告。Android 使用 Flutter + Rust；Windows 复用该栈，Apple 保持独立 SwiftUI。当前公开版本为 Android Beta.2（build 12），包与限制见 [Beta.2 发布与验收记录](_audit/2026-10-29-android-beta2-release.md)，不能由源码覆盖推断真实学校业务已验收。

## 1. 文档职责与事实来源

- **学校上游协议事实以 [API.md](API.md) 为单一来源**：URL、参数、认证、成功码、证据等级及修订记录都在那里维护。本文只链接对应章节，不重新复制端点清单；静态源码线索、合成测试、真实只读和真实写入不是同一种证据。
- 需要具体签名（Rust 端口、FFI 命令、Dart gateway、UI 组件）时查 [接口索引](INTERFACE-INDEX.md)：它给出分层总览、能力总表与模块 IO 契约，逐文件全量清单在 [interfaces/](interfaces/README.md)，由 `scripts/generate-interface-index.py` 从源码生成。
- 本文维护“用户能做什么、从哪里进入、是否写学校系统、哪些数据留在本机”以及 Flutter↔Rust 本地契约；本地 `action`、`state` 和字段名不是学校 HTTP 协议。系统间成功码不得统一，也不得把未知状态解释为成功或空数据。
- 产品方向见 [ANDROID-DEVELOPMENT](ANDROID-DEVELOPMENT.md)，实现状态见 [MIRROR-IMPLEMENTATION](MIRROR-IMPLEMENTATION.md)，平台差距见 [MIRROR-PARITY](MIRROR-PARITY.md)，未完成工作**只维护于 [MIRROR-TODO](MIRROR-TODO.md)**；本文不另建任务表。当前公开发布与升级边界见 [Beta.2 记录](_audit/2026-10-29-android-beta2-release.md)，历史操作规程见 [发包准备](_audit/2026-10-22-android-release-preparation.md)。
- API 中保留了带日期的历史实现记录，可能描述旧版“未接入”；判断当前 Android 是否有入口应核对下列源码，不能把历史只读限制误当现状，也不能反过来因入口存在而提高上游证据等级。

## 2. Android 功能覆盖

手机一级标签为 **工作台、签到、课表、作业、预约**。工作台下方服务目录承载其他入口，常用服务可按账号选择 0–4 项；“预约”聚合图书馆、CGYY 和空教室，不在打开聚合页时同时登录全部系统。宽屏侧栏来自同一[功能登记表](../flutter/lib/workspace/workspace_catalog.dart)。

“只读”按业务副作用分类：认证或查询可能使用 POST，不等于预约/签到写入。“本机写入”不修改学校记录。以下均表示源码链路覆盖，不是当前网络可用性或真实账号验收承诺。

| 模块与 Android 覆盖 | 入口 | 读写边界 / 学校系统 | API.md 对应章节 | 本机数据与关键限制 |
| --- | --- | --- | --- | --- |
| 认证：登录、恢复、退出，自动/直连/WebVPN 路线 | 启动登录页；设置→账号与隐私 | 认证操作；CAS / UC 及各业务会话 | [§1.1 流程](API.md#11-流程总览)、[§1.8 会话验证](API.md#18-会话验证登录成功的唯一判据)、[§0.3 路线约定](API.md#03-通用请求约定) | 自愿记住的密码进入 Android 系统保险库（Keystore）；Cookie/业务 token 属会话状态，直连与 WebVPN 隔离。切路线需要重建登录；显式退出清理本地身份、Cookie、快照和已保存密码后先返回登录页，不等待上游登出或偏好磁盘写入。工作树已接主登录验证码图片/刷新及挑战代次，未知类型拒绝提交；真实风控分支未全验收。 |
| 今天 / 课表 / 考试：正在或下一节、全天课程、周网格/清单、学期/周次/搜索/详情，存在数据时展示考试 | 工作台；课表标签 | 学校只读；本科 BYXT、研究生 GSMIS；工作台复用作业和本机待办 | [§2.1 本科身份](API.md#21-门户探测与身份判定)、[§2.4 周课表](API.md#24-周课表核心)、[§2.6 考试](API.md#26-考试安排)、[§3.3 研究生课表](API.md#33-课表数据核心) | 查询快照与当前筛选；手机默认当日清单和星期切换，宽屏保留周网格，搜索覆盖全周。课程和作业分区独立加载，刷新失败保留旧结果；回到工作台更新本机待办。近期时间线已删除，考试仅在有未早于学校今天的记录时显示独立卡片，加载、失败和成功为空均不占位。不为研究生伪造考试安排。 |
| 成绩：学期、原始成绩、均分/GPA | 工作台→成绩（或常用入口） | 学校只读；buaascore | [§4.2 查询](API.md#42-成绩查询post)、[§4.3 结构](API.md#43-响应结构) | 进程查询快照；失败保留旧结果。空成绩不证明非空成绩和汇总已核对，不把本地汇总当学校学业结论。 |
| 学校作业：SPOC 列表/详情、教师与身份上下文、近期截止；已提交不显示倒计时 | 作业标签；工作台近期作业直达 | 学校读取 + 用户确认文件写入（工作树）；SPOC | [§7.1 作业来源与只读详情](API.md#71-bbaa-原版作业实现对照2026-10-15) | 查询快照；按账号/系统保存课程隐藏选择，学生优先，已确认助教课程默认收起并排除个人待完成统计，未知归属不擅自排除。`rolesComplete=false` 明确显示作业结果不完整，不冒充确认空。日期仅与精确时间共用今天、24 小时紧迫和逾期展示规则，日期仅边界不用于提醒排程。希冀未迁移。工作树新增附件下载、提交限制/已提交内容读取；普通构建已开放个人文件上传/确认提交入口；先配置私有提交保护记录，未知只回查，真实写入未验收；小组及非文件作答不支持。见 [集成记录](_audit/2026-10-25-spoc-homework-integration.md)。正文/截止/提交时间可缺失，不补造。 |
| SPOC 学习：学生课程、公告/详情、根目录资料与测验只读列表（工作树） | 工作台可选常用入口→SPOC 学习；宽屏学业侧栏 | 学校只读；SPOC，不标读、不记录课程访问、不开始/提交测验 | [§7.1.4 学习只读扩展](API.md#714-spoc-课程学习只读扩展2026-10-26静态证据与实测分开) | 四个独立 gateway，native/demo 业务类型一致；资料/公告/测验分页显示，首次切页才读取对应分区，失败及旧快照分别保留，无个人分数字段时显示未知。UI 已接目录/面包屑/分页、显式栏目选择及主动文件保存/打开；Rust 逐层复核当前课程目录路径，未知层级拒绝。可选 Android 加密学习元数据快照默认关闭；本会话能力证据可由课程页信息按钮查看。静态取证、实测与构建分别记于 [本轮记录](_audit/2026-10-26-spoc-learning-integration.md)，未发布。 |
| 个人待办：增删改、完成、无截止/日期/精确北京时间、兼容历史来源记录 | 工作台个人待办；服务目录→待办 | 仅主动本机写；无学校待办服务 | 无独立上游协议；作业来源见 [§7.1](API.md#71-bbaa-原版作业实现对照2026-10-15) | 按账号保存 `tasks-<SHA-1(account)>.json`；v1 只读，发生有效修改时原子替换为 v2，损坏拒绝覆盖。当前已移除作业详情转待办入口，首页不重复预览历史学校来源条目，但保留已有数据与待办页访问；学校刷新不改写/删除个人待办。完成不等于学校提交；不提供跨设备同步或完整待办提醒。 |
| 课程签到：当天/历史、重复冲突合并、阶段反馈、前台只读刷新、单课提醒 | 签到标签 | 学校只读 + 用户逐课确认后单次签到；iClass | [§7.2 签到状态与手动提交](API.md#72-iclass-签到状态与手动提交写协议尚待真实验收) | 日期隔离快照；课程隐藏偏好与提醒已读摘要按账号保存。前台约两分钟只读刷新，课前十分钟门禁不等于自动签到。结果须回查，未知不重发；不套用 SPOC 课程身份，真实写入及后台覆盖未验收。 |
| 图书馆：馆→区→时段→座位、当前/历史预约、公开人数；预约及入座状态管理 | 预约→图书馆座位 | 学校只读 + 用户确认后单次预约/签到/返回入座/暂离/离馆/类型匹配取消；booking.lib 与图书馆公开网站 | [§5.2 查询与预约](API.md#52-业务端点全部-post-json)、[§5.3 加密](API.md#53-预约请求加密aes-cbc)、[§5.5 人数](API.md#55-官网实时空间数据公开只读)、[§5.6 状态操作](API.md#56-当前预约与座位状态操作前端静态取证写入未验收) | 分区/按页进程快照，历史每页 40 条；公共人数 Cookie 隔离，镜像未迁移 Apple 的 60 天趋势。动作依明确资格提示、确认、单次提交和回查；真实写入未验收。本人借阅为下述独立只读模块，不复用选座 token；教学楼 CGYY 不是图书馆研讨室。 |
| 本人借阅（工作树，待真实验收） | 服务目录→本人借阅；宽屏空间资源侧栏 | 用户主动只读；OPAC 私人 Cookie 会话 | [§6.2 本人借阅](API.md#62-本人借阅与隐私) | 独立 gateway，按需查询、逐页读取，失败与确认空分别呈现；离开栏目/后台/换账号清除页面记录，不持久化、不提醒、不续借。认证入口为公开配置与静态证据，App 实际认证、非空字段与多页仍待验收。见 [记录](_audit/2026-10-26-library-loans-integration.md)。 |
| 公开查书与馆藏：关键词、相关度/出版年/题名排序及升降序、按需查看复本 | 图书馆→查书目与馆藏 | 匿名公开只读；OPAC，与预约会话隔离 | [§6 目录与馆藏](API.md#6-图书目录馆藏与本人借阅2026-10-23-部分只读验证) | 只消费领域投影；馆藏原文状态，不将计划馆藏或未知状态伪造成可借；不含本人借阅、续借、预约。 |
| 校园卡余额（工作树，待真实验收） | 服务目录→校园卡；宽屏校园侧栏 | 用户主动只读；航财通与北航统一认证 | [§6E 校园卡余额](API.md#6e-校园卡余额官方前端与脱敏结构真实-app-验收中) | 独立 `CampusCardGateway`，点击才读取；金额默认遮挡，失败仅在本页保留旧值；离页/后台/换账号清除，不持久化、不轮询；不含银行卡、消费明细、充值或挂失。真实回跳与金额一致性未验收。 |
| 就业活动（工作树，待设备验收） | 全部服务→就业活动；宽屏校园侧栏 | 匿名公开只读；学校就业网，不接报名 | [§6G 就业活动月历](API.md#6g-就业活动公开月历工作树只读) | 按月读取宣讲会与双选会，显示校区、地点、时间、类型、状态原文和同步时间；5 分钟进程缓存，失败保留旧快照，不推断 `status` 语义；公开请求不携带账号 Cookie。 |
| 学术文化（工作树，待设备验收） | 全部服务→学术文化；宽屏校园侧栏 | 匿名公开只读；学校官网，详情交外部浏览器 | [§6F 学术文化](API.md#6f-学术文化公开列表工作树只读) | 分别显示发布日期和活动时间、地点与官方详情；按当次总页数读取倒序分页，失败保留旧快照，不做全站镜像。 |
| 校车时刻表：分方向班次、计划可乘人数、官方页面入口 | 服务目录→校车时刻表 | 公开只读；学校公开页面 | [§6C 校车](API.md#6c-智慧校车脚本静态本人查询页面观察未购票) | 不代理购票、不显示实时余票，临时调整以官方为准；源码接入不等于已公开新包。 |
| CGYY：校区/场馆/容量、日期空档、订单详情、门锁密码、审批与保守取消资格、手动拼图预约/取消、显式核对解锁 | 预约→研讨室；我的预约/门锁密码/预约表单分入口 | 学校只读 + 用户主动写；教学楼 CGYY，固定直连 | [§6B 协议与客户端保护](API.md#6b-教学楼研讨室cgyy前端ubaa-协议移植真实写操作未验收) | 查询快照、内存挑战/核对凭据与持久最小 pending 标记，详见下文。门锁码无快照、仅手动刷新；用途读取失败可用 UBAA 内置列表。后台读成功不能解除保护；最近 20 条不是完整历史，空列表不证明未落单；真实预约/取消和门锁码仍未验收。 |
| 空教室：校区/日期/节次、楼栋与搜索、分页展示 | 预约→空教室 | 学校只读；校园应用空教室系统 | [§6A 空教室](API.md#6a-空教室源码已核对真机待验收) | 查询快照；本机每页 50 条不代表上游分页。失败和无空教室分开；空闲查询不占用教室、不保证现场可用。 |
| 校园通知：列表、摘要、原文链接 | 工作台→校园通知 | 公开只读；学校新闻网 | [§7.3 只读盘点](API.md#73-2026-10-18-教育系统只读数据盘点)、[附录 A 通知来源](API.md#附录-a已验证-url-总表) | 进程快照；原文交外部浏览器。校园通知列表不同于下述 Android 本地提醒；未接入学校通知推送。 |
| 博雅：课程目录、已选、统计、详情与类别完成进度 | 工作台→博雅 | 学校只读；BYKC | [§7.3 教育数据索引](API.md#73-2026-10-18-教育系统只读数据盘点)（详细字段由该节指向 EDUCATION-DATA-MAP） | 三部分独立快照与懒加载；目录可读不证明非空已选已核对，未接入选课、退课或博雅签到。 |
| 研究生教务：学籍、执行报告，要求/已获/待考核/缺口、类别/课组与课程筛选详情 | 工作台→研究生教务（学分地图同页，无重复入口） | 学校只读；GSMIS | [§7.4 执行报告](API.md#74-培养方案执行报告结构化类别课组)、[§3.3 排课](API.md#33-课表数据核心) | 学籍和报告独立快照/独立失败；严格执行报告学分地图嵌入同一教务页，旧 ID 仅作兼容别名。未知不补零、分层不累加，待考核不计已获；成绩/考试组合尚未齐，不代替教务认定。 |
| 设置 / 提醒 / 更新：显示阅读、7 组强调色、减少动态效果、账号隐私、通知后台说明、诊断、更新下载 | 工作台页头设置；服务目录→设置 | 本机配置；更新访问 GitHub Releases/门禁清单，非学校系统；不自动预约或签到 | [Android 更新源](API.md#android-镜像更新源2026-10-20)、认证路线见 [§0.3](API.md#03-通用请求约定) | 保存外观、常用入口、提醒开关与已读摘要；Android 作业截止前 48/24 小时及单课提醒为非精确本地通知，依权限和系统调度，不承诺后台常驻/准点。更新支持暂停/续传及哈希/包名/版本/证书校验，安装交系统确认；启动新版轻提示不自动下载，最低版本门禁读取失败放行。不含远程业务代码热更新。 |

### 本机数据的共同边界

- Rust 镜像查询使用[进程内快照](../rust/crates/ginkgo_upstream/src/services/cache.rs)，通用 TTL 为 300 秒、每个缓存最多 32 个键；刷新失败可带旧值与错误，不延长原成功时间。不要将 Apple 的磁盘缓存/保留天数直接套用于 Android，也不要把它当跨重启离线数据库。
- [个人待办存储](../rust/crates/ginkgo_core/src/tasks_store.rs)、[课程范围](../flutter/lib/shared/course_visibility.dart)、[提醒已读/开关](../flutter/lib/shared/reminders.dart)、[常用入口](../flutter/lib/workspace/workspace_shortcut_preferences.dart)是独立本机数据。账号摘要只用于隔离命名，**不是加密**；不能将个人数据或 CGYY 保护标记当普通查询缓存随意清除。
- 不落盘真实密码明文、学校 Cookie/token、验证码密钥或原始学校响应。错误、旧缓存、已确认空结果、部分成功分开显示；有缓存不代表权限或会话仍有效。

## 3. 本地应用接口分层

[contracts.dart](../flutter/lib/application/contracts.dart)只导出 DTO；[application/mirror_service.dart](../flutter/lib/application/mirror_service.dart)定义 Session / Academic / CheckIn / LibrarySeating / LibraryCatalog / Shuttle / Bykc / Graduate / Notice / Cgyy / LocalTask 等独立 gateway；[learning.dart](../flutter/lib/application/learning.dart) 独立定义课程/公告/资料/测验只读能力，`LearningRead<T>` 携带旧快照与失败元数据。页面只消费本地投影，不解析学校原始响应或读取 token。[NativeMirrorService](../flutter/lib/infrastructure/native_mirror_service.dart)负责 FRB 调用，Rust core 编排、upstream 适配学校协议。

CGYY 写能力单列为 `CgyyBookingGateway.executeCgyy(Map<String, Object?>)`，不因具备 `CgyyGateway.cgyy(...)` 的只读能力就自动获得写权限。只读接口的 `kind` 为 `venues` / `day` / `orders` / `order` / `lockCode`，与下列命令的 `action` 不混用；`order` 的 `siteId` 传订单 ID，订单详情和门锁码不走查询快照。

R-19 迁移后桥接全部返回类型化 DTO：只读命令返回 `CgyyLoadResponse`（五个 `kind` 各占一个可空形状字段，互斥），写命令返回 `CgyyActionResultResponse`。**返回类型不代表调用没有副作用**；`executeCgyy` 同样可能写学校系统。学校响应到 DTO 的净化投影在 Rust 端完成，Dart `infrastructure/cgyy_decode.dart` 只做 DTO → 呈现模型投影；错误通过 DTO 的 `failure` 字段表达，不能只按 `state` 处理错误。参见 [bridge DTO](../rust/crates/ginkgo_flutter_bridge/src/api/live.rs)、[命令入口](../rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs)与[Dart 解码](../flutter/lib/infrastructure/cgyy_decode.dart)。

## 4. CGYY 本地 JSON 契约

以下为当前源码契约，不是另起一套学校端点。依据为领域 [cgyy_booking.rs](../rust/crates/ginkgo_domain/src/features/cgyy_booking.rs)、[cgyy.rs](../rust/crates/ginkgo_domain/src/features/cgyy.rs)、core [命令编排](../rust/crates/ginkgo_core/src/application/cgyy.rs)、upstream [写流程](../rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs)。

### 4.1 信封与账号绑定

每次传入一个 JSON 对象。`action` 为下表字符串；动作参数保持 **snake_case**。Rust 的 `rename_all = "camelCase"` 作用于枚举动作名，不会把 `challenge_id` 等字段变成 camelCase。

```json
{
  "action": "status",
  "storage_root": "/absolute/application-support",
  "expected_account": "sy2501001"
}
```

上例账号与目录均为合成占位，调用端不能照抄路径。

- `storage_root`：正常 Android gateway 每次注入 `getApplicationSupportDirectory().path`。core 仅对 `options` / `review` 允许省略；其他动作，**包括 `status` 与 `acknowledge`**，必须提供绝对路径。字段存在时必须为非空字符串；不存在与 `null` 不等价。
- `expected_account`：正常 gateway 必须绑定非空发起账号并注入每次调用；core 兼容入口可省略，但存在时须为非空字符串。它只是前置条件，**真实归属始终由 Rust 已认证会话派生**，不能用调用者账号指定存储归属。绑定不匹配在文件/端口操作前返回会话失效；业务过程中另复核账号与身份代次，拒绝旧页面迟到回调作用于新账号。
- FFI 对整次命令持全局写门禁，service 另做 single-flight；文件同步锁不跨 `await`。直接并发调用 core 的消费者也需要自己的整流程串行门禁，不能认为 marker 已提供跨进程事务。

### 4.2 动作与参数

下表参数均在信封顶层，唯 `prepare.booking` 为嵌套对象。正常 gateway 仍统一附带上述两个信封字段。

| `action` | 业务参数 | 本地结果与副作用 |
| --- | --- | --- |
| `status` | 无 | `ready` / `uncertain`；查询本机/内存保护状态，不发送学校预约。磁盘标记存在或损坏时优先返回 `uncertain`，不因状态端口失败而忽略磁盘保护。 |
| `options` | `site_id: i64`、`date: string` | `options` + 可选项；读当日空档和用途，即使保护中也可读取，不清 marker。 |
| `prepare` | `booking: BookingRequest`（见下） | 复核空档后创建学校草稿并取人工拼图，返回 `challenge`；**不是纯只读预览**。core 先持久写 marker，再调用业务端口；已有标记时不新开流程。 |
| `submit` | `challenge_id: string`、`x: i32` | 消费一次性挑战，人工验证后再复核空档，单次提交并回查；可能 `accepted` / `rejected` / `notSubmitted` / `uncertain` 或桥接失败。 |
| `cancel` | `order_id: i64` | 强读订单与资格后单次取消并回查；可能 `accepted` / `notSubmitted` / `uncertain` 或失败。core 在派发业务端口前先建 marker；保护中不继续写。 |
| `review` | 无 | 绕过快照强读最近 20 条，返回 `reviewRequired` 与 `review`；只生成一次性核对凭据，不解除保护。 |
| `acknowledge` | `review_id: string` | 用户展示核对并明确确认后解除本机保护；外部最终返回 `ready`。本文简称 ack，但**实际 action 不是 `ack`**；它不发送学校预约/取消，也不重发上次请求。 |

`BookingRequest` 所有字段均必填，没有省略默认值：

| 字段 | JSON 类型 / 当前约束 |
| --- | --- |
| `site_id`、`space_id`、`purpose_type` | 整数（Rust `i64`），均大于 0；来源为当前可选项，不自造 ID。 |
| `date` | 字符串，`yyyy-MM-dd`，须为合法日期。 |
| `time_ids` | 整数数组，1–12 个正整数、不能重复；同一空间的已确认可用时段，实际空档仍由 Rust 重读复核。 |
| `phone` | 字符串，11 位 ASCII 数字；不能按 JSON 数字传递。 |
| `joiner_num` | 整数，1–100；这是本地格式门禁，不表示场地容量或学校保证接纳。 |
| `theme`、`activity_content`、`joiners` | 字符串，去空白后非空，各自 UTF-8 字节长度不超过 8000。 |
| `philosophy`、`off_school` | JSON 布尔值；不传字符串 `"0"` / `"1"`。 |

### 4.3 结果字段与状态语义

命令 `payload` 解码为 `CgyyActionResult`：必有 `state: string`、`message: string`；`options`、`challenge`、`review` 无值时**省略**，不输出 `null`。

- `options = { choices: [{ space_id, space_name, time_id, time }], purposes: [{ id, name }] }`。ID 为整数，名称/时间为字符串。
- `challenge = { id, background, jigsaw }`：三个字符串，图像为 Base64；`id` 是本地随机不透明 ID。学校 token、预约 token、验证码 token/密钥和选择串留在 Rust 内存，不跨 FFI、不进入 marker。
- `review = { id, orders }`：`id` 是本地随机核对凭据；订单项必有 `id: i64`、`place/date/time/status: string`、`can_cancel: bool`，`order_status` / `check_status` 为可选整数，缺失时省略。审批码和资格属 live 投影；共享解析 v1 的历史五字段契约（`id/place/date/time/status`）不因此扩写。

| `state` | 必须保留的含义 |
| --- | --- |
| `ready` | 本机保护已就绪，不保证所选空档仍空闲，也不是学校预约成功。 |
| `options` / `challenge` | 已取得选择项 / 人工验证挑战，不代表预约已成立。 |
| `accepted` | 预约已查回相同订单 ID，或取消已查回目标订单取消状态；预约仍须查看审批，不能称“审批通过”。 |
| `rejected` | 当前写流程仅在明确拼图 `success=false` 时表示未提交预约；不能把通用 `BusinessRejected` 错误都转为该状态解锁。 |
| `notSubmitted` | 空档变化未提交，或取消资格不满足而未发取消请求。core 还兼容清理 `not_submitted`，但当前 service 输出为 `notSubmitted`。 |
| `uncertain` | 结果待核实；暂停新写入，仅回查，不自动重试。网络/认证/未知业务码/结构错误都不能证明未生效。 |
| `reviewRequired` | 本次强读已完成，等待用户在核对页展示并确认；不是已解锁。 |
| `reviewed` | service 内部确认成功状态；core 清 marker 后将其转换为对外 `ready`，不作为正常 UI 最终返回值。 |

未知 `state` 或桥接失败必须保守处理，不推断成功/可重试，不自行删除 marker。

### 4.4 TTL、持久保护与回查

1. **挑战一次性且仅在内存**：`submit` 在任何异步请求前取走挑战上下文。ID 必须相同，年龄超过 120 秒即拒绝（源码条件 `elapsed > 120s`），`x` 必须在 0–310；账号/身份代次必须仍匹配。失败或重复回调不能复用该挑战，重启后不能恢复挑战。此 TTL 是本地门禁，不承诺学校验证码寿命。
2. **核对凭据一次性、严格小于 120 秒**：每次 `review` 先废弃旧凭据，强读成功才签发新 ID，绑定账号与身份代次；`acknowledge` 要求 `elapsed < 120s` 且 ID 相同，成功即消费。页面拒绝 stale/失败/无 payload 的核对结果；必须展示本次订单、用户勾选并二次确认。普通订单读取、后台读取或缓存回退均不能替代此流程。
3. **最小 marker 无自动过期时间**：[PendingStore](../rust/crates/ginkgo_core/src/cgyy_pending_store.rs)文件为 `storage_root/cgyy-pending-<SHA-1(account 原始字节的小写十六进制)>.json`，内容严格只有 `版本 + 布尔值`：

   ```json
   {"version":1,"pending":true}
   ```

   不保存账号明文、订单 ID、日期、手机号、表单、图片或任何 token。采用新建排他、flush/sync；Unix 创建权限 `0600`。账号摘要不等于加密。读取限普通文件且不超过 256 字节、拒绝未知字段；格式错误、不可读、非普通文件都视为锁定，不能覆盖或绕过写入。
4. `prepare` / `cancel` 在业务端口前创建 marker；`submit` 可沿用合法现存标记，但损坏标记阻止提交，且仍需有效内存挑战。`challenge`、`uncertain`、错误或未知状态均保留 marker，退出/重新登录/重启不能自动消除。core 只在明确终态 `accepted` / `rejected` / `notSubmitted`（兼容 `not_submitted`）后清理，或校验 `acknowledge` 成功后清理；清理失败不能报告已就绪。有效核对确认也可尝试清理损坏的普通 marker，不能在校验前删除。
5. `review` 仅覆盖最近 20 条，尚无完整历史分页/门锁码；找不到目标须到学校页面核实，**空列表不是未提交证明**。确认仅解除本机保护，不改变学校订单，也不自动补交。
6. 取消前重新核对目标：已知 `order_status` 为 1 或 3、`check_status` 在 0–6、开始时间可解析且当前时间严格早于开始前 4 小时，才继续发送；未知值保守禁用。UI 的 `can_cancel` 只是提示，最终以 Rust 强读资格与提交后回查为准。

## 5. 维护方法

功能变化时同步更新本页的入口、读写边界、本机数据与限制，并核对 gateway、domain DTO、core 编排及 UI 消费者；不把未来计划写成现有功能。上游事实变化仍先在 API.md 补证据与修订，再更新本页链接；涉及写操作继续保持用户确认、单次发送、结果回查与未知结果保护。

本文仅据本机仓库源码整理，未访问学校网络、未发送真实写请求、未做真实账号验收，发布事实单列于版本发布记录。源码/合成验证与设备/真实业务证据分别查阅现有实施与审计记录，不在这里复制验收结论。
