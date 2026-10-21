# Flutter 与 Ginkgo macOS 功能、信息和交互核对

当前对照更新：2026-10-21。范围为工作树中的 Rust / Flutter 与仓库内 Swift 源码；下方带日期的追加记录保留各次历史结果，不代表公开 Android Alpha.1 已包含后续改动。UBAA 协议交叉证据见 [体验设计](MIRROR-EXPERIENCE-DESIGN.md)。

本轮已完成博雅三分段、研究生分层、作业与课程懒列表、短时间标签、信息层级和桌面独立导航栈改造；Windows 已有独立 CI 验收入口，尚无 Windows 主机通过结果。实现不等于真实验收；最终自动检查、第二轮真实只读与视觉 / 延迟结果见 [本轮验收](MIRROR-ACCEPTANCE-2026-10-21.md)，博雅协议与缓存见 [本轮对齐记录](MIRROR-PARITY-2026-10-21.md)。

## 已对齐和仍有差距

| 模块 | macOS 源码证据（BUAA-Assistant/Features/ 下） | Flutter 当前 | 明确未迁移或未验收 |
|---|---|---|---|
| 课表 | Schedule/ScheduleView.swift、TimetableGrid.swift、TimetableLayout.swift、CoursePalette.swift | 周网格默认；每日清单/学期/有数据时考试；学期切换、日期、今天列、节次/时间/地点/教师详情；稳定多色、冲突分栏、搜索；研究生条目时间方案已修正 | 课程提醒未迁移；真实时间仅核验字段完整，未逐门与教务人工比对；窄屏网格横滑，大字号改清单 |
| 作业 | Homework/HomeworkView.swift、SpocHomeworkClient.swift | SPOC 列表 / 详情与教师上下文；标题 / 课程 / 教师搜索、状态与截止筛选；懒列表；标题、截止、状态、课程与教师分层；详情先展示截止和说明，复制菜单适配 Cupertino | 本轮真实字段与交互见验收；希冀、附件下载、作答与提交未迁移 |
| 课程签到 | CheckIn/CheckInSummaryView.swift、CheckInClient.swift | 当天与历史、计数、时间 / 地点、合并冲突与核对时间；确认后单次提交及回查；时间与状态重新分层 | 非空真实历史、自动轮询 / 提醒未验收或未迁移；本轮不提交真实签到 |
| 图书馆 | Library/LibraryView.swift、LibraryPublicStats.swift、LibraryOccupancyHistory.swift | 馆→区→时段→座位、当前 / 历史预约、公共人数；场馆与当前预约独立更新 / 重试；搜索、空闲筛选；预约与生命周期确认、单次提交及回查 | 真实多页历史、60 天趋势仍有缺口；本轮不提交真实预约 / 取消 / 生命周期操作 |
| 博雅 | BYKC/BykcView.swift、BykcClient.swift、BykcSemesterPolicy.swift | 课程库 / 已选 / 统计独立查询、缓存和按需加载；目录 / 已选懒列表、搜索 / 类别；详情展示时间 / 地点 / 教师、选课记录；统计按类别紧凑分组，超额与零要求有明确语义 | 本轮真实字段对照见验收；选退课与博雅签到未迁移 |
| 研究生教务 | Graduate/GraduateAcademicView.swift、GraduateProgress.swift | 学籍 / 执行报告独立读取与快照；概览 / 要求 / 课程分层，已认定 / 待考核 / 缺口区分；课程搜索、状态筛选与详情；待考核不抵扣缺口 | 完整 macOS 学分地图、课程原文和成绩考试组合仍未完整对齐 |
| 成绩 | Grade/GradeView.swift、GradeClient.swift | 学期、原始成绩、均分 / GPA 与明细分层，刷新失败保留旧结果 | 真实非空成绩与汇总待对照；Windows 未验收 |
| 空教室 | Classroom/ClassroomView.swift、ClassroomClient.swift | 校区/日期/空闲节次、缓存与错误区分 | 当前轮不重跑已知不收敛的校区/日期/缓存长流程 |
| 本地待办 | Tasks/TasksView.swift:26,85 | 本地增删改、完成状态和账号隔离 | macOS 精确截止时刻及提醒行为尚未逐项对齐；本地测试不代表通知验收 |
| 校园通知 | Campus/CampusNoticesSummaryView.swift、CampusNoticesClient.swift | 列表、摘要与原文链接，真实响应通过 | 原站网页展示由浏览器负责，未宣称复制网页全文 |
| CGYY | Venue/CgyyView.swift、CgyyClient.swift | 场馆 / 校区 / 容量、查询日期、时段状态与原始订单状态分层；只读查询 | 写操作、门锁码未迁移；未人工遍历每场馆日期 |
| 导航 / 设置 / 账户 | Settings/、Auth/；Core/Network/UpstreamRoute.swift | 手机独立 Tab 栈、齿轮与首屏账户行；桌面固定设置、各目的地独立导航且首次访问才构建；路线 / 缓存 / 保险库 / 自检 / 更新 | 验证码图片、通知 / 提醒、外观偏好与自动启动仍有差距；键盘 / 读屏未全量验收 |
| Windows | 原生 macOS 桌面布局作为参照 | 工程、构建流水线与独立 `windows_test.dart`；设计覆盖保险库合成往返、侧栏与详情栈保留 | 尚无本轮 Windows 主机执行结果，无公开安装包 |

路径用于定位可核查实现，不把字段相似视为协议已经一致。当前真实账号是研究生门户，不代表本科门户已做真实账号验收。

## Dart 原生风格实现与交互

- iOS 路径：CupertinoTabScaffold + 每个 Tab 独立 CupertinoTabView，详情 CupertinoPageRoute，返回手势与导航栈由框架提供；选择器、搜索、开关和分段优先 Cupertino 控件。
- macOS 风格：分组侧栏、固定设置、选中状态与140ms悬停 / 焦点过渡；每个目的地独立 CupertinoTabView，首次访问才构建，切换保留详情栈。非活动目的地关闭 TickerMode 并排除焦点。
- 课表/作业结果180ms easeInOut淡入，分组尺寸220ms；课程块按压使用 CupertinoButton。页面进入/返回沿用框架导航，不额外叠加大幅位移；系统“减少动态效果”关闭自定义过渡。
- 窄屏网格保留横向滚动提示和可见滚动条；按钮、搜索与关键行留出可操作区域；大字号使用清单。无时间不猜、失败保留旧内容，颜色不独立承担状态含义。
- Flutter 对 Apple 样式的复现不等于 AppKit 原生控件或像素一致；桌面悬停/键盘焦点尚需 Windows 实机验收。

Apple 官方依据：[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)、[Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)、[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。具体140/180/220ms是本项目校准值，Apple没有要求这些固定时长。

## 后续顺序

先补本轮真实只读的字段、交互与延迟证据，再在 Windows 主机运行独立验收。继续跟进非空成绩 / 历史、完整研究生组合视图、附件与提醒、键盘 / 读屏等剩余项。已有签到和图书馆写路径须人工逐次触发与回查；只读成功不证明写入成功，本轮不自动执行上游写入。


### 启动细节优化

启动页沿用叶片标识、字标与系统分组背景，280ms一次淡入/0.98→1轻微缩放，不循环、不等待动画完成。会话仍在首帧后立即恢复，不预热Rust网络运行时；减少动态效果时直接静态显示且不显示旋转进度，大字号可滚动。新增2项widget验证恢复不等待动画与减少动态效果；连同6项会话测试共8项通过，analyze通过。产品交互保留五入口、独立Tab栈和周网格默认方案。

公共统计路线修复后，Android使用NativeMirrorService/正式Rust adapter无账号真实GET成功解析2校区（仅输出状态/条数）。正常main入口debug APK已构建并重新安装；最终设备不保留测试入口。Windows、60天趋势、非空签到历史与真实多页预约仍未验收。


## 全面核对与正确性修复（2026-10-20）

详见[MIRROR-FULL-AUDIT](MIRROR-FULL-AUDIT.md)：逐模块记录UI/接口/缓存/刷新差距，不宣称100%对齐。修复长文本截断、今天/成绩错误时隐藏旧结果、成绩请求乱序、重复刷新、清缓存后旧页面保留、bridge读取与身份变更竞争、路线切换后退出残留保存账号、认证恢复失败绕过快照、CGYY北京时间与日期取消。

门禁：139项核心lib、1项契约、1项bridge并发测试、Clippy/analyze、35项widget通过；随后单独新增清缓存页面生命周期回归1项通过（累计36项widget）。Android aarch64交叉检查通过。未重跑mirror_test.dart、未放宽断言、未再次输入真实凭据。持久化/自动刷新/提醒、BYKC已选统计、研究生视图等未迁移项保留，不冒充已修复。

## 2026-10-20：设置、自检与 Android Alpha 更新

- 设置继续采用 Cupertino 大标题和分组列表：账号、网络路线、数据与存储、支持与更新、关于；补充缓存期限与清理边界，版本从安装包读取，退出操作防重复。
- 运行自检按用户点击执行：Rust 合成课表桥接、本地临时文件写读删除、保留前缀的合成安全存储条目写读删除；删除后确认不存在。可选公开统计强制请求，缓存回退不算连通成功；演示模式不联网。结果逐项显示，不读真实密码、不上传报告。
- 软件更新沿用 macOS `UpdateChecker.swift` 的 GitHub Releases 来源，Android 独立 `android-v<semver>` 标签。正式版本排除预发布，Alpha 包接收预发布；仅识别可信项目 URL 与 arm64 APK。未提供 APK 不显示可安装更新；失败保留上次结果和时间。浏览器下载后由系统确认安装，未实现应用内下载校验/静默安装。
- 公开更新请求使用独立直接 Session，完全不共享学校 Cookie/路线，无账号依赖；最多查询最近100条发布。新38类/121份合成fixture；Windows更新尚未接入。
- 本机完整门禁：143 core lib +1契约 +1 bridge、Clippy、Flutter analyze、38 Flutter tests通过；Android aarch64 cargo check通过。设备与发布结果见 `MIRROR-ANDROID-ALPHA.md`，不将本机测试等同所有学校接口验收。

## 2026-10-21：SPOC 教师上下文与宣传页

- 官网首页已发布Android Alpha下载与平台差异说明；Mac/Android release资产独立选择，API失败保留静态APK入口，390/1440宽度无横向溢出。不将macOS写操作、持久缓存和截图冒充Android实现。
- 按`SpocHomeworkClient.swift` Course.skjs和sskcid→kcid关联，把教师从领域/HTTP/context缓存贯通FRB、列表搜索和详情；缺值显示上游未提供，重复课程ID/教师类型漂移拒绝，刷新失败保留原教师快照。演示使用合成课程上下文fixture。
- 附件证据核查：macOS也只提供原站点处理说明，当前源码无已验证附件下载链路；镜像保留相同边界，不猜端点，不标记附件下载完成。
- 完整门禁143 core lib +1契约 +1bridge、Clippy/analyze、38 widget通过；随后扩展原应用测试与原作业widget覆盖教师、缺值、失败缓存及教师搜索，定向通过。新增3fixture，39类/124份。设备结果补记于本段后。

Android作业独立smoke通过（40秒，真实FFI+合成数据）：列表→教师详情→返回→筛选。未登录真实账号，教师实网字段仍待复验。Android编译含新版bridge通过，未重复执行mirror_test。

## 2026-10-21：博雅课程详情

按BykcClient.course与BykcCourseCard/详情源码迁移目录中已返回的时间、选课窗口、退选截止、校区、当前人数/容量、简介、已选与签到配置存在性。课程行可推入Cupertino详情；打开详情零网络请求。缺字段显示上游未提供，不伪造0或可选保证；签到配置正文不离开Rust。

完整门禁143 core lib +1契约 +1 bridge、Clippy/analyze、38 widget通过；新增1项深色1.8倍字号/缺容量测试通过（累计39 widget），增强BYKC缓存失败测试验证详情保留与配置正文裁剪，定向通过。39类126份fixture。已选记录与完成统计仍单独推进，选退课关闭。

Android博雅详情独立smoke通过：真实FFI合成目录→详情校区/简介→返回→搜索空态。首次Cupertino双标题定位已改为唯一页面类型定位，内容断言保留。真实目录新增字段尚未账号复验。

## 2026-10-21：研究生分区加载与学分展示

学籍和执行报告采用独立API、缓存、加载状态与失败重试；GSMIS激活按顺序执行以保护共享认证，第一份结果立即显示，报告含备用方案的等待不再阻塞学籍。Rust白名单增加可选数值学分和课程完成标记；绿色进度只计已认定学分，待考核单列、缺值不补0、超额进度条封顶但保留真实数值。应用缓存隔离测试、契约、Clippy、analyze及2个分区/大字号widget通过；研究生单项设备smoke通过（12秒）。正式main入口需在本轮设备测试后恢复；新增页面人工读图仍待完成，不宣称全量对齐。

## 2026-10-21：签到与图书馆写操作

用户明确要求迁移写功能后，接通课程签到（服务器时间→stu_scan_sign）、图书馆座位预约（日期密钥AES-CBC）、按预约类型取消、入座/返回、暂离、离馆。页面二次确认具体课程/座位/日期；Rust提交前重新读取当前记录并校验动作，合并多ID课程不提交，生命周期只使用上游明确提示；学校不接受空points时不会伪造定位。HTTP写入只发一次，无认证重发/路线回退/重定向重放。响应分受理、拒绝、未提交、待核实，原始服务端消息不进入Dart。提交后清理模块缓存并回查，等待回查时先显示提交反馈；待核实期间不提供重复提交按钮。

Rust 149项lib+1bridge与契约通过；随后路线修复新增回归另记。2项写操作widget验证确认/取消、重复点击抑制、提交后回查；Android write_actions_test单项smoke通过（48秒，真实FFI无账号拒绝+演示确认，不执行真实写入）。41类130份JSON契约。真实签到/预约未自动测试，仍需用户实际操作验收；CGYY/BYKC写功能未迁移，不宣称全部写功能完成。


2026-10-21 后续复核：对照 LibraryViewModel.reserve 的回查发布行为，修复座位页回查结果未同步原图书馆页面的问题；预约回查与座位刷新同时进行，已退出座位页也发布原页面结果。返回三级导航的回归在旧实现失败、修复后通过。签到行改为自适应纵向详情与状态/操作换行，避免固定列表行重叠；研究生零最低学分要求不显示“尚未完成”。4项相关widget与analyze通过，真实网络延迟仍待本机登录测量，未将本次修复当作用户全部卡顿的验收。


### 2026-10-21：缓存等待与会话恢复增量

- 已提交11837ef：研究生有效快照先于GSMIS请求锁返回，等待锁后重新检查缓存。两个确定性poll回归，其中缓存命中阻塞在旧实现失败；研究生相关14项通过，Clippy通过。见[MIRROR-GRADUATE-CACHE-AUDIT](MIRROR-GRADUATE-CACHE-AUDIT.md)。
- 已提交6b637f7：图书馆仅清除本次失败请求所用的旧token，迟到失效响应不再抹掉其他读取已恢复的新token；library相关24项、Clippy通过。见[MIRROR-LIBRARY-RECOVERY-AUDIT](MIRROR-LIBRARY-RECOVERY-AUDIT.md)。
- 设置新增“学校接口耗时”，只在用户点击后顺序读取图书馆/iclass/研究生，逐项显示耗时/条数/缓存标记/错误码，不保留正文或异常文本；演示模式不可测学校网络。3项定向widget、原维护2项widget、产品目录analyze、22秒独立设备合成smoke通过；未重复mirror_test。真实账号尚未完成本轮延迟测量，不能据此关闭“切页才刷新”的全部问题。
- 候选分支release/android-alpha-2-candidate与主工作区并行修改隔离；本轮候选正常main入口release重建成功，Android签名保持Alpha1同证书。尚未公开发布Alpha2，也未完成Windows/全模块真实验收。现有BYKC/研究生/宣传页未提交改动予以保留，不混入本轮修复提交。


## 2026-10-21 博雅学习记录与完成统计

目录、已选记录、完成统计已贯通独立快照与按需分段；缺学期范围不显示为零条，统计保留真实分子/分母并区分零要求。协议与验证详见 [BYKC 验收记录](MIRROR-BYKC-LEARNING-AUDIT.md)。真实账号、人工写入与 Windows 未据合成结果认定通过。


## 2026-10-21 研究生学分与课程层级

完成学分进度/课程/学籍分区及课程状态筛选、类别展开、课程原文详情；未知完成状态不丢课程。领域、widget及单项Android合成smoke通过；真实账号与完整学分地图仍待验收。详见 [验收记录](MIRROR-GRADUATE-PRESENTATION-AUDIT.md)。


## 2026-10-21 作业信息层级与正文保护

作业状态/截止/课程优先，列表懒构建并保留搜索与返回，详情分层与Cupertino复制菜单。正文类型漂移拒绝并保留旧详情。见 [验收记录](MIRROR-HOMEWORK-HIERARCHY-AUDIT.md)；真实账号与附件/作答仍不算完成。


## 2026-10-21 预约资源层级与座位性能

图书馆资源余量加入计数/进度和缺值区分，预约入口及CGYY层级细化，600座位列表懒构建。9项widget与11文件analyze通过；设备/实网分别见 [验收记录](MIRROR-RESERVATION-VISUAL-AUDIT.md)，不因展示改进认定真实写入通过。


## 2026-10-21 课表周次与横向操作

周次定位按实际字号与宽度，当前周和选择周保持可见；横向控制及滑条固定日期上方。3项widget、4文件analyze通过，见 [验收记录](MIRROR-SCHEDULE-SCROLL-AUDIT.md)。保留默认周网格与大字号清单。


## 2026-10-21 研究生课程学校字段（离线切片）

按 macOS 源码补齐课程代码、成绩、类别、属性及课程池考核/必修字段，课程代码可搜索，详情沿用快照。18 项研究生 Rust 测试、契约、Clippy/fmt、定向 analyze 和 5 项 widget 通过。尚未合入发布包、设备读图或实网验收；详见 [字段对照与验证](MIRROR-GRADUATE-COURSE-FIELDS.md)。


## 2026-10-21 培养方案与原文（独立分支）

按 macOS `loadPlan` 接通方案头部、章节原文与课程池，独立 `plan` 快照，入口打开后请求，既有学籍/报告首屏不增加请求。19 项研究生 Rust 测试、契约、Clippy/fmt、Android 交叉检查和 7 项 widget/定向 analyze 通过；三种合成外观读图后修正大字号字段对齐。设备 smoke 与真实账号仍待验收，尚未纳入发布包。见 [方案协议与验收记录](MIRROR-GRADUATE-PLAN-AUDIT.md)。
