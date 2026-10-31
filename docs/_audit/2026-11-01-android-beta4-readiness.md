# Android Beta.4 发布与验收记录

## 范围

候选版本 `0.1.0-beta.4+14`，计划标签 `android-v0.1.0-beta.4`。本轮同时收敛全页面 UI、提醒可靠性、自动 WebVPN 回退、匿名公开读取和图书馆 TLS 兼容性；不包含新的学校写能力，不修改冻结的 SwiftUI 应用。

## 主要改动

- 完成全页面视觉与交互优化，覆盖工作台、课表、作业、签到、图书馆、更多、设置及二级页面；统一摘要、状态、筛选、系统控件和大字号布局。
- 作业区分提交与截止状态，助教范围计数更清楚；签到关联只在身份可靠时展示。提醒增加串行排程、存储失败保护、权限与通知类别恢复，类别关闭时不误记已送达。
- 手动登录仍允许认证链回退；登录后只有实际保存凭据或已有 WebVPN Cookie 时才允许业务自动回退。未记住密码时，直连失败不再被错误转换为全局 `sessionExpired`。
- 匿名公开读取始终直连，不发送或接收 Cookie / Authorization，不在 Automatic 下回退 WebVPN。
- `space.lib.buaa.edu.cn` 与 `lib.buaa.edu.cn` 实测均只下发叶子证书，复用仓库已有的 GlobalSign 中间证书并严格限定这两个主机；其他主机和默认信任库不变。该 TLS 变化在发布前仍需人工安全审查，不能用“绕过证书校验”概括。
- live 验收管线同步当前图书馆场馆选择路由及待办 CRUD 的稳定 key；公开通知、研讨室、空教室与核心页面继续按只读方式验收。

## 自动化证据

- `bash scripts/check-mirror.sh` 最终通过：架构 / 设计 / 文档门禁、Rust fmt / 严格 Clippy / core / upstream / workspace 测试、接口索引、FRB 零漂移、Flutter analyze 和 676 项 Flutter 测试。
- `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --features network only_the_two_library_hosts_use_the_scoped_intermediate -- --nocapture` 通过。TLS 白名单先因函数不存在失败，再实现并通过；其他学校主机与相似恶意域名不使用该中间证书。
- 未记住密码的自动回退回归先在旧实现出现 7 次请求（预期 6），修复后通过；保存凭据的 WebVPN 签到恢复回归同步通过。匿名 Automatic 回归先观察到 2 次请求，修复后只有 1 次直连请求。
- `flutter test integration_test/tasks_test.dart -d emulator-5554` 通过，覆盖本机待办创建、编辑、完成、持久化和删除。

## 真实账号只读与视觉证据

在隔离 Android API 37 ARM64 模拟器中，凭据仅通过一次性 loopback 通道进入真实登录流程，未写入仓库、构建参数或测试报告；全程未执行学校写操作。

- 不保存密码的自动路线：Today、课表、成绩、作业、博雅、研究生与三校区空教室成功；不可达服务保留 `networkUnreachable`，不再误报全局会话失效。
- 临时保存凭据的恢复路线：签到、图书馆场馆/区域/时段/座位及历史、公开统计、通知和其余核心读取均成功。公开统计返回两个校区，读取阶段最终零失败。
- 实际复看 Today、课表、作业及详情、博雅、研究生、图书馆场馆/区域/座位、空教室、研讨室和公开统计画面，未见明显裁切或层级异常。预约确认框只打开并取消，没有提交预约。
- 最后一轮完整 live 在登录阶段出现状态波动并停止，未继续反复提交密码；设置、完整工作壳及大字号末段没有因此获得最终通过证据。此前的真实接口通过与局部视觉证据分别保留，不写成“全页面 live 全部通过”。

## 发布边界

物理 Android 设备、实际 TalkBack、Windows 主机、Release 覆盖升级、真实学校写入及完整 live 末段仍未完成。真实账号测试产生的临时截图、测试包和专用模拟器在验收后清理；仓库不保存密码、Cookie、票据、原始响应或未脱敏个人信息。

发布资产、签名、tag、工作流和公开回下载结果见下方追加记录。

## 本地 Release 候选

- `flutter build apk --release --target-platform android-arm64 --target lib/main.dart --pub` 使用本机既有外部签名配置成功，未回退 Debug 签名。
- 候选 `artifacts/local/android-beta4/Ginkgo-0.1.0-beta.4-android-arm64.apk`：43,841,645 字节，SHA-256 `4a29b4a808f5f95ff32f7131946bd2995c03ce774e34aca85572153e6075d178`。
- 包名 `cn.edu.buaa.ginkgo.ginkgo_mirror`，`versionName=0.1.0-beta.4`、`versionCode=14`，仅 `arm64-v8a`，非 debuggable；生产 `GeneratedPluginRegistrant.java` 不含 `integration_test`。`zipalign -c -P 16 -v 4` 与 `apksigner verify` 通过。
- 签名证书 SHA-256 `451748b957b44d5a28ebcc967cc2aeec7e7bea6a13d9edcb021c9fd8dc7fb245`，与既有 Android 发布证书一致。
- 在隔离 API 37 模拟器覆盖安装该 Release 后，正常入口实际启动到 Ginkgo 登录页，不是 integration_test 等待页；未进行 Beta.3 → Beta.4 数据保留专项验收。

## 标签、公开资产与回下载

- 源码提交 `94ef91b9cefca5cfd52fbfe9e2227f8103474d0b` 与候选证据提交 `d9239139b51eda0b754873cb7df470c47a4399a2` 已推送；annotated tag `android-v0.1.0-beta.4` 指向后者。
- [Android Release workflow](https://github.com/JUANWANG-BUAA/ginkgo/actions/runs/41224215855) 在 Materialize external signing configuration 因仓库未配置四个 Android 签名 secrets 而 fail closed，构建与上传步骤未运行；公开资产使用上述本机同证书候选，没有降低签名要求。
- [GitHub Beta prerelease](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-beta.4) 已公开，`draft=false`、`prerelease=true`。APK 和 `checksums.txt` 均为 uploaded；API 返回 APK 大小 43,841,645 字节及 SHA-256 `4a29b4a808f5f95ff32f7131946bd2995c03ce774e34aca85572153e6075d178`，与本地一致。
- GitHub 直连回下载速度过慢，改用项目既有第三方备用入口完整取回 APK 和校验文件；APK 与本地候选逐字节 `cmp` 一致，校验文件一致，`shasum -a 256 -c checksums.txt` 通过。慢速重复下载已停止。
- 功能分支合入 `main` 的合并提交为 `133c322abb8485d8d2cb741aac497d925fb416bc`，已推送。GitHub Pages [部署](https://github.com/JUANWANG-BUAA/ginkgo/actions/runs/41225640955) 成功，线上 HTML 已显示 `0.1.0-beta.4`，APK 与校验文件链接指向新标签。
- 真实凭据通道、临时真实截图和专用 AVD 已清理；公开 APK 不含账号或个人数据。项目主页只使用离线演示合成素材。
