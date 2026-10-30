# 全量审查与债务消除（2026-10-30）

## 范围

在规则归口与分层收口之后，再做一轮全量审查，逐项消除还影响开发的死代码、重复实现和展示层缺口。只做审查与修复，不改变学校协议，不使用真实凭据，不执行学校写操作。

## 安全与依赖健康

- `cargo audit --file rust/Cargo.lock` 仍报告 `rsa 0.9.10` / RUSTSEC-2023-0071（Marvin 攻击），公告没有修复版本。当前博雅适配只用 `RsaPublicKey` 做公钥加密，没有私钥解密路径，因此公告描述的解密时序侧信道不落在本项目的执行路径上；保留跟踪，不做静默忽略，不为了清报告而换掉加密实现。
- `cross_file` 由传递依赖改为直接依赖：文件选择端口在 `application/` 需要它，而不是靠 `file_selector` 把插件拖进应用层。

## 死代码

- 删除 `foundation/snapshot_persistence`（含 `SnapshotBook`）：查询快照按分层归 upstream，该模块无人使用。
- 删除 `foundation/cookie.rs::cookie_value`：唯一一个没有任何调用方的 `pub fn`，移除后 upstream 381 项测试通过。
- 扫描整个 Rust workspace 的 `pub fn`，只有这一个零调用项。

## 展示层缺口

`CupertinoPageScaffold` 只负责为子节点去掉顶部内边距；没有 `SafeArea` 时，页面内容可以延伸到系统手势区（底部 home indicator）。21 个页面文件此前完全没有 `SafeArea`，`MaintenanceScaffold` 也用硬编码 `SizedBox(height: 96)` 代替。现在统一在 `child:` 里补 `SafeArea`，并保留既有顶部导航结构，不重复加顶部 padding。

新增 `flutter/test/safe_area_coverage_test.dart`，锁定任务页、维护脚手架与网络诊断页的 sliver 都位于 `SafeArea` 内。

`GinkgoIconTile.semanticLabel` 只有 3 处未传值，这些图标均紧邻说明文字，且未标注的 `Icon` 不会被 TalkBack 朗读，因此不构成新的读屏缺陷。

“已更新”横幅在 Flutter 侧不存在：全仓库只有提醒控制器的一条提示文案，没有逐页不同的成功色，因此 `docs/MIRROR-TODO.md` 中“专项排查 Flutter 侧已更新横幅配色”一条可以关闭，不存在 macOS 那种同语义不同色。

## 边界评估

- `MirrorService` 聚合接口：页面只依赖窄网关（`BykcGateway`、`NoticeGateway` 等），聚合接口只在组合根与测试替身使用；`Fake` 已提供空实现，替身按需覆写，因此不需要拆分。
- `platform/` 现在只有更新与系统设置相关文件，没有混入呈现或网络抓取，不需要再迁出。
- `features/library`/`features/cgyy`/`features/settings` 目录拆分与目录命名统一不做：仓库约定不以文件搬迁代替依赖解耦。

## 验证

- 完整 `bash scripts/check-mirror.sh` 通过（Rust 全量、严格 Clippy、格式、架构门禁与自测、design token 预算、接口索引同步、FRB 二次生成零漂移、639 项 Flutter 测试）。
- 正常 `lib/main.dart` 入口的 Android ARM64 Debug APK 构建成功。

## 未覆盖边界

- 真实账号、物理设备与学校写入仍未执行。
- `rsa` 公告保留跟踪，不做静默忽略。
- `GinkgoIconTile` 三处未标注的图标依赖相邻文字，未逐一加标签。
