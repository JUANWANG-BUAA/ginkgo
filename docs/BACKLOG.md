# BUAA Assistant - 候选功能储备清单（BACKLOG）

> **产出背景（2026-10-13 侦察）**：(1) 对 BBAA 仓库做了全量端点盘点——16 个上游主机、14+ 个系统**全部存在直连本地实现**（`shared/.../api/local/` 下 20 个文件），即协议均已逆向完毕；(2) 对公开页面做了轻量无认证实测（见文末记录）。
> **使用规则**：这里的每一项在进入 ROADMAP 正式步骤前，必须先把对应协议写入 API.md（✅/⚠️ 分级）并通过审查。分级依据 = 协议证据强度 × 移植成本 × 操作风险。

## 当前跟进状态（2026-10-16）

空教室已按源码接入，协议见 API.md §6A，真实查询待验收；图书馆座位预约已简化为当前时段并加入本机座位历史估算，真实预约→列表→取消闭环待验收。图书馆官网公开页已发现两个校区实时在馆人数及沙河特色阅览室人数，接入本机按小时采样、历史趋势和同星期/时段均值估算；逐楼层人数分布仍未公开发现。预约端空位/总座位不能替代在馆人数；研讨室 boutique 分类仍待真实请求证据。本地待办已实现。登录时自动启动与课前提醒已接入；登录项状态、通知投递与点击仍待人工验收。Judge 与 SPOC 两个只读 provider 已接入，真实账号逐来源验收未完成。iclass 状态、手动签到和按日历史查询已接入；历史目前由用户逐日选择查询，没有整学期汇总端点。状态查询具备 WebVPN 路径，原生直连认证链仍待验收；课程状态刷新现避免并发，重复课程 ID 会合并，矛盾记录标为待确认。真实签到提交仍需逐项确认并完成人工往返验收；SPOC 上传需正常网页提交的脱敏 HAR 取证。AppIcon 已绑定资源集，运行后 Dock/Finder 显示仍待人工确认。

## A 级：低成本高价值（协议现成、以只读为主）

| # | 功能 | 上游 | 协议依据 | 价值与说明 | 建议 |
|---|------|------|----------|------------|------|
| 1 | 考试安排 | byxt `student/exams.do` | 客户端与本科入口已接入；真实本科账号验收待做 | 考场/座位号/时间，研究生 403 需按身份隐藏 | 与 Step 3 同 host 同会话；mock 覆盖已补 |
| 2 | 图书馆研讨室 | booking.lib v4（待确认 `space/pick` 分区参数） | BBAA `LocalLibBookApi.getAreas()` 虽发送 `boutiqueIds`，但始终为空；当前未找到非空 ID 或分区映射 | 不能据字段名断定研讨室就是同链路可查分区；需本人正常图书馆 UI/脱敏 HAR 观察真实筛选参数与返回类别后再实现 | 暂缓取证；不得硬编码猜测 ID |
| 3 | 空闲教室 | app.buaa.edu.cn `buaafreeclass/wap/default/search1` | `LocalClassroomApi.kt:38`（另需先 GET `site/classRoomQuery/index` 同步会话） | JSON 响应（楼/层/空闲节次），自习找教室刚需 | Step 5 后 |
| 4 | 希冀作业列表（已接入，待验收） | judge.buaa.edu.cn | BBAA `LocalJudgeApi.kt` 直连实现；本项目 API.md §7.1 | SSO Cookie + HTML 课程/作业/详情解析；课程列表、截止时间及提交状态需真实账号对照 | 当前验收项 |
| 5 | iHome 诉求浏览 | i.buaa.edu.cn | **取证文档最全**：`BBAA/docs/_audit/2026-09-17-ihome-live-api.md` + `IhomeUpstreamClient.kt`（12 步 CAS→JWT 链已实现） | 只读浏览诉求/官方回复/公告；关注/支持是写操作（上游为切换语义，重发会反向操作） | 弹性 |

## B 级：中等成本（有加密或独立登录，但实现可移植）

| # | 功能 | 上游 | 协议依据 | 难点 | 建议 |
|---|------|------|----------|------|------|
| 6 | SPOC 作业（已接入，待验收） | spoc.buaa.edu.cn | BBAA `LocalSpocApi.kt` + `LocalSpocSupport.kt`；本项目 API.md §7.1 | CAS token、RoleCode、AES-CBC 加密分页请求；固定向量测试、分页边界与真实账号结果仍待核对 | 与 Judge 一起完成真实账号验收 |
| 7 | 阳光打卡记录（只读） | ygdk.buaa.edu.cn | `LocalYgdkApi.kt` 仅为参考线索；本项目尚无取证章节 | 先确认 OAuth 授权链、只读字段和状态刷新时效；通知按状态变化去重 | iclass 只读完成后 |
| 8 | iclass 课程签到（状态查询与手动提交已接入，写协议待验收） | iclass.buaa.edu.cn:**8346/8347** | API.md §7.2：状态查询有真实只读观察；提交流程按 BBAA 源码移植，未对真实上游写入 | 独立入口、逐课程确认；提交后回查，只有已签到状态才报成功；结果不确定时不自动重发 | 需人工真实账号往返验收和通知体验验收 |
| 9 | 课程评价（评教） | spoc.buaa.edu.cn/pjxt | `LocalEvaluationService.kt` | 复用 SPOC 会话；提交评价是写操作 | 季节性功能，只做进度提醒可降级为只读 |
| 10 | 北航网盘 bhpan | bhpan.buaa.edu.cn `/api/efast/v1/file/*` | `buildSrc/.../UploadLatestReleaseToBhpanTask.kt:346-530` | 上传链路（beginupload/multipart/complete）已知；**浏览/下载/分享未逆向**，且网盘写操作风险高 | 浏览器端 HAR 侦察后再评估 |
| 13 | SPOC 作业提交/附件上传 | spoc.buaa.edu.cn | BBAA `SpocApiBackend` 仅定义列表/详情；官网静态 bundle 有 `submitKcz2`、`queryFjList` 包装定义，但两者均未导出且模块内未发现调用；另有通用编辑器上传 handler（详见 API.md §7.1） | 实际作业详情调用链仍未发现；字段、附件 ID 绑定、权限、响应成功语义及权威回查均未知。不能将未见调用的路由包装或通用编辑器上传端点等同于作业附件上传 | 先由本人正常网页提交一次并提供脱敏 HAR，或提供可关联的前端调用证据；在此之前只做详情读取、不发写请求 |

## C 级：高成本或不建议

| # | 功能 | 上游 | 障碍 | 结论 |
|---|------|------|------|------|
| 11 | 博雅课程 bykc | bykc.buaa.edu.cn | RSA-1024 + AES-ECB 混合加密（`LocalBykcCrypto.kt` 含手写 SHA-1）；选课是高冲突写操作 | 技术上可移植（Security framework），但复杂度高；若做，只做**学分统计只读** |
| 12 | 操场预约 cgyy | cgyy.buaa.edu.cn | MD5 请求签名 + **滑块验证码**（`LocalCgyyCaptchaSupport.kt`） | **滑块验证码是上游明确的反自动化措施，自动绕过接近对抗风控的红线（COLLABORATION §8）——不做**；只读看时段可议 |

## D 级：UBAA 未覆盖，需用户自行侦察

按 COLLABORATION §2.2 逆向取证流执行（人开浏览器 + 本人账号 + 正常使用 + 导出 HAR）：

| 候选 | 现状 | 侦察入口 |
|------|------|----------|
| 图书馆借阅/续借 | `opac/api.php` 已证伪（见下），lib 首页为 JS 渲染 SPA 壳，真实 OPAC 入口需浏览器发现 | 登录图书馆官网 → 我的借阅 → 抓 HAR |
| 一卡通余额/消费 | UBAA 无实现，系统存在性未确认 | 校园卡充值页面/一卡通 App 分享的链接 |
| 校车时刻 / 讲座活动 / 电费网费 | 存在性未确认 | 逐个收集候选 URL，先可达性筛选再 HAR |

> D 级条目在验证前**不要**写任何实现代码，也不要把猜测写进 API.md 的 ✅ 章节。

## 侦察实测记录（2026-10-13，全部为无认证普通 GET）

1. **SSO 登录页**（7195B）：`execution` 隐藏字段存在，值为 **JWT 三段结构**且含 `+`/`/` 字符（表单提交必须正确 percent-encode）；默认页**无** `config.captcha`（验证码仅风控触发，印证 API.md §1.3）；表单 input 共 6 个：`username/password/submit/type/execution/_eventId`，**无 `rememberMe`**（旧版文档硬编码该字段无依据）。CasPageParser 三条正则与实测页面匹配。
2. **lib.buaa.edu.cn**：根路径 200（标题确认官网）；`/opac/`、`/opac/api.php`、`/opac/user/loans` 全部 404——**旧猜测证伪**；首页为 2.5KB 的 JS 渲染 SPA 壳，无法从静态 HTML 发现目录系统入口。
3. **六域名可达性**（sso/uc/byxt/gsmis/app/booking.lib）：全部 HTTPS 可达（见 ROADMAP「网络环境前提」）。

## 维护约定

- 每项进入实施时：先在 API.md 建对应章节（✅ 需附 BBAA 文件:行号或 _audit 取证编号），再从本表移入 ROADMAP；
- 写操作类功能（签到/选课/预约/打卡提交）接入前必须过 COLLABORATION §3 红线 5（不自动重试）与 §4 安全审查。

| 日期 | 变更 |
|------|------|
| 2026-10-13 | 初版：14+ 系统盘点 + 3 项实测 |
