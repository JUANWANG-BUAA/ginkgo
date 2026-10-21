# Windows Alpha.4 首发记录

2026-10-21，版本 `0.1.0-alpha.4+5`，首个公开 Windows 测试包。主下载为单文件安装器，另保留便携 ZIP。目标是 Windows 10 / 11 x64；源码与 Android Alpha.4 共用 Rust 核心和 Flutter 页面层。

## 下载

- [Windows Alpha.4 Release](https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/windows-v0.1.0-alpha.4)
- [Windows 安装包（.exe）](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-windows-x64-setup.exe)
- [便携 ZIP](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-windows-x64.zip)
- [SHA-256](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/checksums.txt)
- [第三方 gh-proxy 备用入口](https://gh-proxy.com/https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-windows-x64-setup.exe)

第三方入口只改善 GitHub 连通性，不改变发布文件；下载后应使用 Release 中的 `checksums.txt` 核对 SHA-256。

## 安装方式

推荐下载 `Ginkgo-0.1.0-alpha.4-windows-x64-setup.exe`。安装器按当前用户安装到 `%LOCALAPPDATA%\Programs\Ginkgo`，不需要管理员权限，并创建开始菜单入口和卸载入口。CI 会对最终安装器执行静默安装、安装目录完整性和静默卸载检查。

便携版按以下方式运行：

1. 确认系统为 Windows 10 / 11 x64。
2. 将 ZIP 完整解压到普通可写目录，例如 `D:\Apps\Ginkgo`。
3. 运行 `ginkgo_mirror.exe`。必须保留同目录 DLL 与 `data` 文件夹，不能只复制 exe。
4. 若系统缺少 Microsoft Visual C++ Redistributable，请安装微软官方运行库后重试。

当前安装器与便携 ZIP 均未签名，SmartScreen 可能显示“未知发布者”。请先核对 Release 中的 SHA-256，再决定是否运行；不要从无法核对摘要的转载源下载。

## 本版包含

- 宽屏分组侧栏与窄屏底部导航；逻辑宽度达到 760px 后切换桌面布局。
- 今天、待办、签到、课表、成绩、作业、博雅、研究生教务、图书馆、预约与设置入口。
- 离线演示；不登录学校系统也可查看脱敏 / 合成页面。
- Windows Credential Manager 的合成凭据写入、读回与删除。
- 独立详情返回栈、Tab 焦点与 Enter 激活。

## 验证证据

Parallels Windows 11 ARM64 来宾运行 x64 Flutter / Rust 工具链，结果见 [主机验证](WINDOWS-2026-10-21.md)：

| 检查 | 结果 |
| --- | --- |
| `cargo test --workspace --locked` | 核心 181、递归契约 1、bridge 1、doc-test 1 项通过 |
| `flutter test --no-pub test` | 91 项通过 |
| `flutter test --no-pub integration_test/windows_test.dart -d windows` | 2 项通过 |
| `flutter build windows --release --no-pub --target lib/main.dart` | 通过 |
| 相邻运行资源 | exe、Rust bridge DLL、Flutter DLL、`icudtl.dat`、`AssetManifest.bin`、AOT `app.so` 齐全 |
| Inno Setup 打包与安装 | 单文件安装器编译、静默安装、关键文件检查、静默卸载均通过 |
| 实际窗口 | 200% DPI 下宽屏显示侧栏，窄屏切换五个底部标签，拉宽后恢复侧栏 |

单文件安装器由 GitHub Actions 在 `windows-latest` 上从已验证便携 ZIP 重新封装：

- 文件：`Ginkgo-0.1.0-alpha.4-windows-x64-setup.exe`
- 大小：`21,661,892` 字节
- SHA-256：`3249f3be0575421c30cf02622e741b9aadbcbcda21eb5618ff61e4aa8620fcd4`
- 2026-10-21 经 gh-proxy 备用入口完整下载，摘要与 Release `checksums.txt` 一致，文件识别为 Windows PE 安装程序。

便携 ZIP 由 Release 工作流在 `windows-latest` 上重新构建并打包：

- 文件：`Ginkgo-0.1.0-alpha.4-windows-x64.zip`
- 大小：`28,180,865` 字节
- SHA-256：`6938a8dfbe80c83baf8e29093f467f9d5156954e481273645ba54d1c2ab5f1e1`
- 2026-10-21 经 gh-proxy 备用入口完整下载，摘要与 Release `checksums.txt` 一致，ZIP 完整性检查通过。

CI 构建不会替代真实设备验收。

## 已知限制

- 未完成物理 x64 Windows 与干净系统安装验收；当前证据来自 Windows 11 ARM64 来宾运行的 x64 构建。
- 安装器与便携 ZIP 未签名；尚无应用内更新、自动启动或完整后台能力。
- 本次公开发布未执行真实学校账号登录、真实只读全链路或上游写入；写操作仍须逐次人工确认，结果不明时不自动重发。
- 完整读屏、输入法、多屏、系统缩放与高对比度仍需 Windows 实机验收。
- 功能未与 macOS 完全对齐；尚未迁移的功能以 [模块对照](../../MIRROR-PARITY.md) 和 [待办](../../MIRROR-TODO.md) 为准。

## 来源与隐私

公开包不含发布者的学校账号、Cookie、票据、个人课程或作业数据。安装包中的演示页面使用合成课程与日期。用户自行登录后的凭据是否保存由用户选择；本地存储实现与清理边界见 [隐私说明](../../PRIVACY.md)。
