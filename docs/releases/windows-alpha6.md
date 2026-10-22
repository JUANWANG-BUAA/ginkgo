# Ginkgo Windows 0.1.0-alpha.6

面向 Windows 10 / 11 x64。推荐下载 `Ginkgo-0.1.0-alpha.6-windows-x64-setup.exe`；也提供完整便携 ZIP。安装器按当前用户安装，无需管理员权限。当前未签名，SmartScreen 可能提示未知发布者；请先核对 `checksums.txt`。

- 签到增加课前 10 分钟门禁，作业增加截止前 48 / 24 小时的应用内未读角标。
- 新增脱敏错误 hint、行动建议和可复制诊断。
- CGYY 接入 iOS 对照预约表单、手动拼图、单次提交 / 取消和回查保护。
- 手机式窄窗口 / 桌面侧栏共用角标及业务规则，保留独立详情返回栈和键盘交互。

**Windows 暂不提供后台系统通知**，只在应用运行时显示提醒；不自动签到、提交作业或预约。CGYY 实验写入尚未完成真实账号往返验收，结果不明时先回查，禁止自动重发。

本轮使用 Windows 11 ARM64 Parallels 来宾运行 x64 构建进行合成验证；不代表物理 x64、干净系统运行依赖、输入法、多屏或完整读屏验收。便携 ZIP 必须完整解压并保留相邻 DLL 与 data 文件夹；缺少运行库时安装微软官方 Visual C++ Redistributable。

未执行真实学校登录或上游写操作；完整记录见 `docs/archive/mirror/MIRROR-ALPHA6.md`。
