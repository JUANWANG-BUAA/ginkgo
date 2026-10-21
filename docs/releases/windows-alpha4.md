# Ginkgo Windows Alpha.4

首个公开 Windows 测试包，面向 Windows 10 / 11 x64。主下载为单文件安装器；便携 ZIP 仍保留给不想安装的用户。

## 下载

- [Windows 安装包（.exe）](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-windows-x64-setup.exe)
- [便携 ZIP](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-windows-x64.zip)
- [SHA-256 校验和](https://github.com/JUANWANG-BUAA/ginkgo/releases/download/windows-v0.1.0-alpha.4/checksums.txt)

## 安装

推荐下载 `Ginkgo-0.1.0-alpha.4-windows-x64-setup.exe`，核对 `checksums.txt` 后双击运行。安装器按当前用户安装，不需要管理员权限，会创建开始菜单入口、安装文件和卸载入口。

便携版需完整解压 ZIP，保留 exe、DLL 与 `data` 文件夹，不能只复制 `ginkgo_mirror.exe`。若系统缺少 Microsoft Visual C++ Redistributable，请先安装微软官方运行库。

当前安装包未配置 Microsoft Authenticode / EV 代码签名，SmartScreen 可能提示未知发布者。请只从本 Release 或已核对摘要的来源安装。

## 本版范围

- 单文件安装器，包含 Flutter 页面、Rust 核心、DLL 与运行数据。
- 宽屏分组侧栏，逻辑宽度低于 760px 时切换到底部导航。
- 今天、签到、课表、作业、预约、成绩、博雅、研究生教务与设置入口。
- Windows Credential Manager 合成凭据往返、独立详情返回栈、Tab 焦点与 Enter 激活通过。
- CI 会执行静默安装、安装目录完整性和静默卸载检查。

## 已知限制

- 未在物理 x64 和干净系统完成运行库、输入法、多屏与完整读屏验收。
- 未完成真实学校账号登录或上游写入验收；写操作仍须逐次人工确认。
- 未签名，尚未接入应用内更新；功能未与 macOS 完全对齐。

完整证据与边界见仓库 `docs/archive/mirror/MIRROR-WINDOWS-ALPHA4.md`。
