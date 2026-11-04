# Android Beta.9 发布记录

用户在源码对齐后明确要求“收尾发包”。本轮继续沿用用户明确指令的手动发布例外，readiness 保持 `blocked`，不改为契约验收通过。

## 候选

- 版本 `0.1.0-beta.9+19`，公开标签 `android-v0.1.0-beta.9`。
- 范围仅为认证网络链及对应回归源码、协议说明；参考固定 UBAA `e8a397fc`，详见 [源码对照](2026-11-03-webvpn-captcha-source-comparison.md)。不改 Swift，不额外提交直连密码，不降低 TLS/身份/Cookie 作用域边界。
- `cargo fmt --all --manifest-path rust/Cargo.toml` 成功；`cargo check --manifest-path rust/Cargo.toml -p ginkgo_upstream --tests --offline --locked` 成功。首次不带 `--all` 的虚拟 workspace 格式化命令未找到 target，改用正确命令后成功，没有将第一次失败记为通过。
- 本轮本地没有执行测试用例、学校请求、真实账号、应用或模拟器操作。编译不能替代测试通过；既往 Beta.8/参考捕获的通过记录不外推到本候选。
- 正常 `lib/main.dart`、ARM64、外部发布签名 Release 构建成功。aapt 确认版本 `0.1.0-beta.9` / versionCode 19、正常 MainActivity、非 debuggable、仅 arm64-v8a；生产插件注册表不含 integration_test；zipalign 16KiB 校验成功。
- APK 44,245,313 字节，SHA-256 `3fed839d2393b6abf3ca46e7f8e7c1ba8d6d7d18bfa74d286341ee07cfd0c713`；apksigner 验证通过，证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245` 与 Beta.8 一致。
- 协议锁按 API 修订 115/116 与对应源码完成审查后刷新，未修改独立参考捕获；生成接口索引同步。`check-contracts.py --release` 仍明确失败：readiness blocked、候选不匹配旧验收、缺账号/设备/写入/人审等证据；没有将该结果改成通过。
- PR #4 合并至 `main`，标签和 Release 指向 `c4afc0c3f5edad5cded1352da5b536001edb430a`，2026-11-03 16:23:36 UTC 公开 prerelease；APK 与两份 basename-only 校验文件均为 uploaded。最终测试源码修订后重新执行正常 Release 构建，APK 哈希完全一致。
- 修订后 PR 的 Mirror run `41671255649` 全部通过：contracts、Android、绑定、Windows（含集成测试）；upstream 473 项测试通过、22/22 可编译已知错误变体被检出。macOS run `41671256350`、iOS run `41671255877` 通过。均为本候选的新结果，不复用首轮或 Beta.8 的通过记录。
- Pages run `41673458899` 通过，公开静态页显示 `0.1.0-beta.9`，APK/SHA/发布说明/备用入口均指向 Beta.9；线上 landing.js 继续从公开 Release 列表选择 Android 版本，公开 API 的首个 Android prerelease 已为 Beta.9。
- tag 的 Android Release run `41673728461` 在签名前按既有 readiness 门禁失败；未降级该门禁、未使用 Debug 签名、未称为 CI 签名通过。本次为用户明确指令下的本机外部签名手动发布。
- 从匿名官方直链与公开备用入口分别完整回下载 APK，均匹配上述 SHA-256；从官方直链下载的两份校验文件均验证通过。官方单连接过慢后改为多连接完成，未用本地上传副本冒充回下载。对官方回下载 APK 再次验证 versionName/versionCode、MainActivity、ARM64、非调试、同证书签名与 16KiB 对齐，全部通过。
- 合并提交上的 Mirror run `41673461290` 的 contracts、Android、绑定、Windows 全部通过；main macOS run `41673461360` 通过，iOS 的 PR 候选结果已通过，main 重跑结果独立保留。文档收尾提交不改变已发布 APK 或标签，不将缺失的现场验收改为通过。

## 首轮远端回归

PR #4 的首轮 Mirror contracts（run 41668995721）为 466 通过、7 失败，未据此公开草稿。逐项处理：UC 落地页状态测试固定直连路线，避免 Automatic 的 483 路线回退消耗模拟响应；恢复失败 transport 补上 CAS 500 后独立 UC 状态 503，保留单次密码提交和冷却隔离断言；生命周期逐请求 Cookie 断言按 UBAA 插入/替换顺序调整，并区分冷恢复后模块 Cookie 重新签发前后的位置。未放宽请求比对，未修改独立参考捕获。Android 构建与绑定 job 首轮通过；修订后以新 CI 结果为准。

## 保留边界

发布时物理设备、验证码实机成功、冷恢复、学校写入及维护者安全审查尚未完成；不提升 `minBuild`，不修改旧版本发布记录为本轮通过。自动 tag 发布仍受既有 release 门禁约束，手动签名产物不称为 CI 签名通过。后续登录结果见下节，其他未覆盖项不变。

## 用户确认与网络冻结

2026-11-03 用户在交付后明确反馈：“现在呢，登录成功了，先把我们废了这么大劲的网络部分冻结，让后续的 agent 别再乱改了”。该反馈承接 Beta.8 仅 WebVPN/验证码故障与 Beta.9 交付，记为用户报告的真实登录成功，关闭唯一 TODO 中对应登录阻断；未要求重新登录，未获取账号、Cookie、验证码或日志。没有额外报告设备型号、其他路线、冷启动恢复、业务模块或学校写入结果，不扩大验收范围。

按用户明确指令，以已发布 Beta.9 `c4afc0c3f5edad5cded1352da5b536001edb430a` 冻结共享网络与认证链，规则见 [NETWORK-FREEZE](../NETWORK-FREEZE.md)。根与 upstream 目录的 AGENTS 规则限定修改授权；64 个实现/回归/参考/依赖文件从固定提交读取字节建立哈希清单，本地基线与 Mirror CI 接入冻结检查和反例测试。此变更不修改任何网络运行代码，不刷新协议锁、不移动发布标签、不改总体 readiness。门禁自身的本地检查和 8 项反例测试通过；不将其表述为重新执行全部运行时测试。
