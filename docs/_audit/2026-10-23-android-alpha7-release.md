# Android Alpha.7 发布记录（2026-10-23）

## 范围与发布边界

用户要求检查代码、同步文档、维护功能和接口协议文件、提交、push并发新Release。本轮仅发布Android，版本 `0.1.0-alpha.7+8`，标签 `android-v0.1.0-alpha.7`；不移动Alpha.6，不发布Apple/Windows，不提高update-gate.json的minBuild（仍5）。远端核对Android/Windows最新均Alpha.6，新Android标签未占用。

包含Today 2.0／作业转待办／启动更新提示，以及工作台减负、待办精简、账号级常用入口、7组强调色、栏目动效、CGYY预约／取消／强读核实／跨重启保护。学校写操作仍逐次人工触发，本轮未用真实学校账号或发送任何预约取消。

**已公开 prerelease**：2026-10-23 00:34:01北京时间（GitHub published_at为2026-10-22T16:34:01Z）。历史未发布审计是当时事实，不重写历史；后续文档提交不移动冻结的源码tag。

## 检查与修复

独立review分别检查CGYY核心／会话／Flutter和工作台／任务／偏好／动效，未发现确认的P0/P1，确认并修复两项P2：

- 深色强调色的实心按钮沿用白字，对比不足。统一按深浅variant亮度选黑白前景；实际CupertinoButton.filled的7色×深浅AA（4.5:1）回归通过。
- 核对／选项页GET401反复用旧token不能就地恢复。仅只读GET在身份代次保护下renew一次，不对草稿、captcha/check、submit或cancel POST重放；定向回归结果收尾记录。

当前功能与客户端契约统一维护在 [功能与接口协议](../FEATURES-AND-PROTOCOLS.md)，学校端点／参数／成功码仍以 [API](../API.md) 为唯一证据源；未完成事项只放MIRROR-TODO。

## 验证与签名产物

冻结业务源码后 `bash scripts/check-mirror.sh` 完整通过：架构5项、Rust fmt/clippy/最小core/上游/workspace，Flutter analyze无问题、272项测试通过；upstream lib231，CGYY booking41项（其中新增只读续期9项），原写POST未知结果矩阵保留。日志 `/tmp/ginkgo-alpha7-final-gate.log`。

Release初次因GeneratedPluginRegistrant引用integration_test而Gradle排除dev plugin编译失败。根因是本机Flutter 3.47/Dart3.13中 `--no-pub` 连带跳过生产模式平台插件重生成；单独pub get按非release生成，clean不足以修复。改用 `flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub`，让工具生成正确生产注册器；不手改生成文件、不将测试依赖移到生产、不改全局SDK。失败产物不上传。上述 `--pub` 命令实际exit 0，生成正常main入口Release（日志 `/tmp/ginkgo-alpha7-release-build.log`），生成注册器已不含integration_test；未更改任何签名／依赖类别／全局SDK。

沿用外部既有签名配置，不打印／提交密钥密码，不回退Debug证书。实际核验：包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，versionName `0.1.0-alpha.7`、versionCode `8`、仅arm64-v8a、minSdk24／target36、`apkanalyzer manifest debuggable=false`、v2签名验证通过、`zipalign -c -P 16 -v 4` exit 0。证书SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与官方下载Alpha.6一致。

新建专用API37 ARM64模拟器，不动已有Medium_Phone或其数据。先离线安装官方Alpha.6（APK摘要 `481c6831c35d34fdd092a2cb406c8ce1dd2bd60445f9292c389bac7a771033fd` 已核对GitHub资产digest），经正常main离线演示创建 `Ginkgo_Alpha7_upgrade_sentinel`，确认可见；`adb install -r`新签名包Success，没有卸载／清数据。更新系统overlay消失后正常入口为登录页，再进入离线演示，工作台实际读出同名待办。包管理核对build8、firstInstallTime保留、lastUpdateTime更新；是一次实际签名包覆盖验收，不是widget或Debug代替。截图保存在本机artifacts/local/android-alpha7/，只含合成数据。

环境排错：旧avdmanager为新AVD外层ini写成target=android-0，使API3/QEMU无HVF而崩溃；仅修新专用AVD目标为android-37.0后读回API37/enable-hvf且boot=1，未动原设备。网络关闭、没有凭据或学校调用。

现有合成回归详见 [CGYY写流程](2026-10-22-android-cgyy-write-flow.md) 与 [工作台精修](2026-10-22-android-workspace-polish.md)。

## 公开与下载

签名资产 `Ginkgo-0.1.0-alpha.7-android-arm64.apk`，SHA-256 `7ae0a8f7d467cfd06866c7e431d40ecf32d7ee5106e0ae3dfc0db6537f632517`；另附checksums.txt。构建后复制到本机ignored产物目录冻结，后续不再用测试入口覆盖。

源码提交 `545814a448e705ce616a9f8f2df9cd7758c99ccd` 已push至 `feat/rust-flutter-mirror`，不可变annotated tag `android-v0.1.0-alpha.7` 指向该提交。Draft上传后核对GitHub资产uploaded状态、41267072字节与完整SHA-256匹配，再公开；公开API读回draft=false/prerelease=true、target为该提交。官方checksums.txt已下载并与本机manifest逐字节cmp通过，公开APK经已记录备用下载入口完整取回、SHA-256匹配冻结产物。

Release：https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-alpha.7

APK：https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.7/Ginkgo-0.1.0-alpha.7-android-arm64.apk

Pages现网landing.js已下载与仓库脚本cmp一致；用实际公开releases响应执行受信脚本，断言Android下载/校验和/版本选择Alpha.7、Windows仍Alpha.6通过（不是浏览器截图验收）。现网动态下载已识别新版本；无JS或API失败时静态fallback仍为原Alpha.6，不误称已更新main静态页面。未merge main或改Apple/Windows下载，README提供直接新APK/Release入口。

## 已知限制

- 真实登录及预约审批／取消往返未新增验收，结果不明不得重发；最近20条非全历史。
- 待办仅本机保存，完成不等于学校提交；升级前备份，勿直接降级编辑v2数据或卸载。
- 物理设备TalkBack／预测返回／通知省电／性能仍待验收，Windows保持既有Alpha.6，不随共享版本号假称已发新包。
