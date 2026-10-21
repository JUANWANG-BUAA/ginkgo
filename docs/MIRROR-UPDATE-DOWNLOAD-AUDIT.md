# Android 更新下载入口（2026-10-21）

基于 `8337014` 在 `feat/mirror-update-download` 独立工作树开发。主工作树与模拟器未操作，改动尚未并入发布包。

## 行为与来源

设置→软件更新成功检查后，若发布确实包含本版本的 `Ginkgo-{version}-android-arm64.apk`，提供“GitHub 下载 APK”和“第三方加速下载”。后者明确标注 gh-proxy.com，沿用 `docs/index.html` 已有的公开 APK 加速地址格式。只打开浏览器，由 Android 系统确认安装；不增加自动下载、安装、学校请求或任何上游写操作。

Rust 在 `UpdateSummary.downloadUrl` 中白名单投影资产：发布页必须与 tag 完全匹配，APK 文件名、下载路径 tag、仓库和版本全部一致，size>0，HTTPS 且无身份信息、端口、query 或 fragment。Dart 在打开浏览器前再次限定仓库、版本/文件名一致性及 URL 格式；仅把合格公开 APK 地址包装为 `https://gh-proxy.com/https://github.com/…`。学校 Cookie/会话不进入该入口，原有更新请求保持公开独立会话。

旧快照缺 `downloadUrl` 时继续显示发布页，缺 APK 不展示下载按钮；预发布通道、更新失败保留上次结果等行为沿用。第三方服务可用性不保证，官方入口始终保留。

## 验证

- Rust 更新领域 2 项通过（其余 164 项未重跑）；契约遍历 1 项通过。现有两份更新 fixture 补可选字段，总类数/文件数不变。
- 全 workspace all-targets/all-features Clippy `-D warnings`、fmt check 通过。
- 4 项 maintenance widget/逻辑测试通过，覆盖官方与加速按钮、匹配下载链接、主机/身份/端口/查询/片段/版本混用拒绝、重复检查和失败保留。
- 三文件 Flutter analyze 无问题。
- 公开现有 Alpha1 APK，宿主 `curl -IL --max-time 25`：官方跟随重定向 HTTP 200（1.54秒），gh-proxy HTTP 200（0.68秒）。这是单次 HEAD 可达性探测，未下载完整文件，不能当作中国大陆手机测速或完整性验证；未发布新的 APK。

设备由根任务独占，本分支没有设备 smoke、Android 浏览器往返或真实账号验收。新下载入口无需学校账号；后续与设置单项设备验收一起核对即可。首次更新查询仍依赖 GitHub API，本次不声称解决了 API 受限场景。
