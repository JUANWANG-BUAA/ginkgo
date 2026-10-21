# 宣传文案与关键词

> 用途：GitHub 仓库信息、社区发帖、社交分享的统一口径。发布时直接复制，避免各文档说法不一致。
> macOS 当前版本：Ginkgo 0.1.0-alpha.7（2026-10-19）；Android 与 Windows 0.1.0-alpha.4（build 5）已发布。下方社区发帖模板面向 macOS，跨平台宣传以本节口径为准。

## 当前首页口径（2026-10-21）

**核心介绍**：校园日常，有个好安排。Ginkgo 把课表、作业、成绩与校园服务收进一个日常工作台，为北航同学而做，免费开源，账号数据保存在本机。

| 平台 | 首页状态与入口 |
|------|----------------|
| macOS | 已发布 Alpha，macOS 14+，DMG / ZIP 下载 |
| Android | Alpha.4，Android 7.0+ / arm64 APK；课表、作业、博雅与校园服务；设置、返回手势、课程范围与应用内更新已收口；签到及图书馆真实写入仍待验收 |
| iOS / iPadOS | iOS 17+，原生工作台，从源码使用 Xcode 构建；暂无 App Store / TestFlight 入口 |
| Windows | Alpha.4 首发，Windows 10 / 11 x64 ZIP；宽屏侧栏、窄屏底部导航、Credential Manager 合成往返和桌面导航已通过；包未签名，物理 x64、干净系统运行依赖与真实业务仍待验收 |

首页默认链接已指向 `android-v0.1.0-alpha.4` 与 `windows-v0.1.0-alpha.4`，正式包和校验和已公开。Android 应用内更新支持 GitHub 官方入口、暂停续传和安装包校验；Windows 需完整解压后运行，不能只复制 exe，包未签名时 SmartScreen 可能拦截。博雅选退课、CGYY 写入、作业提交与附件下载仍未迁移；避免用“四端功能完全一致”“全平台已稳定”概括当前状态。主页使用脱敏 macOS 截图与离线演示 Windows 截图，并在平台入口说明范围；不使用虚构下载量或用户评价。首页设计参考与验证见 [LANDING-REDESIGN-2026-10-21.md](LANDING-REDESIGN-2026-10-21.md)。

## 命名与品牌

- **仓库名 / 应用显示名**：`Ginkgo`（北航校园工作台）；应用内叉栏、菜单栏、窗口标题、登录页与通知文案已统一为 Ginkgo。
- **内部标识保留旧名以兼容历史数据**：bundle id `com.buaaassistant.app`、钥匙串 service `com.buaaassistant.credentials`、本机缓存目录 `~/Library/Application Support/BUAA-Assistant/`。改掉它们会让用户丢失已保存密码与缓存，因此不动。
- **Xcode 工程名**（`BUAA-Assistant.xcodeproj`、`BUAA-AssistantTests/`）保留；App target 的**产物名已改为 `Ginkgo.app`**（`PRODUCT_NAME = Ginkgo`，应用菜单/Finder/窗口标题均显示 Ginkgo），而 Swift 模块名固定为 `BUAA_Assistant` 以兼容测试导入。

## 免责声明（发帖时请附上）

> Ginkgo 是非官方个人开源项目，与北京航空航天大学及其任何部门无隶属、合作或授权关系。项目仅出于个人学习与自用目的直连学校公开服务，不提供破解或绕过风控的能力；数据以学校官方渠道为准；使用者应遵守学校服务条款并自行承担使用风险。代码按 MIT 许可“按原样”提供。

## GitHub 仓库信息

- **仓库名**：`ginkgo`（完整地址 `github.com/JUANWANG-BUAA/ginkgo`，"BUAA"在账号名里）
- **Description（≤ 120 字符）**：
  `北航校园工作台 · macOS / iOS 原生客户端 · Android / Windows Alpha · 课表 / 作业 / 成绩 / 校园服务`
- **Website**：`https://juanwang-buaa.github.io/ginkgo/`（启用 GitHub Pages 后填写）
- **Topics**：
  `buaa` `beihang` `macos` `ios` `android` `windows` `flutter` `rust` `swiftui` `menubar` `campus` `schedule` `checkin` `library-booking` `graduate` `student-tools` `open-source`

## 关键词

北航、BUAA、Beihang、北航助手、校园助手、macOS 客户端、iOS、SwiftUI、菜单栏、课表、课程表、签到、打卡、iclass、图书馆预约、座位预约、研讨室预约、CGYY、研究生教务、培养方案、学分地图、博雅、成绩查询、GPA、空教室、学校作业、SPOC、希冀（Judge）、校园通知、待办、内置更新、DMG 下载、原生应用、直连、隐私、本地缓存

## 一句话介绍

- **极简版**：课表、签到、预约，收进菜单栏的北航 macOS 校园助手。
- **完整版**：Ginkgo 是北航校园服务聚合的 macOS / iOS 原生客户端：课表、签到、图书馆座位与教学楼研讨室预约、成绩、作业、研究生教务与博雅一站式查看；直连校内系统，账号数据只留本机。

## 长介绍（README / 仓库首屏）

> 打开就知道今天要关注什么。
>
> Ginkgo 把北航常用的几个系统收进 macOS 菜单栏与 iOS 工作台：**课表**（本科/研究生周网格、学期总览、考试安排，断网看缓存）、**签到**（iclass 状态常驻核对，逐课程手动提交并回查结果）、**预约**（图书馆座位与官网实时在馆人数，教学楼研讨室 CGYY），另外还有成绩与参考绩点、研究生教务学分地图、博雅课程、空教室、SPOC 作业、校园通知和本机待办。
>
> SwiftUI 原生编写、无第三方依赖；只直连学校系统，不经过任何第三方服务器，密码可选存入钥匙串，查询缓存按账号隔离且可一键清除。

## 社交分享文案

**论坛标题（V2EX / 少数派 / 北航社区）**：

```
[开源] Ginkgo：北航校园工作台，把课表/签到/图书馆预约收进 macOS 菜单栏
```

**正文模板**：

```
分享一个自己写的 macOS 原生小工具：Ginkgo（北航校园工作台）。

它把北航的几个常用系统聚合进菜单栏：
- 课表：本科/研究生周网格、学期总览、考试安排，断网看缓存
- 签到：iclass 状态常驻核对，逐课程手动签到并回查结果
- 预约：图书馆楼馆/分区/座位，附官网实时在馆人数
- 还有成绩与参考绩点、空教室、SPOC 作业、校园通知、本机待办

SwiftUI 原生，无第三方依赖；只直连学校系统，账号数据只留本机。
目前是 0.1.0-alpha.7，212 项测试全绿；打卡签到与图书馆预约已可用，应用内置自更新（从 GitHub Releases 检查并安装，不清本地缓存），欢迎北航同学试用和反馈。

GitHub: https://github.com/JUANWANG-BUAA/ginkgo
项目主页: https://juanwang-buaa.github.io/ginkgo/
```

**朋友圈 / 小红书短文案**：

```
写了个北航专用的 macOS 校园工作台：课表、签到、图书馆预约直接在菜单栏看完。
原生 SwiftUI，数据不上传，开源在 GitHub，北航同学自取 🌿
（非官方项目，与学校无隶属关系；使用请遵守学校相关服务条款）
```

## 视觉素材

- **演示动画**：`docs/images/demo.gif`（10 个页面轮播：今天、课表、学期总览、作业、图书馆、空教室、签到、研究生教务、博雅、研讨室）
- **社交预览图（GitHub Social Preview）**：建议用 `docs/images/overview.png` 或首页 hero 截图按 1200×630 裁切
- **项目主页**：`docs/index.html`（GitHub Pages：main 分支 /docs 目录）；已适配手机端（响应式布局、移动端按钮堆叠），并含免责声明区块
- 所有截图已打码姓名、学号、课程、作业与培养方案信息

## 发布节奏建议

1. 建仓后先发校内渠道（班级/实验室群、北航开源社区），收集第一批试用反馈；
2. 真实写操作（预约/签到）验收完成后再发 V2EX、少数派等公开渠道；
3. 每个渠道都带 **项目主页 + GitHub** 两个链接；README 首屏保留 demo.gif 与截图，降低理解成本。
