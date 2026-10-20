# Flutter 与 Ginkgo macOS 功能、信息和交互核对

日期：2026-10-20。范围：当前镜像与仓库内 Swift 源码；UBAA 协议交叉证据见 [体验设计](MIRROR-EXPERIENCE-DESIGN.md)。本表区分实现、真实响应和仍未迁移，不将合成 smoke 等同真实验收。

## 已对齐和仍有差距

| 模块 | macOS 源码证据（BUAA-Assistant/Features/ 下） | Flutter 当前 | 明确未迁移或未验收 |
|---|---|---|---|
| 课表 | Schedule/ScheduleView.swift、TimetableGrid.swift、TimetableLayout.swift、CoursePalette.swift | 周网格默认；每日清单/学期/有数据时考试；学期切换、日期、今天列、节次/时间/地点/教师详情；稳定多色、冲突分栏、搜索；研究生条目时间方案已修正 | 课程提醒未迁移；真实时间仅核验字段完整，未逐门与教务人工比对；窄屏网格横滑，大字号改清单 |
| 作业 | Homework/HomeworkView.swift:58,214,284,319,419；SpocHomeworkClient.swift | SPOC 真实列表/详情；全部/待完成/已提交、截止与待确认快捷筛选；本地标题/课程搜索；说明、发布/截止/提交时间和分值；原站点入口；180ms 状态切换 | 教师字段尚未从课程上下文贯通 DTO；希冀关闭；提交、下载附件与题目作答未迁移；来源只有 SPOC，不造多来源筛选 |
| 课程签到 | CheckIn/CheckInSummaryView.swift:140,280；CheckInClient.swift | 当天课程、已签/未签/待确认计数、时间、地点、合并冲突和核对时间；网关认证已真实恢复 | 历史日期已迁移；Android前一天真实空结果通过（非空历史待验收）；30秒自动轮询、提醒通知未迁移；提交签到按本轮范围关闭 |
| 图书馆 | Library/LibraryView.swift:182,317,431；LibraryPublicStats.swift、LibraryOccupancyHistory.swift | 真实馆→区→时段→座位及当前预约；CAS并发锁、网关恢复；本地座位搜索/只看空闲；状态同时用图标与文字；独立公共人数/阅览室/资源余量页，预约认证失败仍可达 | 历史预约已迁移；Android真实第一页10条/末页通过（多页待验收）；公共统计host实网两校区解析通过；60天本地历史趋势未迁移；预约/入座签到/暂离/离馆/取消关闭 |
| 博雅 | BYKC/BykcView.swift:5,27,202,257 | 当前学期目录、搜索和类别筛选；真实响应通过 | 已选记录、完成统计、课程详情尚未迁移；选退课关闭 |
| 研究生教务 | Graduate/GraduateAcademicView.swift:6–9,417,452；GraduateProgress.swift | 学籍白名单、zxbg 原结构报告和课程学习；真实响应通过 | macOS 学分地图、分类/完成状态筛选、课程原文和成绩考试组合视图未完整对齐；不能宣称已覆盖研究生全部信息 |
| 成绩 | Grade/GradeView.swift、GradeClient.swift | 学期、课程原始成绩、加权均分/GPA | 当前轮没有重新逐项人工对照；Windows 未验收 |
| 空教室 | Classroom/ClassroomView.swift、ClassroomClient.swift | 校区/日期/空闲节次、缓存与错误区分 | 当前轮不重跑已知不收敛的校区/日期/缓存长流程 |
| 本地待办 | Tasks/TasksView.swift:26,85 | 本地增删改、完成状态和账号隔离 | macOS 精确截止时刻及提醒行为尚未逐项对齐；本地测试不代表通知验收 |
| 校园通知 | Campus/CampusNoticesSummaryView.swift、CampusNoticesClient.swift | 列表、摘要与原文链接，真实响应通过 | 原站网页展示由浏览器负责，未宣称复制网页全文 |
| CGYY | Venue/CgyyView.swift、CgyyClient.swift | 公开场馆、当天时段、最近订单真实只读响应通过 | 写操作、门锁码未开放；未人工遍历每场馆日期 |
| 设置/账户 | Settings/、Auth/；Core/Network/UpstreamRoute.swift:93–99 | 手机齿轮+首屏账户行、桌面固定底部设置；路线/缓存/保险库/退出 | 验证码图片、通知权限/提醒偏好、外观偏好、自动启动等尚未迁移；不将登录成功等同全部账户状态通过 |

路径用于定位可核查实现，不把字段相似视为协议已经一致。当前真实账号是研究生门户，不代表本科门户已做真实账号验收。

## Dart 原生风格实现与交互

- iOS 路径：CupertinoTabScaffold + 每个 Tab 独立 CupertinoTabView，详情 CupertinoPageRoute，返回手势与导航栈由框架提供；选择器、搜索、开关和分段优先 Cupertino 控件。
- macOS 风格：分组侧栏、固定设置、选中状态与140ms悬停/焦点过渡；首次访问才构建页面，避免切换前触发所有业务认证。
- 课表/作业结果180ms easeInOut淡入，分组尺寸220ms；课程块按压使用 CupertinoButton。页面进入/返回沿用框架导航，不额外叠加大幅位移；系统“减少动态效果”关闭自定义过渡。
- 窄屏网格保留横向滚动提示和可见滚动条；按钮、搜索与关键行留出可操作区域；大字号使用清单。无时间不猜、失败保留旧内容，颜色不独立承担状态含义。
- Flutter 对 Apple 样式的复现不等于 AppKit 原生控件或像素一致；桌面悬停/键盘焦点尚需 Windows 实机验收。

Apple 官方依据：[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)、[Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)、[Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。具体140/180/220ms是本项目校准值，Apple没有要求这些固定时长。

## 后续顺序

先按本表补核心只读信息：图书馆历史/公共信息与签到历史；随后 SPOC 教师/附件信息、博雅已选/统计、研究生视图。每项独立补协议证据、fixture、应用链路和一个页面 smoke。上游写操作继续逐项后置，不能由只读成功推定安全可写。


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
