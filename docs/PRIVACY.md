# 隐私与数据管理

> 适用范围：Ginkgo（BUAA Assistant）macOS 与 iOS 客户端、Android/Windows Rust + Flutter 镜像、本仓库的文档与截图。
> 核心原则：不经过本项目自建中转服务器；可选直连学校系统或北航官方 WebVPN 网关，账号数据只留在本机，仓库永远不包含个人数据。

## 1. 应用接触哪些数据、放在哪里

| 数据 | 存放位置 | 生命周期与说明 |
|------|----------|----------------|
| 学号、密码 | Apple 平台钥匙串（service `com.buaaassistant.credentials`） | 仅在用户勾选「记住密码」后写入，访问级别 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；关闭开关或登出即删除 |
| 会话 Cookie（CASTGC 等） | 系统 `HTTPCookieStorage` / 应用进程内存 | 会话 Cookie 不跨进程保留，重启免登录由「钥匙串凭据 + 静默重登」达成；WebVPN 使用独立进程内 CookieStorage，不落盘 |
| WebVPN 网络路线 | 北航官方 `d.buaa.edu.cn` 网关 | 仅在直连被访问策略拦截或用户主动选择时启用；不经过本项目服务器，不上传凭据到第三方 |
| 课表、考试、成绩、作业、图书馆、空教室、签到、校园通知等查询快照 | macOS Application Support；iOS 应用沙盒 Application Support | 文件名按账号 SHA-256 摘要隔离（摘要用于区分账号，**不是加密**）；设置页「清除缓存」可删除 |
| 图书馆人数与座位聚合历史 | 同上 | 仅按校区/日期/小时的匿名聚合，不含账号或座位标识；最多保留 60 天/4,000 条 |
| 座位签到/临时离开/完全离开 | 应用内存 | 不申请系统定位权限，按上游前端兼容方式提交空 `points` 对象；不保存位置或轨迹 |
| 教学楼 CGYY 预约表单（手机号、主题、内容、参与人数/说明） | 应用内存，仅随单次请求发送 | 只在用户二次确认后提交到 `cgyy.buaa.edu.cn`；不写入查询缓存与日志 |
| 教学楼门锁密码/二维码 | 应用内存 | 只在用户打开“门锁密码”页时读取；不落盘、不写日志，界面提示不要转发或截图分享 |
| 滑块验证码图片 | 应用内存 | 自动识别仅在用户点击提交后进行一次，不保存图片；识别结果只用于当次请求 |
| 个人待办 | 本机 `UserDefaults` | 按账号摘要隔离；清除缓存不会删除待办；iOS 当前不在 Application Support 备份排除范围内 |
| 通知与提醒 | 系统通知中心 | 正文不含课程名、地点、学号等敏感信息；课程提醒与签到通知可分别关闭 |
| 运行日志 | Apple 统一日志 OSLog（subsystem `com.buaaassistant.app`） | 只记录模块、阶段、HTTP/业务状态、错误域与错误码；不含响应正文、账号、Cookie、票据或课程内容 |

### 1.1 Rust + Flutter 镜像（Android / Windows）

| 数据 | 存放位置 | 生命周期与说明 |
|------|----------|----------------|
| 学号、密码 | Android Keystore + 私有 SharedPreferences；Windows Credential Manager；macOS Keychain | 仅在用户勾选「记住密码」后写入；Android 使用 AES-GCM，密钥不出 Android Keystore，账号名以 SHA-256 摘要作为偏好键；验证码答案不持久化；关闭开关或登出即删除 |
| 会话 Cookie（CASTGC 等） | Rust 进程内存 | 不落盘；进程重启后通过平台保险库静默重登；直连与 WebVPN Cookie 分离 |
| 空教室、课表、今天、成绩快照 | Rust 进程内存 | 5 分钟 TTL、容量上限；登出、账号切换、路由变化即清空；不读取 Apple 缓存文件，不写磁盘 |
| 设备验收诊断 | 平台保险库 | `verifyCredentialStorage` 只写入并删除调用方提供的合成密钥，用于验证 JNI/Keystore 往返，不接触账号数据 |
| 运行日志 | 平台日志 / Flutter debugPrint | 不记录密码、Cookie、票据、账号或上游响应正文；Kotlin 保险库只记录通用失败类别 |

Android 清单关闭 `allowBackup`，避免保险库密文与账号元数据进入系统备份；重启后由 Keystore 解密，密钥本身不离开设备。镜像端目前没有真实账号只读验收记录；在用户单独授权前，不得用真实凭据运行自动化登录或查询。

应用不向任何第三方服务器发送数据；除学校上游域名外没有其他网络出口。座位生命周期与座位预约的写请求发送到 `booking.lib.buaa.edu.cn`；教学楼研讨室写请求发送到 `cgyy.buaa.edu.cn`。两者都必须由用户逐次确认。

iOS 端在启动时把 Application Support 根目录标记为 `isExcludedFromBackup`，避免课表、成绩、作业、座位、签到历史等查询快照进入 iCloud/iTunes 备份；个人待办当前仍存于 UserDefaults，尚未纳入这一备份排除范围。Keychain 凭据仍使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。iOS 隐私清单声明应用不跟踪、不收集数据，并列出 UserDefaults 与文件时间戳 required-reason API。

## 2. 仓库红线（贡献者必读）

- **永不提交**：真实学号、姓名、密码、Cookie、票据、原始 HAR、含个人信息的截图或日志。
- 协议文档只使用合成示例（如学号 `sy2501001`、Cookie 值 `xxx`）。
- 界面截图入库前必须打码姓名与学号，并在文档中注明数据为当时状态。
- 测试使用合成 fixture 与 `URLProtocol` 模拟响应，不访问真实账号；真实账号观察只在脱敏后以文字记录进 `docs/ACCEPTANCE.md`。
- `.gitignore` 已排除 `*.har` 与构建产物；新增敏感目录（原始抓包、本地截图工作区）时应同步加入忽略规则。

## 3. 本机数据如何清理

- **登出**：清除钥匙串凭据、Cookie 与内存会话。
- **设置 → 数据与缓存 → 清除缓存**：删除课表/成绩/作业/图书馆/空教室/签到/校园通知快照与图书馆聚合历史；不删除个人待办。
- **彻底清除（macOS）**：删除整个 `~/Library/Application Support/BUAA-Assistant/` 目录即可移除全部本机查询数据。
- **彻底清除（iOS）**：卸载 App 可移除沙盒内查询数据；Keychain 项的生命周期由系统管理，可在系统设置中清理或通过应用登出删除。
- **多账号隔离**：快照按账号摘要分文件，切换账号不会读到其他账号的数据。

## 4. 反馈问题时的要求

请附脱敏后的运行日志（`AppLog` 输出本身不含敏感值）、复现步骤和账号类型（本科/研究生）。不要粘贴：真实学号、Cookie、HAR 原件、成绩/课表截图或任何可识别的个人信息。需要协议取证时，先按 [COLLABORATION.md](COLLABORATION.md) §2.2 的流程脱敏。

## 5. 构建与沙箱状态（2026-10-17）

- Xcode 工程声明了 `BUAA-Assistant.entitlements`（App Sandbox + `network.client`）；用 Xcode 默认签名运行时会应用沙箱，数据落在 `~/Library/Containers/com.buaaassistant.app/`。
- 本仓库文档中的命令行构建使用 `CODE_SIGNING_ALLOWED=NO`（仅用于编译/测试，不启用沙箱）；此类构建产物资源未封签，Dock 图标需 `codesign --force --sign -` 修复，见 [RELEASE-NOTES.md](RELEASE-NOTES.md)。
- iOS 工程使用应用沙盒，本地缓存排除备份，包含 `PrivacyInfo.xcprivacy`；签名、TestFlight 与 App Store 隐私标签尚未配置。
- 仓库已扫描确认不含真实姓名、学号或凭据；界面截图身份字段已打码。
