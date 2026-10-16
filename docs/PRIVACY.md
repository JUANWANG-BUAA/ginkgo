# 隐私与数据管理

> 适用范围：Ginkgo（BUAA Assistant）桌面端、本仓库的文档与截图。
> 核心原则：只直连学校系统，账号数据只留在本机；仓库永远不包含个人数据。

## 1. 应用接触哪些数据、放在哪里

| 数据 | 存放位置 | 生命周期与说明 |
|------|----------|----------------|
| 学号、密码 | macOS 钥匙串（service `com.buaaassistant.credentials`） | 仅在用户勾选「记住密码」后写入，访问级别 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；关闭开关或登出即删除 |
| 会话 Cookie（CASTGC 等） | 系统 `HTTPCookieStorage` / 应用进程内存 | 会话 Cookie 不跨进程保留，重启免登录由「钥匙串凭据 + 静默重登」达成；WebVPN Cookie 仅存于进程内，不落盘 |
| 课表、考试、成绩、作业、图书馆、空教室、签到、校园通知等查询快照 | `~/Library/Application Support/BUAA-Assistant/` | 文件名按账号 SHA-256 摘要隔离（摘要用于区分账号，**不是加密**）；设置页「清除缓存」可删除 |
| 图书馆人数与座位聚合历史 | 同上 | 仅按校区/日期/小时的匿名聚合，不含账号或座位标识；最多保留 60 天/4,000 条 |
| 个人待办 | 本机 `UserDefaults` | 按账号摘要隔离；清除缓存不会删除待办，需自行处理 |
| 通知与提醒 | 系统通知中心 | 正文不含课程名、地点、学号等敏感信息；课程提醒与签到通知可分别关闭 |
| 运行日志 | macOS 统一日志（OSLog，subsystem `com.buaaassistant.app`） | 只记录模块、阶段、HTTP/业务状态、错误域与错误码；不含响应正文、账号、Cookie、票据或课程内容 |

应用不向任何第三方服务器发送数据；除学校上游域名外没有其他网络出口。

## 2. 仓库红线（贡献者必读）

- **永不提交**：真实学号、姓名、密码、Cookie、票据、原始 HAR、含个人信息的截图或日志。
- 协议文档只使用合成示例（如学号 `sy2501001`、Cookie 值 `xxx`）。
- 界面截图入库前必须打码姓名与学号，并在文档中注明数据为当时状态。
- 测试使用合成 fixture 与 `URLProtocol` 模拟响应，不访问真实账号；真实账号观察只在脱敏后以文字记录进 `docs/ACCEPTANCE.md`。
- `.gitignore` 已排除 `*.har` 与构建产物；新增敏感目录（原始抓包、本地截图工作区）时应同步加入忽略规则。

## 3. 本机数据如何清理

- **登出**：清除钥匙串凭据、Cookie 与内存会话。
- **设置 → 数据与缓存 → 清除缓存**：删除课表/成绩/作业/图书馆/空教室/签到/校园通知快照与图书馆聚合历史；不删除个人待办。
- **彻底清除**：删除整个 `~/Library/Application Support/BUAA-Assistant/` 目录即可移除全部本机查询数据。
- **多账号隔离**：快照按账号摘要分文件，切换账号不会读到其他账号的数据。

## 4. 反馈问题时的要求

请附脱敏后的运行日志（`AppLog` 输出本身不含敏感值）、复现步骤和账号类型（本科/研究生）。不要粘贴：真实学号、Cookie、HAR 原件、成绩/课表截图或任何可识别的个人信息。需要协议取证时，先按 [COLLABORATION.md](COLLABORATION.md) §2.2 的流程脱敏。

## 5. 构建与沙箱状态（2026-10-16）

- Xcode 工程声明了 `BUAA-Assistant.entitlements`（App Sandbox + `network.client`）；用 Xcode 默认签名运行时会应用沙箱，数据落在 `~/Library/Containers/com.buaaassistant.app/`。
- 本仓库文档中的命令行构建使用 `CODE_SIGNING_ALLOWED=NO`（仅用于编译/测试，不启用沙箱）；此类构建产物资源未封签，Dock 图标需 `codesign --force --sign -` 修复，见 [RELEASE-NOTES.md](RELEASE-NOTES.md)。
- 仓库已扫描确认不含真实姓名、学号或凭据；界面截图身份字段已打码。
