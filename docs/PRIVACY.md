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
| 校园卡/网费余额（若接入） | 应用进程内存 | 仅用户主动打开页面时读取；金额默认遮挡、点击显示；不写入查询快照、不写日志、不缓存到磁盘；缴费/充值/挂失等资金写操作永不接入 |
| 个人待办 | 本机 `UserDefaults` | 按账号摘要隔离；清除缓存不会删除待办；iOS 当前不在 Application Support 备份排除范围内 |
| 通知与提醒 | 系统通知中心 | 正文不含课程名、地点、学号等敏感信息；课程提醒与签到通知可分别关闭 |
| 运行日志 | Apple 统一日志 OSLog（subsystem `com.buaaassistant.app`） | 只记录模块、阶段、HTTP/业务状态、错误域与错误码；不含响应正文、账号、Cookie、票据或课程内容 |

### 1.1 Rust + Flutter 镜像（Android / Windows）

2026-11-03 工作树改动：Android 会话快照 v2 保存实际 Direct/WebVPN 路线，用户的 Automatic 偏好仍单独保存。旧 v1 显式路线可恢复；旧 Automatic 记录缺少实际路线，保留密文并等待用户手动登录，不猜 Cookie 归属或后台试密码。密码、Cookie 的加密范围和固定 24 小时上限不扩大；后续只用合成数据做离线回归，设备存储和人工安全审查仍未完成，详见[离线对照](_audit/2026-11-03-offline-session-parity-and-agent-review.md)。

| 数据 | 存放位置 | 生命周期与说明 |
|------|----------|----------------|
| 学号、密码 | Android Keystore + 私有 SharedPreferences；Windows Credential Manager；macOS Keychain | 仅在用户勾选「记住密码」后写入；Android 使用 AES-GCM，密钥不出 Android Keystore，账号名以 SHA-256 摘要作为偏好键；验证码答案不持久化；关闭开关或登出即删除 |
| 会话 Cookie（CASTGC 等） | Rust 进程内存；Android另存独立 Android Keystore AES-GCM 密文 | Android 冷启动时读取同一认证生命周期起点 24 小时内的会话快照（Cookie 轮换与恢复不重置期限），先按保存路线装载隔离的直连/WebVPN Cookie，再向 UC 验证账号后发布会话，UC 暂不可用时保留密文供重试但不发布缓存身份；登录成功与后续认证响应的 `Set-Cookie` 会更新快照。快照与“记住密码”分开，退出、开始新的手动登录或更改路线时删除。专用 Keystore 密钥不离开设备，密文不进入 Android 备份；Windows/macOS 镜像仍只在进程内保存 Cookie。验证码答案、业务 token 和匿名浏览器 Cookie 不进入快照 |
| 匿名公开读取会话 | Rust 临时直连会话 | 就业、学术文化、通知、校车、公开书目/馆藏、图书馆人数和版本检查不发送学校 Cookie/认证头，不保存响应 `Set-Cookie`，不改变账号会话路线，也不在 Automatic 下回退 WebVPN |
| 空教室、课表、今天、成绩、作业、博雅、研究生、签到、预约等查询快照 | Rust 进程内存 | 5 分钟 TTL、容量上限；登出、账号切换、路由变化即清空；不读取 Apple 缓存文件，不写磁盘 |
| 可选 SPOC 学习快照（工作树，默认关闭） | Android noBackupFilesDir，独立 Keystore AES-GCM 密文 | 用户显式确认后仅保存课程/栏目/公告列表/资料目录/测验元数据；原成功时间五分钟内、同账号已认证且网络暂不可用时可采用旧值，不持久化文件字节/Cookie/token；关闭、退出或清查询缓存撤销并清除；不涉及个人待办。接线与设备回归见 [记录](_audit/2026-10-26-module-integration.md)，敏感存储仍需人工审查 |
| 本人借阅（工作树） | Rust 单次响应与 Flutter 当前页内存 | 仅点击后读取，不进入查询快照、磁盘或提醒；离开栏目/后台/服务切换清除页面值，迟到响应废弃；认证失败清除旧记录。不取完整读者资料、册条码或续借资格。实网与设备验收仍待完成 |
| 显式宿主认证诊断 `auth_stage_probe` | 凭据、Cookie、表单和拒绝正文仅在该进程内存；可选临时验证码图片 | 非生产入口，须显式网络 opt-in；默认只做匿名 GET，另加 `--submit` 才读私有 stdin 管道并提交一次密码。输出仅固定阶段、状态、计数、结构布尔值和中英关键词标签，不输出任意 URL、字段值或错误原文，不调用平台保险库。仅显式 `--captcha-file` 才用 create_new 写图片，Unix 为 0600；正常退出/超时删除，异常终止须维护者清理。只允许保留白名单元数据；标签未命中不代表无错误，也不作为连续试密码的依据 |
| 设备验收诊断 | 平台保险库 | `verifyCredentialStorage` 只写入并删除调用方提供的合成密钥，用于验证 JNI/Keystore 往返，不接触账号数据 |
| 个人待办 | 应用私有支持目录；按账号 SHA-1 摘要隔离，Unix 文件权限 0600 | 仅本机待办内容；清除查询缓存不会删除；原子替换且损坏不覆盖；摘要不是加密 |
| 外观、路线与显式退出标记 | 应用私有支持目录的 `display-preferences-v1.json` | 仅设备级呈现和会话流程状态，不含学号、密码、Cookie、token 或学校响应。读取失败暂停自动路线初始化/会话恢复，可显式重读；保存重试只写当前本机快照，不重新认证学校。临时文件替换适配器不变，设备异常断电与存储故障仍需验收 |
| 提醒偏好与阅读摘要 | 应用私有支持目录；按账号 SHA-256 摘要隔离 | 仅开关、摘要键及过期时间，不含课程 / 作业正文；摘要不是加密；清除查询缓存不删除阅读偏好 |
| Android 本地提醒计划 / 投递去重 | 私有 SharedPreferences 与系统 AlarmManager / 通知中心 | 仅摘要键、类别、触发 / 到期时间；通知正文通用化。关闭提醒 / 登出撤销有效计划，过期去重键清理；未申请精确闹钟或常驻权限 |
| Android 后台提醒配置（工作树） | 私有 `reminder-background-v1` SharedPreferences / JobScheduler | 仅账号 MD5 所有权摘要、随机代次、签到/作业开关、通用状态和上次执行时间；摘要不是加密或身份凭据。后台只读取既有加密会话快照至密码盲的内存副本，UC 验证后查询；不读取保存密码、不落盘学校响应、不改前台 Cookie 密文，不在后台重登。账号切换撤销旧计划，退出清配置并取消任务；开关关闭相应分组。重启/覆盖升级重排有效计划；恢复失败保留原密文并供前台重试 |
| CGYY 表单及手动拼图 | Flutter / Rust 进程内存 | 二次确认后单次发送；token / 密钥不跨 FFI，不写日志或缓存；图片只用于本次手动验证 |
| 错误 hint 与可复制诊断 | 应用进程内存 | 最近 50 条错误码与 UTC 时间，不保存原始异常、URL、上游响应或个人信息；退出进程即清除 |
| 运行日志 | 平台日志 / Flutter debugPrint | 不记录密码、Cookie、票据、账号或上游响应正文；Kotlin 保险库只记录通用失败类别 |

Android 清单关闭 `allowBackup`，避免保险库密文与账号元数据进入系统备份；重启后由 Keystore 解密，密钥本身不离开设备。镜像端已有用户授权的真实账号只读记录；本轮结果及边界见 [2026-10-21 验收](archive/mirror/MIRROR-ACCEPTANCE-2026-10-21.md)。未经用户授权，不得用真实凭据运行自动化登录或查询；只读授权不包括自动提交上游写操作。

学校账号与查询请求不经过本项目自建中转服务器。Rust/Flutter 的已迁移公开查询与版本检查使用匿名临时会话，不携带学校 Cookie 或账号认证头，也不导入响应 Cookie；浏览器下载安装包可由用户选择第三方加速。座位生命周期与座位预约的写请求发送到 `booking.lib.buaa.edu.cn`；教学楼研讨室写请求发送到 `cgyy.buaa.edu.cn`。两者都必须由用户逐次确认。

iOS 端在启动时把 Application Support 根目录标记为 `isExcludedFromBackup`，避免课表、成绩、作业、座位、签到历史等查询快照进入 iCloud/iTunes 备份；个人待办当前仍存于 UserDefaults，尚未纳入这一备份排除范围。Keychain 凭据仍使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。iOS 隐私清单声明应用不跟踪、不收集数据，并列出 UserDefaults 与文件时间戳 required-reason API。

## 2. 仓库红线（贡献者必读）

- **永不提交**：真实学号、姓名、密码、Cookie、票据、原始 HAR、含个人信息的截图或日志。
- **资金类写操作禁止**：缴费、充值、挂失、转账、修改支付密码不得接入；余额查询仅只读，约束见 [DATA-SOURCES.md](DATA-SOURCES.md) §3。
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

2026-11-03 网络工作树补充：自动业务回退仅用现有 Cookie，在隔离副本校验目标 UC 同一账号后才提交到既有密文会话；失败副本不导入，不额外读取或提交密码。原路线、24 小时固定生命周期与退出清理边界保留。Cookie 拒绝不匹配 Domain，路径段隔离比固定 UBAA 的前缀规则更严格；真实设备与人工安全审查仍未完成。
