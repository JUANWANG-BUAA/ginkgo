# Flutter 与 Apple 客户端功能对照

更新：2026-10-23；对象为当前源码，功能/接口统一索引见 [功能和接口协议](FEATURES-AND-PROTOCOLS.md)，公开包内容另见 [Alpha.6记录](archive/mirror/MIRROR-ALPHA6.md) 与 [Alpha.7记录](_audit/2026-10-23-android-alpha7-release.md)。Apple 维持 SwiftUI，Android / Windows 使用 Rust + Flutter；新增手机 UI 以现有 iOS 原生页面为设计验收基准；桌面保留 macOS 层次。未完成逐像素对照的部分必须单列，不能仅凭 Cupertino 组件宣称完全对齐。

本轮Today 2.0、作业转待办、常用入口/配色/动效及CGYY闭环纳入Android Alpha.7源码；[用户说明](releases/android-alpha7.md) 与 [Alpha.7记录](_audit/2026-10-23-android-alpha7-release.md) 单列发布、签名与升级边界，不改变Apple/Windows公开包状态。Alpha.7 之后的当前工作树已移除作业详情转待办入口，新增公开查书/馆藏与应用内校车等；不能按沿用版本号认定这些后续改动已发布。

下表的“已接入”表示代码链路存在。真实只读证据和最近登录失败均保留于 [验收归档](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md)，不推导真实写入或未覆盖的平台验收。

| 模块 | Apple 定位（BUAA-Assistant/Features/） | Flutter 当前实现 | 缺口 / 待验收 |
| --- | --- | --- | --- |
| 今天 / 课表 | Today/、Schedule/ | 本科 BYXT 与研究生 GSMIS、今日正在/下一节焦点、默认折叠全天课程、近期作业直达与个人待办独立分区、周网格 / 清单、学期 / 周次 / 搜索 / 课程详情；有数据时展示考试 | 提醒、真实逐门核对、本科账号、跨午夜与设备缓存场景；研究生不伪造考试 |
| 作业 | Homework/SpocHomeworkClient.swift、HomeworkView.swift | SPOC 真实列表 / 详情与教师上下文；学生身份优先，已确认助教课程默认收起且不进入个人待完成统计；支持按账号、按系统隐藏课程并保留未知归属 | 已接入截止前 48 / 24 小时提醒和未读角标；希冀、附件下载、作答和提交未迁移；真实学生 / 助教课程列表仍需账号人工核对 |
| 签到 | CheckIn/CheckInClient.swift、CheckInSummaryView.swift | 当天 / 按日历史、冲突合并、首次读取阶段与耗时反馈、按账号隐藏非个人课程、确认后单次提交与回查；语义状态色 | 已接入前台两分钟只读刷新、课前十分钟门禁及单课提醒；真实写入与后台覆盖仍待验收；iClass 的课程内身份仍待真实响应证据，不能套用 SPOC 的 `kcid` |
| 图书馆 | Library/LibraryClient.swift、LibraryView.swift | 馆→区→时段→座位、当前 / 历史预约和公共人数；分区独立加载；确认、单次写入、回查；根页状态由 LibraryController 管理 | 真实多页历史、趋势及真实写入；原有座位页通知根页的回调已保留并集中强制回查 |
| 公开查书 / 馆藏 | Apple 当前未迁移此查询页 | 匿名关键词检索、相关度/出版年/题名排序及升降序、按需查看馆藏复本原始状态；Rust 内受限解码 | 真实排序/分页/限流全分支、本人非空借阅；不含续借/预约 |
| 校车时刻表 | Apple 当前未迁移此查询页 | 应用内读取官方公开时刻表、双向班次及计划可乘人数、官方页面入口 | 真实设备与官方临时调整对照；不代理购票、不显示实时余票 |
| 博雅 | BYKC/BykcClient.swift、BykcView.swift | 目录 / 已选 / 统计独立快照，按需分段、懒列表、详情、类别完成进度 | 非空已选实网、选退课与博雅签到 |
| 研究生教务 | Graduate/GraduateAcademicClient.swift、GraduateAcademicView.swift | 学籍 / 执行报告独立加载；概览 / 要求 / 课程、认定 / 待考核 / 缺口、在修学分聚合与双段进度、课程筛选与详情 | 完整学分地图及成绩 / 考试组合仍未齐 |
| 成绩 | Grade/GradeClient.swift、GradeView.swift | 学期、原始成绩与均分 / GPA，失败保留旧结果 | 真实非空成绩和汇总对照 |
| 空教室 | Classroom/ClassroomClient.swift、ClassroomView.swift | 校区 / 日期 / 节次筛选、缓存与错误区分 | 设备长流程仍未收敛，不能以单次查询替代完整验收 |
| 本地待办 | Tasks/ | 按账号隔离的本机增删改、无截止/日期/精确北京时间、本地完成与学校状态独立、次级操作菜单及已完成计数折叠；旧 v1 读取/变更写 v2；作业转待办新建入口已撤，历史来源记录仍保留、首页不重复预览 | 完整待办提醒、跨设备同步、物理真机/读屏及旧版本降级说明；本轮证据见 [迭代记录](_audit/2026-10-22-android-product-iteration.md) |
| 校园通知 | Campus/CampusNoticesClient.swift | 列表、摘要和原文链接 | 外部浏览器往返与全量读屏 |
| CGYY | Venue/CgyyClient.swift、CgyyView.swift | 场馆 / 校区 / 容量、日期时段、订单；完整摘要确认、手动验证、单次提交 / 取消、审批状态；账号绑定、跨重启最小待核实标记、强读展示后一次性确认解锁 | 门锁码未迁移，真实写入未验收；非空订单和场馆日期覆盖仍需补 |
| 导航 / 设置 | Auth/、Settings/、Core/Network/UpstreamRoute.swift | 760px 宽度切换 iOS 式手机布局与 macOS 式桌面层次；独立导航栈；非工作台返回、工作台二次确认；7 组深浅强调色与预览、账号级常用入口 0–4 项、手机栏目方向动效/减少动态效果；显示与阅读、通知与后台、账号隐私、UBAA 致谢与分享；应用内 Android 更新 | Windows 真实业务 / 完整读屏；主登录验证码图片、Windows 系统通知与后台签到仍未接通；Android 截止 / 签到本地提醒和诊断 hint 已接入 |
| Windows | 原生 macOS 作为行为参照 | 当前公开 Alpha.6（Alpha.4 为首发），未签名 x64 单文件安装器与便携 ZIP；Parallels Windows 11 ARM 上的 Release、保险库、独立详情栈、宽窄切换、固定桌面页头、Tab / Enter 与返回栈回归已通过 | [首发边界](archive/mirror/MIRROR-WINDOWS-ALPHA4.md)：物理 x64、干净系统依赖、读屏、真实业务、签名与更新仍待验收 |

当前状态色在 [AppleDesign](../flutter/lib/apple_design.dart) 集中定义，覆盖签到、作业、图书馆与场馆的成功 / 待处理 / 待核实 / 错误 / 未激活呈现。文字仍保留具体业务状态，不由颜色反推“可签到 / 可预约”。

可重复的验证入口见 [实施现状](MIRROR-IMPLEMENTATION.md)，剩余工作只在 [TODO](MIRROR-TODO.md) 更新。旧版逐模块分析和每轮细节见 [历史索引](archive/mirror/README.md)。
