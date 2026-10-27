# 宣传文案与关键词

> 用途：GitHub 仓库信息、社区发帖、社交分享的统一口径。发布时直接复制，避免各文档说法不一致。
> **Android 是当前唯一主推平台**：公开版本 Ginkgo 0.1.0-alpha.9（build 10，2026-10-26 已发布），工作树 0.1.0-beta.1+11（未发布）。Windows 0.1.0-alpha.6（build 7，共用工程、不再排期）；macOS / iOS 已冻结（macOS 停在 0.1.0-alpha.7）。下方所有对外文案都以 Android 为主角，冻结平台只在"其它平台"一句带过。

## 当前口径（2026-10-27，Android 主推）

**核心介绍**：手机上的北航校园工作台。打开就知道今天要关注什么——课表、作业、签到、图书馆座位、研讨室与校园服务，收进一个 Android 应用；免费开源，学校请求不经过项目自建中转服务器。

| 平台 | 状态与入口 |
|------|----------------|
| **Android** | **主推**。0.1.0-alpha.9（build 10），Android 7.0+ / arm64 APK；工作台、课表、作业、签到、图书馆、研讨室、空教室、博雅、研究生教务与学分地图、SPOC 学习、本人借阅、校车时刻表、校园通知、本机待办；应用内更新支持断点续传与安装包校验。真实认证与学校写入仍待人工验收 |
| Windows | 与 Android 共用同一 Flutter 工程，只保证可编译、不再排期。0.1.0-alpha.6（build 7），单文件安装器 + 便携 ZIP；安装器未签名，SmartScreen 可能拦截 |
| macOS / iOS | 已冻结。保留 Swift/SwiftUI 源码与归档文档，不再功能开发、不再排期；对外只说明"历史版本" |

下载链接指向 `android-v0.1.0-alpha.9` 与 `windows-v0.1.0-alpha.6`；页面上的版本号与下载地址会在发布新 `android-v*` 标签后自动指向最新包。国内下载速度仍取决于 GitHub 连通性，页面提供第三方代理备用入口并提示核对 SHA-256。避免用“四端功能完全一致”“全平台已稳定”概括当前状态，也避免把尚未验收的学校写入说成可用。主页与 README 的界面素材全部来自 **Android 离线演示模式**（合成数据，无真实账号与个人课程），另有 20 秒演示录屏。

## 命名与品牌

- **仓库名 / 应用显示名**：`Ginkgo`（北航校园工作台）；应用内标题、登录页与通知文案已统一为 Ginkgo。
- **Android 标识**：`cn.edu.buaa.ginkgo.ginkgo_mirror`；旧 macOS 标识 `com.buaaassistant.app`、钥匙串 service `com.buaaassistant.credentials` 与本机缓存目录保留，避免老用户丢数据。

## 免责声明（发帖时请附上）

> Ginkgo 是非官方个人开源项目，与北京航空航天大学及其任何部门无隶属、合作或授权关系。项目仅出于个人学习与自用目的直连学校公开服务，不提供破解或绕过风控的能力；数据以学校官方渠道为准；使用者应遵守学校服务条款并自行承担使用风险。代码按 MIT 许可“按原样”提供。

## GitHub 仓库信息

- **仓库名**：`ginkgo`（完整地址 `github.com/JUANWANG-BUAA/ginkgo`，"BUAA"在账号名里）
- **Description（≤ 120 字符）**：
  `北航校园工作台 · Android 主推（课表/作业/签到/图书馆/研讨室）· Flutter + Rust · 直连校内系统，无项目自建中转`
- **Website**：`https://juanwang-buaa.github.io/ginkgo/`
- **Topics**：
  `buaa` `beihang` `android` `flutter` `rust` `campus` `schedule` `checkin` `library-booking` `graduate` `student-tools` `open-source` `windows` `macos` `ios`

## 关键词

北航、BUAA、Beihang、北航助手、校园助手、Android 应用、Flutter、Rust、课表、课程表、签到、打卡、iclass、图书馆预约、座位预约、研讨室预约、CGYY、门锁密码、研究生教务、培养方案、学分地图、博雅、成绩查询、GPA、空教室、学校作业、SPOC、校园通知、待办、应用内更新、APK 下载、直连、隐私、本地缓存、开源

## 一句话介绍

- **极简版**：把北航的一天，装进手机。
- **完整版**：Ginkgo 把北航课表、作业、签到、图书馆座位与研讨室收进一个 Android 工作台；免费开源，直连学校系统，不经过项目自建中转服务器。

## 长介绍（README / 仓库首屏）

> 打开就知道今天要关注什么。
>
> Ginkgo 把北航常用的几个系统收进一个 Android 应用：**课表**（周视图与当日清单、学期与周次、考试安排）、**作业**（SPOC 列表与详情、截止倒计时、个人文件提交需确认）、**签到**（iclass 状态逐课核对，手动提交并回查）、**预约**（图书馆座位与在馆人数、教学楼研讨室 CGYY 与门锁密码），另外还有成绩与参考绩点、研究生教务学分地图、博雅课程、空教室、SPOC 学习、本人借阅、校园通知和本机待办。
>
> Flutter + Rust 同一套工程，手机底部标签导航、平板与宽屏自动展开为侧栏。查询在设备进程内直连学校系统或经北航官方 WebVPN，不经过项目自建中转服务器；密码可选存入 Android Keystore，个人待办按账号保存在本机。普通查询快照目前主要在进程内保留，不宣传重启后的完整离线能力。

## 社交分享文案

以下标题与模板仅在 Beta.1 对应 prerelease 公开后使用。

**论坛标题（V2EX / 少数派 / 北航社区）**：

```
[开源] Ginkgo：把北航的一天装进手机，Android Beta 公开试用
```

**Beta.1 正文模板（仅在对应 prerelease 公开后使用）**：

```
分享一个自己写的北航校园助手：Ginkgo（Android，Flutter + Rust 写的）。

它把北航常用的系统聚合成一个手机应用：
- 工作台：当天课程、签到状态、近期作业和个人待办
- 课表：周视图 / 当日清单、学期与周次切换、考试安排
- 作业：SPOC 列表与详情、截止倒计时，个人文件提交前会先让你确认
- 预约：图书馆座位、教学楼研讨室（CGYY）与空教室
- 还有成绩、博雅、研究生学分地图、SPOC 学习、校园通知和本机待办

查询直连学校系统，必要时走北航官方 WebVPN，不经过项目自建中转服务器；密码只有你勾选才存进 Android Keystore。

首个 Beta 版 0.1.0-beta.1（Android 7.0+ / ARM64）已公开。签到、预约和作业提交都会先请你确认，结果不明时只回查、不自动重发；部分真实写入和设备场景仍在验收，请以学校记录为准。反馈请不要附密码、Cookie、真实学号或未打码截图。

GitHub: https://github.com/JUANWANG-BUAA/ginkgo
项目主页（含截图与演示录屏）: https://juanwang-buaa.github.io/ginkgo/
```

**朋友圈 / 小红书短文案（Beta 发布后使用）**：

```
写了个北航专用的 Android 校园工作台：课表、作业、签到、图书馆座位一个应用看完。
Flutter + Rust 写的，直连学校系统，不经过项目自建中转服务器；开源在 GitHub，北航同学自取。
首个 Beta 公开试用中，重要信息请以学校官方记录为准。
（非官方项目，与学校无隶属关系；使用请遵守学校相关服务条款）
```

## 视觉素材

- **Android 原始截图**（1080 × 2400，离线演示合成数据，无个人信息）：
  `docs/images/android-today.png`（工作台）、`android-schedule.png`（课表）、`android-homework.png`（作业）、`android-checkin.png`（签到）、`android-reservations.png`（预约）、`android-cgyy.png`（研讨室）、`android-library.png`（图书馆）
- **页面优化图**：对应的 `android-*-640.webp` 用于页面展示，原始 PNG 保留作放大预览与下载。
- **演示录屏**：`docs/media/ginkgo-android-demo.mp4`（约 20 秒，真实 Android 构建的离线演示模式）与 `docs/media/ginkgo-cold-start.mp4`（冷启动品牌动画）。
- **应用图标**：Android 启动图标为银杏叶（自适应图标 + 旧版位图），应用名统一为 “Ginkgo”。
- **生成方式**：`flutter/integration_test/promo_capture_test.dart` + `scripts/capture-android-module-visual.py`（仅隔离模拟器、仅离线数据）。
- **社交预览图**：`docs/images/ginkgo-android-social.png`（1200 × 630）；首页 OG 与 Twitter 大图均指向该素材，GitHub Social Preview 也可复用。
- **项目主页**：`docs/index.html`（GitHub Pages：main 分支 /docs 目录）；主打 Android 下载与三步安装，含 Beta 边界、脱敏反馈、演示录屏和截图灯箱。
- 冻结平台的旧截图仍留在 `docs/images/`，仅作历史对照，不用于对外宣传

## 发布节奏建议

1. 先发校内渠道（班级/实验室群、北航开源社区），收集第一批试用反馈；
2. 真实写操作（签到/预约/提交）验收完成后再发 V2EX、少数派等公开渠道；
3. 每个渠道都带 **项目主页 + GitHub** 两个链接；README 首屏保留演示录屏与 Android 截图，降低理解成本；
4. 每次 Android 发布后同步更新：仓库 Description、README 顶部下载链接、主页版本号（自动）、[docs/RELEASE-NOTES.md](RELEASE-NOTES.md) 与 [docs/releases/](releases/)。
