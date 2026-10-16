# 宣传文案与关键词

> 用途：GitHub 仓库信息、社区发帖、社交分享的统一口径。发布时直接复制，避免各文档说法不一致。
> 当前版本：Ginkgo 0.1.0-alpha（2026-10-16）

## GitHub 仓库信息

- **仓库名**：`ginkgo`（完整地址 `github.com/JUANWANG-BUAA/ginkgo`，"BUAA"在账号名里）
- **Description（≤ 120 字符）**：
  `北航（BUAA）校园服务聚合的 macOS 原生客户端 · 课表 / 签到 / 图书馆预约 / 成绩与作业`
- **Website**：`https://juanwang-buaa.github.io/ginkgo/`（启用 GitHub Pages 后填写）
- **Topics**：
  `buaa` `beihang` `macos` `swiftui` `menubar` `campus` `schedule` `checkin` `library-booking` `student-tools` `open-source`

## 关键词

北航、BUAA、Beihang、北航助手、校园助手、macOS 客户端、SwiftUI、菜单栏、课表、课程表、签到、打卡、iclass、图书馆预约、座位预约、成绩查询、GPA、空教室、学校作业、SPOC、希冀（Judge）、校园通知、待办、内置更新、DMG 下载、原生应用、直连、隐私、本地缓存

## 一句话介绍

- **极简版**：课表、签到、预约，收进菜单栏的北航 macOS 校园助手。
- **完整版**：Ginkgo 是北航校园服务聚合的 macOS 原生客户端：课表、签到、图书馆预约、成绩与作业一站式查看；直连校内系统，账号数据只留本机。

## 长介绍（README / 仓库首屏）

> 打开就知道今天要关注什么。
>
> Ginkgo 把北航常用的几个系统收进 macOS 菜单栏：**课表**（本科/研究生周网格、学期总览、考试安排，断网看缓存）、**签到**（iclass 状态常驻核对，逐课程手动提交并回查结果）、**预约**（图书馆楼馆/分区/座位与官网实时在馆人数），另外还有成绩与参考绩点、空教室、SPOC 作业、校园通知和本机待办。
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
目前是 0.1.0-alpha，141 项测试全绿；打卡签到与图书馆预约已可用，应用内置自更新（从 GitHub Releases 检查并安装，不清本地缓存），欢迎北航同学试用和反馈。

GitHub: https://github.com/JUANWANG-BUAA/ginkgo
项目主页: https://juanwang-buaa.github.io/ginkgo/
```

**朋友圈 / 小红书短文案**：

```
写了个北航专用的 macOS 校园工作台：课表、签到、图书馆预约直接在菜单栏看完。
原生 SwiftUI，数据不上传，开源在 GitHub，北航同学自取 🌿
```

## 视觉素材

- **演示动画**：`docs/images/demo.gif`（9 个页面轮播，294 KB）
- **社交预览图（GitHub Social Preview）**：建议用 `docs/images/overview.png` 或首页 hero 截图按 1200×630 裁切
- **项目主页**：`docs/index.html`（GitHub Pages：main 分支 /docs 目录）
- 所有截图已打码姓名、学号、课程与作业标题

## 发布节奏建议

1. 建仓后先发校内渠道（班级/实验室群、北航开源社区），收集第一批试用反馈；
2. 真实写操作（预约/签到）验收完成后再发 V2EX、少数派等公开渠道；
3. 每个渠道都带 **项目主页 + GitHub** 两个链接；README 首屏保留 demo.gif 与截图，降低理解成本。
