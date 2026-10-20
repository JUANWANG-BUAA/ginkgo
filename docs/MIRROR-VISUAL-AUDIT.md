# 镜像视觉审查

> 2026-10-20。目标：颜色、组件、层次、字体、布局、动画和状态与对应 Apple 产品尽量一致。当前先审查空教室切片，不宣布整个镜像或“100% 相似度”通过。

## 参照与方法

Android 直接参照 `BUAA-Assistant-iOS/Sources/Native/IOSClassroomView.swift`；Windows 参照 `BUAA-Assistant/Features/Classroom/ClassroomView.swift` 与 `docs/UI-DESIGN.md`。

2026-10-20 已重新运行 `Ginkgo iPhone 17 Pro / iOS 27.0` 的 `GinkgoSmokeUITests.testAuthenticatedShellIsReachable`：1 项通过，导出 12 张原生页面截图（本机 `artifacts/local/ios-attachments/`），其中 `iOS classroom` 作为本轮初始页参照。使用现有演示环境，没有真实账号验收。

原生截图与 Android Flutter 表面截图的分辨率、系统状态栏和全局导航不同，应按逻辑尺寸和内容区域比对。当前没有定义可证明“接近 100%”的像素分数，不采用不同视口的整图 SSIM 作为通过凭据。

## 官方依据

- [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials)：导航/控件与内容层分开；玻璃效果节制使用。
- [Apple Color](https://developer.apple.com/design/human-interface-guidelines/color)：颜色按语义使用，适配明暗与可读性。
- [Apple Typography](https://developer.apple.com/design/human-interface-guidelines/typography)：层级、可读性、字重与可访问字号；系统字体不嵌入应用分发。
- [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion)：动效服务于状态反馈，支持关闭动态效果。
- [Apple Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、[Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)、[Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)：按平台组织高频操作与导航。

同时检查本机 Flutter 3.47 的 `cupertino/list_section.dart`：默认 inset group 的采样注释仍指向 iOS 14，因此不把默认 Cupertino 尺寸视为当前 iOS 原生外观的保证。

## 本轮调整

| 维度 | 实现 | 验证与剩余差异 |
| --- | --- | --- |
| 颜色 | 语义背景、label、separator；品牌绿直接对照 Apple 资源 `#189840` / `#47bd6b` | 深色与高对比需分别复核 |
| 分组与层次 | 16pt 页边、26pt 连续圆角、52pt 基础行；查询、筛选、结果、楼栋分组 | 尺寸是项目截图校准值，不是 HIG 通用常量 |
| 控件 | 日期胶囊、着色快捷按钮、浮动选择菜单、圆形刷新、详情节次网格 | SF Symbols 与 Cupertino 图标的字形仍有差异 |
| 字体 | Inter 变量字体 + Noto Sans SC 变量字体，正文 17、主标题 34，区分字重与字距 | 近似 SF / 苹方；不声称字形完全相同 |
| 材质 | 模糊与高光限于导航按钮和临时菜单；内容保持纯净表面 | Flutter 近似实现，不是原生 Liquid Glass 折射 |
| 动画 | 按压 90/260ms，分组 220ms，菜单 180ms，保留 Cupertino 页面过渡 | 时长/曲线是 Ginkgo 调整值；减少动态效果时自定义动画为零 |
| 可读性 | 放大文字、深色、语义标签；14 节状态由 Rust 提供 | 需要进一步 TalkBack 人工复核，widget 测试不等于读屏验收 |
| 导航外壳 | 手机端“今天 / 课表 / 作业 / 图书馆 / 更多”五项 Cupertino Tab；桌面侧栏按工作台/学习/校园/更多分组 | 已对齐 iOS 参照的信息架构；账号切换与通知入口仍缺 |

## 历史截图命令（本轮不要重跑已知长流程）

```sh
cd flutter
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/mirror_test.dart \
  --dart-define=GINKGO_CAPTURE=true \
  -d emulator-5554
```

PNG 写入 `flutter/build/visual/`；保存初始、结果、详情、零匹配、错误，以及深色放大文字状态。驱动只检查截图文件完整性，视觉一致性另行人工审查。

本机证据可复制到 `artifacts/local/mirror/`，该目录不入库。原生参考 `.xcresult` 与完整日志位于本机临时目录，具体命令与结果以本次执行记录为准。

## 后续审查

1. 当前完整导航外壳、iOS 27 的玻璃细节及 Windows/macOS 布局仍要按模块接入后继续对齐。
2. 相同页面状态、固定视口、固定字号分别采集浅色/深色截图，标注字体、图标和系统表面的不可直接共享之处。
3. 对滚动、选择菜单、详情返回、加载/失败切换做动态检查；静态截图不替代动效验收。

## 已确认差异（初始页）

- 参照页从“更多”推入，因此左上角有返回圆钮；镜像的空教室也已改为从“更多”推入，返回钮与层级一致。
- iOS 底部为“今天 / 课表 / 作业 / 图书馆 / 更多”五项；2026-10-20 晚已按此重排，空教室与成绩移入“更多”。图书馆/签到已从骨架替换为只读页面（见下文第二轮记录）。
- 镜像保留了“离线合成样例 / 查看共享规则示例”演示说明，iOS 演示模式没有这两个页脚；这是有意的可验证性差异，不作为像素一致项。
- 初始页的页边距、卡片圆角、语义色、大标题和空态结构已接近；字体仍为 Inter/Noto Sans SC 近似 SF/苹方。

## 2026-10-20 晚：iOS 五 Tab 与设置页重构

- 移动端：底部五项改为“今天 / 课表 / 作业 / 图书馆 / 更多”；“更多”使用 inset grouped 分组（账号卡、工作台、学习、校园、设置），空教室/成绩改为推入页面。
- 桌面端：侧栏改为“工作台 / 学习 / 校园 / 更多”分组，底部保留账号与退出入口。
- 设置页：账号卡、退出登录、网络路线选择、清除查询快照、版本与核心信息；切换路线会明确提示需要重新登录。
- 图书馆/课程签到：当轮仍为导航骨架；第二轮已接入真实只读数据（见下文），不再显示“尚未迁移”。
- 真实账号只读验收已跑通今天/课表/空教室/成绩空结果；真实课程名、姓名和学号没有进入仓库截图或文档。
- 本轮未采集登录后带姓名/学号的截图入库；账号卡截图仅在本机临时查看后删除。

## 设备证据（2026-10-20）

使用带窗口、硬件 GPU 的 Android 模拟器（非 headless/SwiftShader）：

- `integration_test/mirror_test.dart`：真实 FFI、查询/详情/返回、14 个空闲节次、最少空闲/连续空闲/三种排序均通过（前 3 项）。第 4 项校区/日期流程在设备测试框架内长时间未收敛，已中止，未标记通过。
- `integration_test/schedule_test.dart`：课表 Tab 经真实 FFI 通过，包含周网格课程块、考试区、切换未缓存周次的空态。测试结果：1 项通过。
- `integration_test/grades_test.dart`：成绩 Tab 经真实 FFI 通过，包含加权平均/绩点汇总、课程分数与学分。测试结果：1 项通过。
- `integration_test/today_test.dart`：今天 Tab 经真实 FFI 通过，包含日期/星期、课程数量与当天课程行。测试结果：1 项通过。
- `integration_test/homework_test.dart`：作业 Tab 经真实 FFI 通过，包含 SPOC 列表、待完成/已提交计数与状态筛选。测试结果：1 项通过。
- 课表/成绩设备测试最初在四 Tab 外壳上通过；2026-10-20 晚在最终五 Tab 外壳上重新运行 `schedule_test.dart` 与 `grades_test.dart`，均通过。今天/作业同样在五 Tab 外壳通过。
- 空教室筛选菜单曾整体压到底部 Tab 下方，导致第 3 节以后不可点击；已在 `choose` 中加入移动端底部安全区并复测。
- 课表截图保存在本机 `artifacts/local/mirror/android-schedule-grid.png`（宽度调整前）。iOS 演示课表截图为“会话过期”空态，不能作为网格像素参照；只用于外壳、刷新按钮和空态结构对照。

## 2026-10-20 晚：登录与真实/演示入口

本轮新增登录页、会话恢复门禁和真实/演示两种入口，视觉复核范围只到“结构、层级和文案”，没有做跨视口像素分数。

- 登录页：大标题式品牌区、统一身份认证分组、学号/密码/记住密码、登录按钮与“先看看离线演示”次级入口。字体仍为 Inter/Noto Sans SC 近似 SF/苹方；图标使用 Cupertino 近似符号，不是 Apple 原生 SF Symbol。
- 会话恢复：启动时显示“正在恢复本地会话…”；无保存账号时进入登录页；恢复失败时在登录页显示本地化错误。
- 真实模式：今天页右上角增加“账号”圆形玻璃按钮，点开显示账号名与退出登录；桌面侧栏底部显示账号名与退出入口。
- 离线演示：今天页右上角为“演示模式”眼睛按钮，点开可“返回登录”；桌面侧栏底部显示“离线合成样例”。
- 旧结果：空教室、今天、课表、成绩在刷新失败且存在旧快照时显示橙色警告行，不再清空页面。
- 验证码：仅显示提示与可选输入框，没有图片展示；不能把这一步算作验证码 UI 完成。
- 已采集登录页浅色与深色、1080×2400 的启动截图，保存在本机 `artifacts/local/mirror/android-login.png` 与 `android-login-dark.png`；尚未采集大字号和错误态，不能据此给出登录页像素通过结论。文字/按钮/输入框在两种外观下都保持可读，绿色主色在深色下自动提亮。

### 设备证据（2026-10-20 晚）

- `integration_test/auth_test.dart`：Android Keystore/JNI 保险库两次写入/读回/删除往返通过；无保存账号时应用启动到登录页通过。测试结果：2 项通过。
- `integration_test/today_test.dart`、`schedule_test.dart`、`grades_test.dart`、`homework_test.dart`：最终五 Tab 外壳下均通过（真实 Rust 动态库 + 合成数据）；成绩从“更多”进入后通过。
- `integration_test/auth_test.dart`：最终外壳下重新通过（保险库往返 2 项）。
- `integration_test/mirror_test.dart`：先有一轮 8 项中 5 项通过、3 项失败（校区/日期/缓存、课表 Tab、深色大字号）；修正课表/深色测试的导航后重跑，前 3 项通过，第 4 项“校区/日期/缓存/刷新”再次在测试框架内长时间未收敛，已中止。整文件未标记全绿。
- 登录页只做了启动与字段存在的结构检查，没有提交真实账号，也没有用真实账号截图。

## 2026-10-20 晚（第二轮）：课程签到与图书馆只读页

- 签到页：大标题“课程签到”，日期分组显示当天课程数与已签到/未签到计数；课程行含时间、教室、教师与合并记录数，状态用绿色/灰色/橙色区分“已签到/未签到/待确认”；冲突记录在副标题提示“状态待确认”。空态、错误态与刷新失败保留旧结果的提示沿用今天/成绩页的结构。页面没有签到按钮。
- 图书馆页：Tab 首屏为“当前预约 + 选择场馆”，随后推入区域、时段、座位；使用与空教室/成绩一致的 inset grouped 行、圆形导航按钮和语义色；座位行只用图标与状态文本表达可用性。页面没有预约/签到/暂离/离馆/取消按钮。
- 两页的设备证据：`integration_test/checkin_test.dart`、`integration_test/library_test.dart` 在 Android 模拟器通过（真实 Rust FFI + 共享合成 fixture），分别验证状态行、计数、空态/错误/旧结果与四级层级推入。
- 五 Tab 外壳下重新运行 auth/today/schedule/grades/homework/checkin/library 七个设备测试，均通过。
- 视觉复核范围只到结构、层级和文案；没有采集两页固定视口的浅色/深色/大字号截图，不能标记像素通过，也不把合成数据页面当作真实上游状态。

## 2026-10-20：课表优先重构

- 学期参数贯穿 Rust 用例、FRB 与 Dart；BYXT/GSMIS 命中指定学期，否则回退学校选中/首个学期，返回最终学期。缓存按 `(term_id, week)` 隔离，今天仍请求默认学期与周次。
- 手机使用按星期与日期分组的课程列表，时间/节次、色条、课名、地点和教师分层；推入课程详情。学期菜单、带日期的周条、本周快捷入口、课程/学期/考试分段与本地搜索已接入。学期列表不编造课程数；考试仅在已有数据时出现。
- 刷新与未缓存周失败保留旧课表并提示实际显示范围；请求序号保护快速切换。排序/过滤在数据或关键词变化时计算。宽屏保留七列网格并显示日期、今天列，放大文字改用列表。
- 验证：21 项 Rust 课表相关测试、122 项 workspace lib + 1 项契约、Clippy、Flutter analyze、25 项 widget 测试通过；Android `schedule_test.dart` 1 项真实 FFI + 合成 fixture smoke 通过。未运行已知不收敛的 `mirror_test.dart`；其重复课表用例已移除，保留独立 smoke。FRB stem 为 `ginkgo_flutter_bridge`。
- 模拟器合成课表已查看浅色、深色、1.8 倍字号截图（仅 `/tmp/ginkgo-schedule-*.png`，不入库）。保持 34pt 标题、16pt 页边与26pt分组圆角；字体/系统材质仍为 Flutter 近似，未宣称像素一致。真实账号学期切换仍待本机登录，Windows 未验收。

## 2026-10-20：SPOC 真实只读链路

- 已接通 SPA/CAS 完整回调、Token/RoleCode、当前学期/课程上下文、最多100页作业与正文/提交信息详情；全部走 Session 路由。真实入口不再调用 loadDemoHomework，离线演示仍独立保留。
- 列表/详情五分钟快照、账号/路线/登出清空、会话过期单次恢复、失败保留旧结果；正文仅显示纯文本。列表点击推入详情，缺正文/时间/分值明确显示未确认，不推断已提交。希冀与提交/上传仍关闭。
- 4份新增合成详情契约覆盖正常/空/漂移/业务拒绝，contracts router已登记；8项作业Rust测试、契约、Flutter analyze与25项widget通过。Android独立作业smoke含列表/详情/筛选，结果见当次交付记录。真实上游验收待本机登录，不将合成FFI当作真实数据通过。

## 2026-10-20：博雅课程目录

- BYKC CAS token、随机 AES-ECB/PKCS7、RSA PKCS1 ak/sk、SHA1 与时间戳按 `BykcClient.swift` / `EDUCATION-DATA-MAP.md` §2 迁移；配置学期、课程分页只读接通。五分钟内存快照、失败保留、会话过期单次恢复与登出清理。
- 更多→博雅为独立列表，显示当前学期课程目录、类别与搜索；无选课按钮。正常/空/漂移/业务拒绝合成契约已入 router。Rust协议公钥/加密与缓存测试通过，Android独立smoke 1项通过（合成显示数据；不替代上游验收）。Windows及真实账号仍待验收。

## 2026-10-20：研究生学籍与培养方案执行报告

- GSMIS学籍白名单摘要与培养方案执行报告真实只读接通，报告严格使用 code==1，支持zxbg字符串/数组，逐类别/课组/课程展示要求、已获、待考核及状态；无硬编码类别学分。报告不可用时回退方案头部和课程池并明确提示，课程池不冒充毕业要求。
- 五分钟快照、单次会话恢复、失败保留；敏感学籍字段在Rust投影时丢弃，不进入桥接JSON。更多→研究生教务使用语义色与inset分组，长文字自然换行。4份执行报告合成契约与应用链路/白名单/缓存测试；真实账号与Windows仍待验收，不宣称像素一致。

## 2026-10-20：本地待办

- Rust本机文件存储、标题/日期校验、增删改与完成状态；账号由Rust会话确定，散列文件名隔离账号，演示使用独立命名空间。应用支持目录由平台插件提供，写入sync后替换；损坏文件禁止覆盖。手机更多与桌面侧栏均已接入，不联网。
- 4份合成文档契约（正常/空/漂移/无效）、CRUD/账号隔离/损坏保护应用测试通过；Flutter analyze通过。Android独立smoke覆盖新增、编辑、完成、重建页面后读取及删除。无提醒/跨设备同步；Windows未实机验收。

## 2026-10-20：校园通知

- 按API §7.3既有5条证据与CampusNoticesClient迁移公开HTML列表，经Session路由读取、五分钟快照、失败保留。标题/日期/摘要/HTTPS同站原文白名单投影，详情显示摘要并可浏览器打开官网。无已证实空标记，空HTML按结构变化处理，不伪造空通知。
- 4份合成契约（正常/空HTML/漂移/拒绝页面）、公开读取+缓存+失败保留用例通过；Android单项FFI合成smoke覆盖列表到详情，外部浏览器往返仍待人工。镜像真实上游⚠️待验收，Windows未验收。

## 2026-10-20：CGYY教学楼场馆只读

- 公开场馆目录、独立直连SSO/业务Token、MD5签名、按场馆/日期查询时段、最近20条订单真实链路与页面已接入。全程Session显式直连，不改全局路线；GET会话失效最多重建一次；五分钟快照、刷新失败保留实际日期范围。公开目录不依赖登录成功。
- 12份合成契约覆盖场馆/时段/订单正常、空、漂移与业务拒绝；签名对齐Apple固定向量，应用mock覆盖登录→公开场馆→业务登录→时段→订单→缓存/失败保留，校验WebVPN偏好下仍直连。Android cgyy_test.dart独立FFI合成smoke 1项通过；真实账号与Windows仍待验收。
- 预约Token、手机号、参与人及门锁密码不进入桥接投影；没有预约、取消、滑块或其他写入口。桌面仍首次访问才构建，并补齐博雅/研究生/通知/研讨室侧栏入口。

### 本轮状态汇总

课表已对照IOSScheduleView重构并查看浅色/深色/大字号合成截图；六个新增模块使用现有语义色/inset分组/导航按钮，独立设备smoke通过页面交互。没有为新模块宣称完整三种外观或像素验收。桌面入口已补齐，保持首次访问才构建；Windows未验收。

### 无账号公开接口探测（2026-10-20）

- macOS host经Rust真实Session/reqwest只读GET：新闻网解析5条，CGYY签名公开场馆解析7个site，通过；只记录条数，未保存正文或网页。此结果仅证明当前网络下公开接口可读，不代表Android真实账号或CGYY登录/时段/订单已验收。临时probe已删除。
- 当前正常Android APK已安装并确认登录页，ginkgo_secure_credentials.xml不存在；本轮没有输入真实凭据。真实账号验收等待用户本机登录。

## 2026-10-20：任务入口与课表重设计复核

本轮采用 [模块聚类与设计](MIRROR-EXPERIENCE-DESIGN.md)，Apple源码用于行为/协议对照，不沿用旧五Tab的信息架构。

- 手机：工作台/签到/课表/作业/预约；工作台四项任务入口带蓝/橙/靛/紫识别色，次级服务按任务分组。账户与设置首屏文字行+右上齿轮，演示同样显示；桌面设置固定侧栏底部。
- 课表：学期次级、当前周和日期为主范围；视图分段与搜索独立。课程名稳定多色，开始20pt/结束13pt/节次与地点教师分级；无时间不猜。宽屏七列与时间轴，冲突分栏，窄屏周视图有左右滑动提示；1.8倍字号回退清单。
- 作业：标题/课程/截止/提交状态分层，状态动态语义色，不再用技术写操作列表占据范围区域。
- 实际模拟器已查看合成课表浅色、深色、1.8倍字截图（/tmp/ginkgo-rework-*.png），工作台与设置深色截图；均无真实账号数据，不入库。检查发现启动过渡零宽约束和设置长路线溢出，已修正；27项widget包含首屏设置进入/返回和大字号回归。
- 课表独立设备smoke 1项通过；未重跑已知不收敛的mirror_test.dart。真实链路响应检查另记实施文档，没有保存真实页面截图。
- 这是实现迭代复核，仍非用户最终视觉验收；没有宣称像素一致、原生macOS控件或Windows通过。


### 周视图与组件交互收尾

参考 Apple [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)、[Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls) 和 [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)，用Dart/Cupertino还原导航与控件行为。课表默认周网格（用户确认），不隐藏入口；按压与滚动反馈、180ms内容淡入、220ms分组尺寸、桌面140ms悬停/焦点。减少动态效果直接跳过分组动画，规避Flutter零时长AnimatedSize布局期自重排。保持现有导航玻璃按钮，不新增装饰材质。

作业和座位的搜索/空态并入现有测试；1.8倍深色+减少动态效果覆盖课表/作业/预约。新增信息及未迁移项详见 [逐模块对照](MIRROR-MACOS-PARITY.md)。独立schedule设备smoke更新后1项通过（约2分钟），未运行mirror_test.dart。真实会话的课程/作业详情可达，仅检查状态，无真实截图。

最终合成截图 `/tmp/ginkgo-final-{light,dark,large}.png` 自查：普通字号周网格多色与时间轴可读；大字号四段文字过密，改为两行“显示方式”选择器，课程清单回退。深色时间轴由三级文字提升二级、分隔线加强。截图仅合成，未入库。

已用最终预览重新检查大字号选择器，并查看作业合成首屏（搜索、筛选、截止/提交状态、详情入口）；无真实数据。普通APK已重新构建，通过独立安装恢复正式登录入口，避免保留integration_test入口。

## 签到历史查询

Dart/Cupertino推入独立页，顶部日期行+滚轮、前后一天；查询状态与结果实际日期分开，失败保留而不混日。系统导航/返回与现有圆角分组；历史没有签到提交入口。28项widget覆盖乱序与错误保留；设备合成smoke与真实响应分别记录，不宣称历史真实通过。

签到独立Android合成smoke 1项通过，确认历史日期切换和返回保留当天。未保存真实页面。

## 图书馆预约记录

在当前预约下方提供明确“全部预约记录”入口；Cupertino大标题与返回，页码/条数为范围、日期/时段与状态为正文、上/下一页为操作；错误保留实际页码，状态只用中性文字，不误将历史标绿。沿用180ms内容淡入与减少动态效果。未展示或截图真实记录。

独立library设备smoke通过，已确认历史入口、终态文本、末页按钮禁用与返回后层级查询；29项widget通过。未跑mirror长流程。

预约记录合成首屏已截图自查（仅/tmp）：日期、状态中性展示、末页禁用；将秒级时段精简到HH:mm，避免列表噪声，原数据不改。

合成预约记录浅色及深色1.8倍字号已自查，文字与末页按钮无溢出（/tmp，不入库）；正常主入口APK重新构建安装，等待用户本机登录。


## 2026-10-20：图书馆公共统计

- 依照 API §5.5、`LibraryPublicStats.swift` 与解析测试贯通领域→独立 Cookie 会话 HTTP adapter→五分钟快照→FRB→MirrorService→Cupertino 页面；不依赖预约认证。图书馆首组入口始终显示，认证失败也能进入。
- 两校区在馆人数优先、特色阅览室人数及座位/研讨间/寄存柜空闲与总量次级；缺指标明确“官网未提供”，零值仍展示。更新时间标北京时间；刷新失败保留原数据与原时间；下拉和按钮共享请求，防止重复触发。
- 37类/118份合成契约；完整门禁137项Rust lib + 1项契约、Clippy、Flutter analyze、30项widget通过。新增页面回归覆盖预约认证失败仍可达、刷新失败保留、缺值和零值、返回。
- macOS host 使用 Rust 正式 Session/reqwest 无账号公开 GET，成功解析两校区；仅输出状态与条数，临时探针删除。此结果不替代 Android 真实网络和账号验收。60天历史/趋势没有迁移；所有上游写操作保持关闭。

Android `library_stats_test.dart` 独立合成FFI smoke 1项通过（42秒，包含浅色/深色/1.8倍字号及减少动态效果），NDK27 aarch64 bridge交叉检查通过。没有重跑mirror_test.dart，接口测试桩仅补齐新增方法。

公共统计已用合成数据目视自查浅色、深色及深色1.8倍字号（`/tmp/ginkgo-stats-{light,dark,large}.png`，不入库）；人数、余量和缺值层级清晰。深色数字与背景可区分，大字号纵向滚动无横向裁切。


### 本轮Android真实只读复验

正常登录表单建立会话后，签到历史前一天返回成功空列表；图书馆历史第一页返回10条、hasNext=false，页面进入/返回可用。空签到不替代非空历史课程验收，第一页末页不替代多页真实验收；未保存真实内容或截图，未触发上游写操作。

公开页在私有业务自动切换WebVPN后返回不可用：原adapter复制了有效路线，却没有网关Cookie。现改为复制用户原始路线偏好，使自动模式的公开会话从直连开始；明确选择WebVPN时仍尊重设置，不复制认证Cookie。应用关键回归通过、Clippy与Android交叉检查通过；设备真实复验另记。


### 启动细节优化

启动页沿用叶片标识、字标与系统分组背景，280ms一次淡入/0.98→1轻微缩放，不循环、不等待动画完成。会话仍在首帧后立即恢复，不预热Rust网络运行时；减少动态效果时直接静态显示且不显示旋转进度，大字号可滚动。新增2项widget验证恢复不等待动画与减少动态效果；连同6项会话测试共8项通过，analyze通过。产品交互保留五入口、独立Tab栈和周网格默认方案。

启动独立设备smoke 1项通过（1秒测试体）；第一次设备发现阶段模拟器断开，重启后执行一次，未重跑既有长流程。真实验收后正式signOut返回signedOut，重新连接设备后保险库XML条目数确认为0。

公共统计路线修复后，Android使用NativeMirrorService/正式Rust adapter无账号真实GET成功解析2校区（仅输出状态/条数）。正常main入口debug APK已构建并重新安装；最终设备不保留测试入口。Windows、60天趋势、非空签到历史与真实多页预约仍未验收。


## 全面核对与正确性修复（2026-10-20）

详见[MIRROR-FULL-AUDIT](MIRROR-FULL-AUDIT.md)：逐模块记录UI/接口/缓存/刷新差距，不宣称100%对齐。修复长文本截断、今天/成绩错误时隐藏旧结果、成绩请求乱序、重复刷新、清缓存后旧页面保留、bridge读取与身份变更竞争、路线切换后退出残留保存账号、认证恢复失败绕过快照、CGYY北京时间与日期取消。

门禁：139项核心lib、1项契约、1项bridge并发测试、Clippy/analyze、35项widget通过；随后单独新增清缓存页面生命周期回归1项通过（累计36项widget）。Android aarch64交叉检查通过。未重跑mirror_test.dart、未放宽断言、未再次输入真实凭据。持久化/自动刷新/提醒、BYKC已选统计、研究生视图等未迁移项保留，不冒充已修复。

新增TTL/容量/清理测试单独通过（核心累计140）；Android独立refresh_audit合成smoke通过43秒，覆盖成绩刷新及设置清理后回工作台。没有把页面合成通过算作全模块真实验收。

## 2026-10-20：设置与维护页面

设置沿用34pt大标题、原AppleSection/AppleListTile，不添加装饰卡片；账号/路线/存储/支持与更新/关于按用途分组。自检逐行显示状态图标与文字，不仅靠颜色；更新结果、时间、失败提示与原文说明分层显示，按钮运行时禁用。使用系统页面导航，减少动态效果沿用已有封装绕过AnimatedSize。设备浅/深/1.8倍字号检查结果见 MIRROR-ANDROID-ALPHA。未宣称全模块像素对齐或TalkBack完成。
