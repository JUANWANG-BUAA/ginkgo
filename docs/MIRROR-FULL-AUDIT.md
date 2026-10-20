# 镜像功能与正确性审计（2026-10-20）

基线：`55e9578`，macOS参照为本仓库当前Swift源码。审计覆盖现有模块的页面状态、缓存、刷新和adapter调用；不代表每个真实返回字段都经人工逐项核验。不得将本报告写成100%对齐或零缺陷证明。Apple targets只读；写操作仍禁用。

## 已定位的正确性问题与处理

| 问题 | 证据 | 处理与回归 |
|---|---|---|
| 长标题/说明被截断 | Flutter CupertinoListTile默认title/subtitle maxLines=1；AppleListTile原样继承 | 局部恢复可换行DefaultTextStyle，保留Cupertino点击反馈；1.8倍长标题与多行说明回归 |
| 刷新失败藏掉旧内容 | TodayPage/GradesPage错误分支与内容互斥；成绩刷新busy时替换列表 | 错误提示与旧结果并存，空快照按fetchedAt判断，实际日期/学期仍可核对；页面回归 |
| 重叠刷新与旧响应覆盖 | 多页下拉/工具栏/重试可同时请求；成绩无序号 | 无查询范围变化的页面busy合并；成绩增加请求序号，旧失败不得覆盖新成功 |
| 清缓存后仍有旧页面 | 设置只清Rust缓存，各Tab及桌面IndexedStack保留本地数据 | Rust清理成功后重建工作区页面/路由；回工作台重新读取，保留账号与待办 |
| 清理后旧请求再写回 | bridge允许身份/缓存变更与读取并发，缓存键大部分不含账号代次 | bridge公平读写锁：读取并行；登录/恢复/退出/路线/清缓存独占，等待旧读取结束；本地同步待办竞争时明确失败 |
| 路线切换后退出残留密码 | set_route先清account；sign_out原先只删除当前account | 显式退出删除vault列出的已存账号并清身份；合成路线→退出回归 |
| 恢复失败绕过快照回退 | schedule/classroom使用silent_login().await?；只对部分错误保留 | 恢复失败进入原缓存fallback，所有读取失败保留既有范围；无保存密码的课表过期回归 |
| CGYY日期与取消行为 | DateTime.now使用设备日期；dismiss弹层也提交草稿 | 以北京时间日历日初始化；取消/遮罩关闭不发请求，确定才应用 |

读写锁解决正式bridge边界的会话竞争，不宣称任意直接调用SessionService的外部程序已获得相同串行保证。退出等待已有网络请求完成，仍受单请求30秒超时和协议有界跳转约束，不宣称即时取消网络。

## macOS逐模块差距（不能遗漏）

| 模块 | 已接入的只读路径 | 仍缺能力/验收 |
|---|---|---|
| 工作台/今天 | 课程、快捷入口、分组服务、设置 | macOS跨模块摘要/自动刷新调度不同，后台跨午夜未设备验收 |
| 课表 | 本科/研究生、学期周次、周网格/清单/考试条件显示、课程详情 | macOS已知周持久化与整学期缓存组织不同；提醒、非空本科实网、逐门时间比对缺失 |
| 成绩 | buaascore、学期、均分/GPA | macOS搜索/排序、持久化、非空真实成绩与公式人工对照缺失 |
| 作业 | SPOC学期/课程/加密分页/详情 | 教师skjs未贯通；附件/题目/希冀仍缺（希冀关闭）；上传作答不启用 |
| 签到 | 当天与历史、状态合并、日期缓存 | macOS30秒轮询/失败退避、通知、持久化历史缺失；非空历史待验；提交关闭 |
| 图书馆 | 馆区时段座位、当前/历史、公共人数余量 | macOS60天历史趋势、周期更新、区域缓存不同；真实多页历史待验；写操作关闭 |
| BYKC | 学期目录/搜索/分类 | macOS已选/统计/详情未迁移，选退关闭 |
| 研究生 | 学籍白名单、执行报告、课程学习 | 数字模型/学分地图/分类状态过滤/课程原文/成绩考试组合未齐 |
| 空教室 | 查询、筛选、排序、详情 | 原长流程已知不收敛，不重跑/不放宽；持久化与进入自动刷新不同 |
| CGYY | 公开目录、日期时段、最近20条 | 更多订单/日期验收不足，门锁/预约/取消禁用 |
| 通知 | 最新5条、摘要、官网 | macOS自动刷新及本地快照不同；网页全文由外部浏览器提供 |
| 待办 | 本地账号隔离CRUD | 精确时分、通知提醒、权限与同步未迁移 |
| 设置 | 账号/路线/清缓存/退出 | 外观/紧凑列表/启动/更新/提醒偏好；路线跨进程持久化与macOS不同 |
| 平台 | Android已运行；桌面分组导航 | Windows实机/键盘/读屏未验；菜单栏与全局快捷键不是Flutter已实现能力 |

## 缓存和刷新语义核对

macOS `Core/Storage/LocalStore.swift`：按账号SHA256文件名、原子JSON落盘；ViewModel先读缓存再刷新；Schedule/Grade默认15分钟陈旧判断，自动刷新经AutoRefreshGate与generation控制。镜像`application/cache.rs`：进程内300秒TTL、每类最多32键，Instant计时；进程重启不保留查询结果（待办除外）。两者明确不等价。

镜像键：课表(term?,week?)、成绩term或__current__、空教室(campus,date)、签到date、图书馆历史page、SPOC详情id、CGYY kind/site/date；单值模块用current/catalog/academic/public。默认课表None键跨周直到TTL、强刷与旧请求同key竞争、缓存别名同步仍需专项完善。不能把“清缓存已调用”推定所有自动刷新和离线行为对齐。

## 接口依据与范围

- BYXT/GSMIS/buaascore：`schedule_http.rs`、`graduate_schedule_http.rs`、`grades_http.rs` 对照ScheduleClient/GradeClient与API §2–4。
- SPOC：`homework_http.rs` 对照SpocHomeworkClient与API §7.1；保留200成功码、加密body与课程上下文，不调用中转API。
- iclass：`checkin_http.rs` 对照CheckInClient与API §7.2；历史复用dateStr，不添加提交请求。
- booking.lib：`library_http.rs` 对照LibraryClient、API §5；历史type=1/page/limit=40；公共页单独Cookie会话，原始路线偏好。
- BYKC/GSMIS报告：`bykc_http.rs`、`graduate_http.rs` 对照BykcClient/GraduateAcademicClient与EDUCATION-DATA-MAP；不同成功码保持各自判定。
- CGYY：`cgyy_http.rs` 对照CgyyClient，固定直连；当前bridge只接venues/day/orders。
- 通知：`notices_http.rs` 对照CampusNoticesClient；仍借用学校Session，公开Cookie隔离没有与公共统计统一，需专项核对。

此轮未重复真实账号登录，不复述或使用历史密码。既有真实通过记录按MIRROR-IMPLEMENTATION保留，不扩大为全功能验收。后续优先修正确性与缓存失效，再逐模块补只读信息，平台能力分开验收。


## 验证结果

- 完整门禁一次：139项核心lib、1项契约、1项bridge并发测试、Clippy、analyze、35项widget通过。
- 后增缓存TTL/容量/清理测试单独通过（核心lib累计140）；清缓存页面生命周期回归单独通过（widget累计36）。未把累计数量误写为一次全量运行数量。
- Android aarch64 bridge检查通过；`refresh_audit_test.dart`独立设备合成smoke通过（43秒），覆盖工作台→成绩刷新→返回→设置清缓存→回工作台，真实FRB demo数据；不包含真实账号/全模块大字号验收。
- 长标题/多行说明1.8倍字号widget通过；系统读屏、Windows桌面仍未验收。现有页面的浅深大字号既往记录不扩大为此次所有页面通过。
- 未运行已知不收敛mirror_test.dart；本轮没有发送上游签到、预约、取消或选退请求。


剩余正确性专项：今天页门户探测失败仍会在应用层快照fallback之前返回（页面现保留旧结果）；后台跨日默认课表周缓存、同时刷新同key的完成顺序、公开通知Cookie隔离、vault删除失败反馈仍需处理，不以本轮回归掩盖。CGYY取消逻辑已改但尚无独立日期弹层设备验收。此轮是全范围审计与已确认问题修复，不是所有迁移差距已完成。

最终正常main APK已重新构建安装，登录页无障碍状态确认；保险库文件不存在。改动仅rust/flutter/docs，无Apple targets改动。修复提交：6494a55（会话与快照）、1293a15（UI与刷新）。
