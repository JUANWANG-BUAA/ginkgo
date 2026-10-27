# Android Beta.1 发布准备记录（2026-10-27）

## 版本与范围

工作树版本 `0.1.0-beta.1+11`；**尚未发布**，没有对应的 tag 或 Release。公开基线仍是 Android Alpha.9（`0.1.0-alpha.9+10`，`android-v0.1.0-alpha.9`）。发布时建议标签 `android-v0.1.0-beta.1`，由 `.github/workflows/android-release.yml` 构建签名 ARM64 包并校验产物；真实设备覆盖升级与 GitHub prerelease 由维护者执行。

本轮同时推进两件事：

1. **工程收口**：按 [接口索引](docs/INTERFACE-INDEX.md) 的设计模式清理跨层问题，并把接口文档补成可执行的契约说明；
2. **宣传重制**：把仓库首页、GitHub Pages 主页与对外文案全部改成 Android 主推，界面素材换成真实 Android 截图与演示录屏。

本轮没有使用真实学校账号，没有签到、预约、取消、上传或提交。真实非空学习协议、本人借阅认证、校车实时余票与学校写操作仍未被此版本验证。

## 工程改动

### 跨层与接口

| 改动 | 位置 | 说明 |
| --- | --- | --- |
| 本机待办命令不再被登录并发丢弃 | `ginkgo_flutter_bridge` `edit_tasks` | 原实现用 `try_read()` 抢会话读锁，登录持写锁时直接返回"服务不可用"；改为等待读锁，并把阻塞式 fsync 移到 `spawn_blocking`，不占用异步工作线程 |
| 图书馆读路径的令牌恢复统一为一次重建 | `ginkgo_upstream` `library_service` | 五处重复的"取 token → 登录失效 → 作废 → 重建 → 重试"收敛为一个 `library_retry` 助手，行为不变并补回归测试 |
| upstream 命名空间去重 | `ginkgo_upstream` | 删除 `pub use codecs as features` 别名：上游内部只有 `codecs`，`features` 专指 `ginkgo_domain::features`（领域规则），消除"同名两个 features"的歧义 |
| 演示与真实命令同形 | 桥接层 | `edit_tasks` 改异步后重新生成 FRB 绑定；Dart 侧签名不变（仍返回 `Future`） |

### 门禁与文档

| 门禁 | 命令 | 作用 |
| --- | --- | --- |
| 接口索引过期检查 | `python3 scripts/generate-interface-index.py --check` | 改了公开接口却没刷新 `docs/interfaces/` 即失败；已接入 `scripts/check-mirror.sh` 与 CI |
| 设计 token 采纳预算 | `python3 scripts/check-design-tokens.py` | 硬编码 `fontSize` / `EdgeInsets` / `SizedBox` / `BorderRadius` 计数只许减不许增；已接入本地基线与 CI |
| 索引导航 | 生成器 | `docs/interfaces/README.md` 增加"新增接口先选模式"入口 |

### 接口文档

[docs/INTERFACE-INDEX.md](docs/INTERFACE-INDEX.md) 本轮重写并补全：

- 新增 [§1.1 接口设计模式](docs/INTERFACE-INDEX.md#11-接口设计模式)：把信封、端口、纯规则、粗粒度命令、写状态机、三件套、账号绑定、投影、演示同形、门禁登记十种模式写成表格（解决什么问题 / 具体形态 / 反例），并给出每个接口必须回答的四个问题；
- 新增 [§6.10 返回形态与载荷契约](docs/INTERFACE-INDEX.md#610-返回形态与载荷契约)：87 个 FFI 命令中 46 个返回类型化 DTO、41 个仍用 `ReadOnlyResponse` 载荷信封，逐个列出并写清解码位置约束；
- 新增 [§7A.5 命令与能力的命名约定](docs/INTERFACE-INDEX.md#7a5-命令与能力的命名约定)：按前缀区分读、写、回查、本机、纯规则与诊断命令；
- 新增 [§12 自动化门禁](docs/INTERFACE-INDEX.md#12-自动化门禁)：列出每道门禁拦住什么；
- 修正命令总数（原写 88，实为 87，并写明计数口径）、补齐 CGYY `order` / `lockCode` 只读查询、课程签到写路径与本机待办的输入输出说明。

全量接口清单由生成器刷新为 36 个文件、1337 条记录。

### 宣传重制（Android 主推）

| 载体 | 变化 |
| --- | --- |
| 仓库首页 `README.md` | 首屏改为 Android 下载入口 + 演示录屏 + 7 张真机尺寸截图；平台表把 Android 标为主推，macOS / iOS 明确为已冻结；移除以 macOS 为主的界面预览与 Apple 功能表 |
| 项目主页 `docs/index.html` | Hero 换成两台手机框（工作台 + 课表），主按钮直链 APK；新增"离线演示录屏"区块与 6 张手机截图墙；下载区把 Android 做成主推大卡，Windows / macOS / iOS 收进次级网格；FAQ 改为 Android 口径（安装、主推平台、写操作安全边界） |
| 视觉素材 | 新增 `docs/images/android-*.png`（7 张，1080×2400）、`docs/media/ginkgo-cold-start.mp4`（冷启动：银杏叶展开）与 `docs/media/ginkgo-android-demo.mp4`（约 20 秒，真实 Android 构建的离线演示录屏，720 宽 / 300 KB） |
| 采集方式 | 新增 `flutter/integration_test/promo_capture_test.dart`：只在离线演示模式驱动真实界面并截图，产物经 `adb reverse` 传回宿主机，不接触任何账号或学校接口 |
| 应用图标与名称 | Android 启动图标改为银杏叶（自适应图标 + 旧版位图），应用名统一为 “Ginkgo”（不再带中文后缀）；冷启动为“银杏叶展开 → 字标 → 细进度线”，底色与系统闪屏一致 |
| 对外文案 | `docs/PROMOTION.md` 全量重写：仓库 Description、topics、一句话与长介绍、社区发帖模板、社交短文案、视觉素材清单全部以 Android 为主角 |

截图与录屏全部来自离线演示模式，内容为合成样例，不含真实学号、课程或成绩。

## 验证

`bash scripts/check-mirror.sh` 通过：架构规则与自测、设计 token 预算、接口索引新鲜度、Rust 格式与严格 Clippy、core / upstream / workspace 测试、Flutter 分析、**529 项 Flutter 测试**以及 FRB 重生成零差异。测试数量只属于本次运行。

Android 模拟器（`Medium_Phone_API_37.0`，API 37，1080×2400）上的合成验证：

| 项目 | 结果 |
| --- | --- |
| `integration_test/promo_capture_test.dart` | 离线演示模式截图与录屏驱动通过，产出 7 张截图与 1 段录屏 |
| 正常入口构建 | `flutter build apk --debug --target-platform android-arm64 --target lib/main.dart` 通过；`flutter run` 冷启动进入登录页并可进入离线演示 |
| 冷启动 | 系统闪屏显示银杏叶图标（Android 12+ `windowSplashScreen*`），Flutter 侧续接“叶子展开 → 字标 → 进度线”；深色模式底色与叶子颜色随 `values-night` 切换 |
| 启动图标 | 桌面显示为银杏叶图标，应用名为 “Ginkgo”；启动图标与应用内标记同源（`design/ginkgo_mark.dart` 矢量绘制） |
| 启动路径 | 独立安装的**测试驱动包**会停在原生闪屏（AGENTS.md 已记录的既有现象）；正常入口包不受影响 |

## 仍未覆盖

- 物理 Android 设备、完整 TalkBack、预测返回、厂商省电与后台提醒恢复；
- 真实学校账号的登录复验、学习非空公告／后页／测验、本人借阅认证、校车实时余票；
- 真实签到、图书馆预约、CGYY 预约、作业上传或学校提交；
- Beta.1 的签名 Release 构建、真实设备覆盖升级与 GitHub prerelease 公开；
- Windows 主机构建与集成测试；本版公开范围只有 Android。

## 发布前检查清单

1. `bash scripts/check-mirror.sh` 全绿，且 `python3 scripts/generate-interface-index.py --check` 无差异；
2. 标签 `android-v0.1.0-beta.1` 与 `flutter/pubspec.yaml` 的 `0.1.0-beta.1+11` 一致；
3. `docs/releases/android-beta1.md` 的 3–5 条用户收益与实际包一致，不写未验收能力；
4. 真实设备覆盖升级（保留个人待办）与 TalkBack / 大字号抽检；
5. 发布后更新仓库首页与主页的下载链接（页面脚本会自动指向最新的 `android-v*` 资产）。
