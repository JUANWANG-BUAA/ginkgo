# 全面优化准备：架构、基线与执行顺序

> 日期：2026-10-22；源码基线：9b58ac0a9d516495cc9843311029bb901ebead7e。本轮仅调研、运行现有检查和整理文档，未修改生产代码、工程配置或测试。

## 1. 结论

项目已具备多平台业务能力和自动化基础，不宜以大重写启动全面优化。建议顺序：**异步正确性与数据生命周期 → 可执行契约与发布门禁 → 有测量的性能/体验 → 按功能推进边界收敛**。静态竞态必须先用可控延迟测试复现，不把代码推演冒充用户运行故障，也不把全绿测试等同于无缺陷。

## 2. 项目地图

| 层面 | 当前实现 | 优化时保留的边界 |
| --- | --- | --- |
| Apple | Swift/SwiftUI；macOS/iOS 独立壳与页面，共享客户端、模型、解析器、缓存与 ViewModel | WorkspaceHost 按账号持有 WorkspaceCoordinator；页面按需加载，不启动全量拉取 |
| Apple 数据访问 | 课表、考试、成绩、作业、BYKC、签到、通知、研究生教务已有 Repository | 图书馆/CGYY 仍直接组合客户端；不重复已完成的仓储拆分 |
| 镜像 | Rust domain/core/upstream/runtime/bridge 五层；Flutter 功能 gateway 与基础设施分离 | 领域规则、学校协议、平台保险库、UI 保持独立；不是 Apple 替代工程 |
| 跨语言 | Swift/Rust 独立消费版本化 fixtures | Swift 只覆盖部分契约；共享数据投影，不共享实现、凭据或磁盘缓存 |
| 网络 | 直连/学校 WebVPN，无自建中转 | 不统一上游成功码、不重编码 body、不放宽 TLS；系统例外以 API.md 为准 |
| 存储 | Keychain、账号摘要文件名 JSON 缓存、UserDefaults 待办 | 摘要不等于加密，原子写不等于业务提交屏障 |

依据：docs/ARCHITECTURE.md:3–69、docs/IOS.md:3–84、docs/MIRROR-IMPLEMENTATION.md:27–48、fixtures/README.md:7–29。历史示例（如 SwiftData）不作为当前事实；DEEP-ARCHITECTURE-REVIEW.md 分析的是参考项目 UBAA。

## 3. 本轮实际运行基线

环境：Xcode 27.1（27A9275）、XcodeGen 2.46.0、Rust stable 1.99.0、Flutter 3.47.0 / Dart 3.13.0。开始时工作区干净。

| 检查 | 本轮结果 | 证据/边界 |
| --- | --- | --- |
| macOS xcodebuild test | **232 通过、0 失败、0 跳过；退出码 0** | xcresulttool summary 核实；本机 arm64 |
| iOS 共享单元测试 | **232 通过、0 失败、0 跳过；退出码 0** | Ginkgo iPhone 17 Pro / iOS 27.0；未执行 UI/live 测试 |
| bash scripts/check-mirror.sh | **完整退出码 0** | 架构检查及其回归、Rust fmt、严格 Clippy、core 无默认特性、upstream/workspace tests、Flutter analyze/widget tests |
| git diff --check | 通过 | 最终文档写入后复查 |

临时结果文件（不入库）：/tmp/ginkgo-prep-89a8-macos.xcresult、/tmp/ginkgo-prep-89a8-ios.xcresult。macOS 有多匹配 destination 警告；iOS 有系统 build 号解析警告，未阻止运行，结果包均确认通过。镜像脚本生成的单个 Python bytecode 已核对路径并清除。

```sh
xcodebuild test -project BUAA-Assistant.xcodeproj -scheme BUAA-Assistant -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet -resultBundlePath /tmp/ginkgo-prep-89a8-macos.xcresult
xcodebuild test -project BUAA-Assistant-iOS/Ginkgo-iOS.xcodeproj -scheme Ginkgo-iOS -destination 'platform=iOS Simulator,id=EE47402B-2839-4CD8-950C-92BBDA0D6CAD' -only-testing:GinkgoiOSTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet -resultBundlePath /tmp/ginkgo-prep-89a8-ios.xcresult
bash scripts/check-mirror.sh
git diff --check
```

复跑时选择本机可用 simulator 并使用新的 resultBundlePath。check-mirror.sh 含 dart pub get，不是纯离线入口。本轮没有 APK/Windows 构建、FRB 再生成、远端 CI 查询、真机/签名包/可访问性/性能采样或真实账号验收，未触发学校预约、签到等写请求。

## 4. 优先候选：证据与完成标准

P0 表示优化前应保留的质量门槛，不代表已发现线上严重事故。O1/O2 是首批实现候选（P1），必须先补失败回归。

| 优先级/编号 | 观察与证据 | 状态 | 首个可执行验收 |
| --- | --- | --- | --- |
| P1 / O1 缓存失效屏障 | Features/BYKC/BykcRepository.swift:27–38 网络返回后写盘；BykcViewModel.swift:92–111 的 generation 只在仓库返回后保护 UI。Features/Campus/CampusNoticesRepository.swift:59–71 同模式，CampusNoticesViewModel.swift:18–49 无刷新代际检查 | 静态可达：加载挂起→清缓存完成→旧结果返回，会再次写盘；通知还可能恢复 UI。未新增复现 | 注入可暂停服务，清理后释放旧响应，断言磁盘/UI 保持清理；另一账号不受影响，新请求可写入 |
| P1 / O2 提醒生命周期 | flutter/lib/reminders.dart:290–320 初始化等待后仅检查 mounted 就启动 Timer；paused 只取消当时已有 Timer | 静态可达：paused 后迟到初始化可重建轮询；未动态复现，实际频率受 OS 调度影响 | 延迟初始化→paused→释放响应→推进 fake clock，不新增学校查询；resumed 仅一组轮询，dispose 无回调 |
| P0 / O3 隐私生命周期验收 | Core/Storage/LocalStore.swift:16–33 账号摘要+明文原子写；Features/Tasks/PersonalTaskStore.swift:19–29,50–55 待办用 UserDefaults；iOS/Sources/IOSStoragePolicy.swift:3–19 只排除 Application Support 备份 | 已知策略缺口，不是已证明的数据泄漏 | 列出所有数据目录/备份/保留/清理矩阵；补测试，再评审可回滚迁移，保护待办 |
| P1 / O4 跨语言契约扩面 | fixtures/README.md:11–15 明确 Swift 未覆盖全部签到/图书馆/BYKC/研究生解析契约；Rust runner 递归执行全部 JSON | 已确认覆盖不对称，不代表已证明输出不同 | contract×consumer 支持/未覆盖原因清单；优先补拒绝、漂移、空态、未知写结果，两端消费同一输入/期望 |
| P1 / O5 发布测试闸门 | .github/workflows/release.yml:18–27,68–74 build 后创建草稿，无该工作流内测试依赖；手动 ref 直接作为版本 | 工作流级缺口；外部保护设置未查，草稿非自动公开发布 | 校验 tag/版本；同 SHA 测试失败不能进入打包并归档结果，签名安全设置留人工审查 |
| P1 / O6 最低版本门禁时序 | flutter/lib/main.dart:72–103,158–194 并行恢复/门禁，结果未返回可先构建 signedIn 工作区 | 静态时序需与产品预期确认；离线/清单失败放行是已有设计 | 延迟清单+快速恢复，明确是否应阻止首次业务请求；保留有界超时/离线放行 |
| P2 / O7 文档入口漂移 | fixtures/README.md:9 仍指向 core 契约路径，实际为 rust/crates/ginkgo_upstream/tests/contracts.rs:1,43–47 和 src/services/contracts.rs；README/镜像页存在多个平台版本口径 | 已确认入口漂移；未远端核实公开资产，不猜已发布状态。不同日期测试数量不是相互矛盾 | 修本地链接，分离源码/已发布/已验收索引；保留历史日期和原始结果 |

Swift 的 Features/Core 相对路径基于 BUAA-Assistant/；上表 iOS 路径全称为 BUAA-Assistant-iOS/Sources/IOSStoragePolicy.swift。

其他待验证：Core/Shell/WorkspaceCoordinator.swift:243–249 的 weak self 在循环内提升后跨 sleep 强持有。已有场景失活取消和 deinit 兜底，但工作区移除时显式停止是否必达仍值得验证；没有 Memory Graph 或动态复现，不能称为已实测泄漏。部分读路径未复用 RequestCancellation 分类，可补取消不报服务错误的测试，不能将写结果未知静默吞掉。

## 5. 执行批次

1. **正确性第一批**：O1/O2 分别补失败回归再最小修复，覆盖迟到响应、清缓存、账号切换和挂起；一次一个模块，不重写整个刷新体系。
2. **质量第二批**：O4/O5 + O7；契约版本、协议证据、同提交测试和产物可追溯，不用测试数量替代覆盖率。
3. **数据第三批**：O3 策略评审与迁移；区分清查询缓存/退出账号/删除全部数据，默认保护待办。
4. **性能/体验第四批**：先采样冷启动、缓存首屏、请求数、后台请求、滚动帧和内存，再优化热点；补 VoiceOver、动态字体、窄屏、深浅色及真机矩阵。没有采样不宣称已定位性能瓶颈。
5. **架构收敛后置**：按收益推进图书馆/CGYY 仓储注入及大文件职责拆分。Swift Package 不是本轮前置；macOS target 改动交维护者，iOS 仅改 spec 后生成。

**建议首个实现任务：BYKC 缓存清理与在途刷新竞态的可控回归 + 最小失效屏障。**已有可注入服务、临时目录及双 Apple 测试基线，无需账号或学校写请求；完成后再决定复用范围。

## 6. 不做与未知

- 本轮不改 CAS/TLS/Keychain/日志输出/entitlements、不统一成功码、不为学校写操作增加重试。安全四件套和写策略遵守 COLLABORATION.md:119–126 人工审查。
- 不读取真实凭据、Cookie、个人抓包内容；历史实网成功不推导当前成功，认证复验、真实写闭环及物理 Windows 冷机依赖仍独立验收。
- 本轮为文档与代表性源码抽查，非逐文件安全审计；O1/O2/O6 未新增动态回归，均未修复。暂无当前性能、全量覆盖率及远端 CI 结论。
