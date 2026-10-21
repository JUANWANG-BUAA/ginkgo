# 宣传首页改版（2026-10-21）

本轮只调整静态宣传页与宣传口径，没有部署或推送。平台事实依据 `MIRROR-ANDROID-ALPHA.md`、README、iOS 文档与公开 GitHub Releases；不表示 Android / Windows 已完成与 Apple 客户端的功能对齐。

## 信息与视觉

首页主任务是了解产品并选择平台。首屏采用“校园日常，有个好安排。”，配真实 macOS 周课表截图。功能介绍按出门前、学习安排、自习空间组织；完整功能清单与技术实现留在项目文档。界面区展示今天、学期总览、研究生教务，标明 macOS、深色模式、开发截图和已打码范围。

平台入口明确区分：macOS 已发布 Alpha 的 DMG / ZIP、Android arm64 APK Alpha、iOS / iPadOS 源码构建、Windows x64 单文件安装器 Alpha，并保留便携 ZIP。Windows 与 Android 均连到各自独立 Release，并提供校验和与第三方备用入口；iOS 没有虚构商店链接。保留原有 `#top`、`#features`、`#screenshots`、`#privacy`、`#start`、`#android`、`#windows`、`#disclaimer` 锚点；Mac、Android 与 Windows 都使用已核对的静态发布资产，不依赖 GitHub API 才能直接下载。

使用 serif-editorial-console 的 retreat 页面语法、forest 自然色、spacious 密度与浅色页面。主要层级来自字号、留白与边线。阅读段落使用本机衬线字体，控制与导航使用系统无衬线，版本使用等宽字体；不请求外部字体。CSS 与脚本拆为 `landing.css` / `landing.js`，无需框架与构建。首页不再加载循环 GIF、滚动显隐脚本或重复的大量截图；首屏课表优先加载，下方图片延迟加载并声明宽高。

`images/ginkgo-mark.svg` 是网页使用的本地银杏品牌图形，不替换应用图标。

## 参考网站

以下为 2026-10-21 实际读取官网后提炼的信息结构，仅参考组织方法，未复制其文案或视觉素材：

- [LocalSend](https://localsend.org/)：首屏的一句用户价值、明确下载入口、跨平台说明和简短使用流程。Ginkgo 采用清楚的首屏任务与平台入口，避免虚构下载量或成熟度。
- [Ente Photos](https://ente.com/)（`ente.io` 重定向）：以产品画面呈现用途，把跨平台、隐私与开源放在用户能理解的层次。Ginkgo 使用真实已打码截图与可查阅的隐私说明，没有借用他人的评价或认证。
- [Joplin](https://joplinapp.org/)：下载与使用场景先行，再解释设备覆盖和数据所有权。Ginkgo 据此把场景和平台状态提前，工程细节交给文档入口。

## 验证结果

自动检查：

- `node --check docs/landing.js` 通过。
- HTMLParser 检查页面 ID 唯一、内部锚点全部存在、本地样式 / 脚本 / 图片文件存在，通过。
- Serif Enforcer：`validate_serif_output.py --dir docs --archetype retreat --json`，0 违规、0 警告。另按技能规则人工检查字体分工、面板边线、中文主语言与英文产品名标记、没有循环装饰动画。
- `check_contrast.py --css docs/landing.css`：6 对配色全部通过，正文与页面对比度 12.56:1，次级正文与面板 6.48:1，按钮前景与主色 6.61:1；加查交互边线与面板 3.27:1。
- Node VM 合成发布响应检查：更新的 Android 版本不会替换 Mac 下载；不可信外域资产被拒绝；GitHub API 失败保留静态下载。仅合成数据，不涉及校园账号。
- `git diff --check` 通过。

本地浏览器交互与人工视觉检查（Chromium / Playwright CLI，`python3 -m http.server 8766 --bind 127.0.0.1 --directory docs`）：

- 1440×1000 桌面、390×844 手机已截图并目视检查；320、768、1024、1440 宽度均无横向溢出。
- 移动导航可展开；Esc 关闭并回焦到导航摘要；选择锚点关闭导航。
- 截图链接打开原生 dialog；Esc 关闭，焦点回到触发截图链接；无 JS 时原链接仍可直接查看图片。Windows 入口使用离线演示截图，不包含真实账号、课程或个人内容。
- `prefers-reduced-motion: reduce` 时滚动为 `auto`、按钮过渡为 `0s`。
- 控制台 0 错误、0 警告；首屏本地资源正确加载。
- GitHub Releases 实际核对：macOS `v0.1.0-alpha.7` 的 DMG / ZIP / checksums、Android `android-v0.1.0-alpha.4` 的 APK / checksums 与 Windows `windows-v0.1.0-alpha.4` 的 x64 安装器 / 便携 ZIP / checksums 均存在。安装器静默安装与卸载由 Windows CI 验证；页面验收不替代真实设备安装。

本地截图在未跟踪的 `output/playwright/ginkgo-landing-{desktop,mobile,platforms}.png`，未作为新的个人账号素材入库。未验证 Safari / Firefox、真实读屏或线上 GitHub Pages 部署；浏览器检查不代表 Android / Windows 客户端验收。


## 发布前复核

主代理重新以 Playwright 打开手机390×844和桌面1440×1000，并亲自查看两张页面截图（仅/tmp）。两种宽度无横向溢出；Android官方APK与第三方加速各自保持准确链接，未链接未发布Alpha2。HTML 24个ID唯一、59处链接/本地资源检查通过，JS语法通过；重新运行enforcer为0违规0警告，6对对比度通过。此次主页变更仅包含docs静态资源，不把网站测试等同客户端验收。
