# Android Beta.2 发布与验收记录（2026-10-29）

## 版本与范围

候选版本 `0.1.0-beta.2+12`，标签计划为 `android-v0.1.0-beta.2`。Android 继续作为唯一开发目标；本版收敛跨层接口、校园服务公开请求、校园卡余额展示、工作台信息和异步状态。学校写操作协议未新增，不使用真实账号、凭据或学校写入。

公开协议与跨层接口文档分别以 [API.md](../API.md) 和 [接口索引](../INTERFACE-INDEX.md) 为事实入口。新增了就业活动月历的完整端点、参数、字段、错误分类与证据边界，并记录公开请求的 Cookie/认证头隔离规则；全量接口索引已重生成并通过新鲜度检查。

## 严重问题修复

公开就业、学术文化、通知、校车、书目/馆藏和图书馆人数读取此前共用已登录会话 Cookie 容器。Cookie Jar 会让父域票据匹配学校子域，公开请求因此可能带出登录 Cookie；公开响应也可能反向写入认证会话。新增 `Session::send_anonymous`：公开读取不发送 Cookie、`Authorization` 或 `Proxy-Authorization`，不接收/保存 `Set-Cookie`，并在独立临时会话中处理路由回退。针对父域 CASTGC 外泄、公开响应 Cookie 污染、共享路由变化添加了合成回归。

## 自动化与本机构建

| 检查 | 结果 |
| --- | --- |
| `bash scripts/check-mirror.sh` | 通过（退出码 0；包含 Rust 格式、严格 Clippy、Rust 测试、Flutter 分析与 636 项 Flutter 测试、FRB 重生成差异检查） |
| `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked` | 373 项通过 |
| `python3 scripts/generate-interface-index.py --check` 和生成器自测 | 40 份接口索引当前；2 项自测通过 |
| `git diff --check` | 通过 |
| Android 正常入口 Release 构建 | 通过：`flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub` |

Release APK：`artifacts/local/android-beta2/Ginkgo-0.1.0-beta.2-android-arm64.apk`，43,851,525 字节；SHA-256 `7c7470d2fda7a19b5f42cf3fdc72ee714e05ca6321809058c487790b6f093fad`。包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，`versionName=0.1.0-beta.2`、`versionCode=12`、`minSdk=24`、`targetSdk=36`、仅 `arm64-v8a`；Release 非 debuggable，`integration_test` 未打入，`GeneratedPluginRegistrant` 不含测试插件。`zipalign -c -P 16 -v 4` 和 `apksigner verify` 通过。

签名证书 SHA-256 为 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与已公开 Beta.1 APK 一致。构建使用本机外部签名配置；签名配置与密钥没有写入仓库。

## 模拟器与设备边界

已有 Android 37 模拟器预装的是 Beta.1 版本号的 Debug 包；Release Beta.2 APK 因签名不同被 Android 正确拒绝覆盖安装，未删除该模拟器数据。使用同一 Debug 签名构建的 Beta.2 正常入口 APK 覆盖安装成功；冷启动进入登录页，离线演示进入工作台，确认 Beta.2 不再显示近期时间线，在合成数据下显示近期考试卡片。此为 Debug 代码级模拟器冒烟，不是 Release 包覆盖升级或待办保留证据。

新建的干净 Android 37 模拟器首次启动崩溃；当前没有物理 Android 设备。因此 Beta.1 Release → Beta.2 Release 覆盖升级、待办保存、TalkBack、大字号和厂商后台行为未验收。不能将模拟器 Debug 冒烟写成真实设备或 Release 升级验收。

## 依赖安全复核

`cargo audit --file rust/Cargo.lock` 报告唯一漏洞为 `rsa 0.9.10` / [RUSTSEC-2023-0071](https://rustsec.org/advisories/RUSTSEC-2023-0071.html)，公告当前没有修复版本。当前 `bykc_http.rs` 只以 `RsaPublicKey` 执行上游协议要求的公钥加密，没有私钥解密操作；据此判断，公告描述的私钥时序恢复路径不出现在本项目当前调用链中。这是基于代码调用点的适用性分析，不代表依赖本身已修复，也不忽略该公告。继续跟踪兼容修复或经验证替代实现。

GitHub 仓库目前仅有 macOS 签名 secrets，没有 Android workflow 所需的签名 secrets；tag workflow 会按既有 fail-closed 规则拒绝无签名 CI 构建。Beta.1 也曾在该步骤失败。本版 Release APK 使用已核验且与 Beta.1 一致的本机外部签名，发布时分别记录 workflow 结果、公开资产摘要和回下载结果。

## 公开发布

待 tag、GitHub prerelease、公开 APK/校验文件回下载和 Pages 首页核验完成后补录链接、时间与远端摘要。
