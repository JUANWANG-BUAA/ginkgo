# Flutter 与 Apple 客户端功能对照

更新：2026-10-21；对象为当前源码，公开包内容另见 [Alpha.5 发布记录](archive/mirror/MIRROR-ANDROID-ALPHA5.md)。Apple 维持 SwiftUI，Android / Windows 使用 Rust + Flutter；共享领域语义和交互目标，不要求控件像素相同。

下表的“已接入”表示代码链路存在。真实只读证据和最近登录失败均保留于 [验收归档](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md)，不推导真实写入或未覆盖的平台验收。

| 模块 | Apple 定位（BUAA-Assistant/Features/） | Flutter 当前实现 | 缺口 / 待验收 |
| --- | --- | --- | --- |
| 今天 / 课表 | Today/、Schedule/ | 本科 BYXT 与研究生 GSMIS、今日摘要、周网格 / 清单、学期 / 周次 / 搜索 / 课程详情；有数据时展示考试 | 提醒、真实逐门核对、本科账号、跨午夜与设备缓存场景；研究生不伪造考试 |
| 作业 | Homework/SpocHomeworkClient.swift、HomeworkView.swift | SPOC 真实列表 / 详情与教师上下文；学生身份优先，已确认助教课程默认收起且不进入个人待完成统计；支持按账号、按系统隐藏课程并保留未知归属 | 希冀、附件下载、作答和提交未迁移；真实学生 / 助教课程列表仍需账号人工核对 |
| 签到 | CheckIn/CheckInClient.swift、CheckInSummaryView.swift | 当天 / 按日历史、冲突合并、首次读取阶段与耗时反馈、按账号隐藏非个人课程、确认后单次提交与回查；语义状态色 | 自动轮询 / 提醒与真实写入；iClass 的课程内身份仍待真实响应证据，不能套用 SPOC 的 `kcid` |
| 图书馆 | Library/LibraryClient.swift、LibraryView.swift | 馆→区→时段→座位、当前 / 历史预约和公共人数；分区独立加载；确认、单次写入、回查；根页状态由 LibraryController 管理 | 真实多页历史、趋势及真实写入；原有座位页通知根页的回调已保留并集中强制回查 |
| 博雅 | BYKC/BykcClient.swift、BykcView.swift | 目录 / 已选 / 统计独立快照，按需分段、懒列表、详情、类别完成进度 | 非空已选实网、选退课与博雅签到 |
| 研究生教务 | Graduate/GraduateAcademicClient.swift、GraduateAcademicView.swift | 学籍 / 执行报告独立加载；概览 / 要求 / 课程、认定 / 待考核 / 缺口、课程筛选与详情 | 完整学分地图及成绩 / 考试组合仍未齐 |
| 成绩 | Grade/GradeClient.swift、GradeView.swift | 学期、原始成绩与均分 / GPA，失败保留旧结果 | 真实非空成绩和汇总对照 |
| 空教室 | Classroom/ClassroomClient.swift、ClassroomView.swift | 校区 / 日期 / 节次筛选、缓存与错误区分 | 设备长流程仍未收敛，不能以单次查询替代完整验收 |
| 本地待办 | Tasks/ | 按账号隔离的本机增删改、完成状态 | 精确截止时刻、提醒、跨设备同步 |
| 校园通知 | Campus/CampusNoticesClient.swift | 列表、摘要和原文链接 | 外部浏览器往返与全量读屏 |
| CGYY | Venue/CgyyClient.swift、CgyyView.swift | 场馆 / 校区 / 容量、日期时段和订单只读，语义资源状态色 | 写入 / 门锁码未迁移；非空订单和场馆日期覆盖仍需补 |
| 导航 / 设置 | Auth/、Settings/、Core/Network/UpstreamRoute.swift | 760px 宽度切换 iOS 式手机布局与 macOS 式桌面层次；独立导航栈；非工作台返回、工作台二次确认；显示与阅读、通知与后台、账号隐私、UBAA 致谢与分享；应用内 Android 更新 | Windows 真实业务 / 完整读屏；验证码图片、系统通知调度与后台签到仍未接通 |
| Windows | 原生 macOS 作为行为参照 | Alpha.4 未签名 x64 单文件安装器已公开，便携 ZIP 备用；Parallels Windows 11 ARM 上的 Release、保险库、独立详情栈、宽窄切换、固定桌面页头、Tab / Enter 与返回栈回归已通过 | [首发边界](archive/mirror/MIRROR-WINDOWS-ALPHA4.md)：物理 x64、干净系统依赖、读屏、真实业务、签名与更新仍待验收 |

当前状态色在 [AppleDesign](../flutter/lib/apple_design.dart) 集中定义，覆盖签到、作业、图书馆与场馆的成功 / 待处理 / 待核实 / 错误 / 未激活呈现。文字仍保留具体业务状态，不由颜色反推“可签到 / 可预约”。

可重复的验证入口见 [实施现状](MIRROR-IMPLEMENTATION.md)，剩余工作只在 [TODO](MIRROR-TODO.md) 更新。旧版逐模块分析和每轮细节见 [历史索引](archive/mirror/README.md)。
