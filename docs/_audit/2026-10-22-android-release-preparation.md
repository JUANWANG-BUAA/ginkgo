# Android 发包准备记录（2026-10-22）

## 结论与版本边界

**文档与发布说明已准备，签名 Release 尚未构建、安装或公开。** 本次仅整理发包材料与静态产物核验，遵照用户“测试适当”的要求，不重跑全量测试或设备矩阵。未执行 commit、tag、push、GitHub Release、官网部署或最低版本调整。

- 当前 `HEAD`：`9b58ac0a9d516495cc9843311029bb901ebead7e`，本地标签 `android-v0.1.0-alpha.6` 已指向该提交。远端公开状态本轮未查询；不能重用/移动此标签打包新工作树。
- `flutter/pubspec.yaml` 当前仍为 `0.1.0-alpha.6+7`；工作树另含 Today 2.0、作业关联待办、任务 v2、提醒生命周期与视觉精修改动，尚未冻结为新的源码提交。
- 建议下一版为 **Android `0.1.0-alpha.7+8`**，拟用标签 `android-v0.1.0-alpha.7`。这是待确认的候选标识，不表示版本配置已修改或远端不存在同名版本；实际发布前复核远端且不可覆盖既有版本。
- 用户说明草稿：[android-alpha7.md](../releases/android-alpha7.md)。未完成的发布动作只跟踪于 [MIRROR-TODO](../MIRROR-TODO.md)，本文是操作规程与当次事实，不维护第二份待办清单。

## 已有调试包：不能作为公开更新包

本轮只读核验 `ginkgo-ios-visual-debug.apk`：

| 项目 | 实测值 |
| --- | --- |
| 路径 | `flutter/build/app/outputs/flutter-apk/ginkgo-ios-visual-debug.apk` |
| 入口 / 构建 | `lib/main.dart` / ARM64 Debug（构建记录） |
| 大小 | 145,795,709 字节 |
| SHA-256 | `e5fd30da175f02df745d76c6a256c6a2a289433ad08748d585f292a6fa974e9a` |
| 包名 | `cn.edu.buaa.ginkgo.ginkgo_mirror` |
| versionName / versionCode | `0.1.0-alpha.6` / `7` |
| minSdk / targetSdk | 24 / 36 |
| 证书 DN | `C=US, O=Android, CN=Android Debug` |
| 证书 SHA-256 | `9d356bcc24985e4865d21d11a39b9256d0b84a4d652b0db5794467383cf9d39e` |

`aapt dump badging` 与 `apksigner verify --print-certs` 成功退出。历史 Alpha.5 记录中的发布证书为 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与此 Debug 证书不同；**不改名冒充Release，不上传该Debug摘要为正式checksums**。历史证书身份来源见 [Alpha.5](../archive/mirror/MIRROR-ANDROID-ALPHA5.md)，不表示新包已经复核同签名。

## 发布操作规程（尚未执行）

### 1. 冻结版本与源码

核对远端已有 tag/Release 和上一公开包的 build。若采用建议编号，将 `flutter/pubspec.yaml` 同步为 `0.1.0-alpha.7+8`；Android versionCode 必须高于旧版。确认本轮源码、fixtures、新文件与说明均纳入待发布提交，并记录其 SHA；不要从仅包含旧 Alpha.6 的 HEAD 直接打标签，也不要为本轮顺带发布 Windows/Apple。

本次已有全量 gate 的 Flutter 202项、设备原流程4项，以及最后辅助灰补丁的 Today 24/任务30项定向检查；详见两份迭代记录。仅文档修改不重复这些套件。最终签名包仍需下面的产物校验与一次覆盖启动检查，而非再扩大功能矩阵。

### 2. 正常入口签名构建

使用既有发布密钥，不创建新key，不打印签名配置或密码。Gradle 从外部 `GINKGO_ANDROID_SIGNING_PROPERTIES` 或默认 `~/.config/ginkgo/android-alpha/signing.properties` 读取配置；缺失会拒绝 Release，不能改为 Debug 兜底。此说明不验证本机密钥是否存在。

```sh
# 仓库根目录；执行前先按上节同步版本并冻结源码
set -eu
(
  cd flutter
  flutter pub get
  flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub
)
```

2026-10-23 勘误：本机Flutter 3.47生产构建勿用 `--no-pub`，它会跳过release模式插件注册器重生成，造成integration_test的dev注册残留；不能手改生成文件。后继发布见 [Alpha.7记录](2026-10-23-android-alpha7-release.md)。

不得在该构建后再运行 integration_test 覆写同名产物。Android 的 `.github/workflows/mirror.yml` 当前只构建Debug artifact，不能将其当签名发布流水线；Windows 的tag发布流程也不能用于Android。

### 3. 产物核验与整理

对 `flutter/build/app/outputs/flutter-apk/app-release.apk` 用已安装Android Build Tools执行：

```sh
# BT 指向本机实际安装的SDK build-tools版本目录，不含签名秘密
: "${BT:?请设置已安装的Android Build Tools绝对路径}"
"$BT/apksigner" verify --verbose --print-certs flutter/build/app/outputs/flutter-apk/app-release.apk
"$BT/aapt" dump badging flutter/build/app/outputs/flutter-apk/app-release.apk
```

确认普通包名、预期新版本/build、minSdk、arm64 ABI、无debuggable，并比对上一发布证书。核验通过才复制为计划资产名并生成真实摘要：

```sh
# 从仓库根运行；版本专属目录必须不存在，避免混入旧APK或checksums
set -eu
mkdir -p dist
mkdir dist/android-alpha7
cp flutter/build/app/outputs/flutter-apk/app-release.apk dist/android-alpha7/Ginkgo-0.1.0-alpha.7-android-arm64.apk
(
  cd dist/android-alpha7
  shasum -a 256 Ginkgo-0.1.0-alpha.7-android-arm64.apk > checksums.txt
  shasum -a 256 -c checksums.txt
)
```

对安装旧发布包的专用测试设备，用同签名新包覆盖并冷启动一次，确认版本递增、正常登录/演示入口和本机待办保留。若签名冲突，停止而非卸载；真实用户设备卸载会丢本机数据。检查不需要学校凭据或真实写操作。

### 4. 草稿发布与人工公开

新标签必须锚定上面的冻结提交；由维护者创建 **GitHub Draft + prerelease**，附APK、checksums和 [用户说明](../releases/android-alpha7.md)。下载草稿资产后重新核对摘要、证书与版本，再由维护者决定公开。此规程不自动执行任何远端命令。

公开后才补正式资产大小/SHA、证书、源码SHA/链接和安装结果，再同步官网/README的下载入口与“已发布”状态；本轮不预写不存在的下载链接。`docs/update-gate.json` 仍为 `minBuild: 5`，不随候选版本号提高，避免新包不可下载时锁住旧客户端。

## 数据升级与回退

v1任务可读，实际变更才原子写v2。发布说明必须保留“本机完成≠学校提交”“本机保存无云同步”“升级前备份，不能直接降级编辑”。当前无新增备份UI，维护者协助备份应用私有任务文件时须保护个人内容。v2不可用旧版继续写；回退先保留新数据副本，再由维护者评估恢复升级前备份，不能仅安装旧APK或清空任务。

## 补充：启动更新与用户说明

发包准备后追加启动更新检查：真实Android入口首帧后单次、8秒总等待上限，不阻塞登录/工作区；发现已提供APK的新版才轻提示，查看复用结果并进入既有软件更新页，下载/安装仍由用户主动操作。最低版本门禁和诊断错误提示优先，不支持的平台和显式离线测试组合不检查。源码变动后此前Debug包已不是最新工作树产物，发包必须按规程重建，不复用该包。定向验证见 [启动更新记录](2026-10-22-startup-update-hint.md)。

用户要求简短说明：Release正文及应用内更新内容按3–5条短句呈现，不放测试数/工程/打包过程；已知限制在维护记录保留。本次未执行真实学校登录或写操作，模拟器与合成测试不代表物理设备、完整TalkBack或正式签名包验收；提醒投递仍受系统省电影响，实验写操作结果不明时只能先回查，不能重复提交。任务数据升级与卸载风险在用户正文另保留简短提醒。

## 本轮文档范围

更新Release总览、Android Alpha.7用户草稿、README/Flutter README入口、镜像现状/对照及唯一待办。保留Alpha.6与历史发布事实，不更改签名逻辑、学校接口、版本配置或最低门禁；不声称当前Debug包已能覆盖公开Alpha。
