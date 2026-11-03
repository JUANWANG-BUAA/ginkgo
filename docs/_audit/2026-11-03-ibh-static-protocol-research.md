# 2026-11-03 i 北航静态取证与公开信息研究

用户要求减少真实账号测试，改从 i 北航客户端协议取证、公开接口和官方网页信息整合推进；随后确认可自行安装更新 REA，并指出本地已有 App。本轮不登录、不运行目标 App、不读取账号缓存/钥匙串，不执行学校写入。未完成任务仍只维护在 [MIRROR-TODO](../MIRROR-TODO.md)。

## 工具与样本

从 npm 官方 registry 查询最新版本为 REA 6.8.0，安装于 `/Users/juanwang/.local/share/rea-tools/`。经 dry-run 检查后按本轮授权执行 Codex setup：仅注册 REA MCP 并更新对应技能，保留其他配置；原配置备份为 `~/.codex/config.toml.rea.backup.7f2265d28562d6a2acd0c54853591722dddd71389117e895dd2ab6949e7bd0bb.recovery`。最终 `doctor --client codex` 的 Node 和 Codex 注册检查通过。当前聊天继续使用 CLI，不能把注册通过写成当前会话已连接 MCP，也不能把该健康检查理解为所有原生/Android 引擎已就绪。

本地样本 `/Applications/i北航.app`：Info.plist 显示版本 `3.5.0`、build `3451`，bundle ID 为 `com.tencent.WxWorkMacEntCustomized`，主程序 `UniWeCom`，为 x86_64 Mach-O。包约 1.3 GiB，包含企业微信组件、内嵌浏览器、Qt RCC、ASAR 和其他资源；不将通用组件协议视作北航业务协议。

| 对象 | SHA-256 / REA 证据 |
| --- | --- |
| App 目录库存 | `71ee393239895d72de7b8bb306fbb3e03c3565bdc35be14bfee81fe0f839b859`；REA 6.7.0 `ev_7dd1d40007678968534f31ccc7bea4c06f6eafe920044ae5d6096b45da58eddb`，库存 manifest `agm_2756e345d245ba196dab403b2272bf825e03f561fb2118d930d39f4ad9941ad8` |
| UniWeCom 主程序 | `10cdb9c3bbd9356934fc13165fc3f80cae0b2a92d04dfc17d256d8f45d65cc60`；REA 6.8.0 Mach-O `ev_79f306041dc408f0b18a8d504f2188fafa7591206dd3cf4a1fb418adddc2bd05` |
| `Contents/Resources/res/res.rcc` | `ab45bce7458338a730802096ead248f59066d81118ce84366303f4317a76b672`；本地只读格式解析，不标为 REA 原生反编译证据 |

完整机器报告及派生资源仅保存在忽略的 `artifacts/local/ibh-research-20261103/`，不提交厂商二进制、完整资源、加密参数或任何账号数据。目录摘要是 REA 库存结果，不是上游签名证明。

## 当前观测与限制

1. RCC v3 本地格式解析枚举到 10,937 个文件节点；解压后找到 `/wecom/local/html/eula.html` 与 `privacy.html`。后者包含 `https://privacy.buaa.edu.cn/`，支持“北航定制资源”的判断，不证明业务 API。
2. 同目录有 `wecrm_config.json` 与 `wecrm_config_aeskey.txt`，分别为 6,240 / 512 字节的十六进制文本；前者不能直接作为明文 JSON 解析。后续已按本页末的定点汇编证据完成离线解析，不猜测加密方式，不输出加密参数或业务凭据。
3. 主程序及 RCC 原始字节的有界 URL 检索没有找到学校业务 URL；压缩资源中的隐私链接说明原始字符串检索覆盖有限。未返回的符号、动态注册应用和远程加载页面仍是未知，不能宣布 App 不含相关协议。
4. Native Mach-O 工具的 import/export 覆盖不完整，不能据其缺项推断函数不存在。深度原生反编译还需独立引擎；Ghidra 官方发布包的准备结果另行追加，不将 REA 本体安装成功冒充深度引擎已就绪。

## 官方公开下载入口

[学校官网 i 北航页](https://www.buaa.edu.cn/index/ibh.htm) 给出定制企业微信下载入口。由该页可验证的公开 corpkey 访问腾讯 `local_download` 落地页，标题为“下载i北航”。保存的网页 JavaScript 静态构造 `realdownload`，Android 平台值为 `andr`。此值来自实际脚本，不使用猜测的 `android` 值作为协议事实。

落地页单独由 REA JavaScript 分析器处理，证据 `ev_a750a4cf318e56d3f38ccb20429a5a30315834b6e6ce4e6ddccea404b56ae53c`；只覆盖下载路由脚本，不覆盖 App 业务。学校域名本机 TLS 错误、办事大厅 HTTPS 超时与 Android 下载端点错误分别保留；搜索服务读取成功不能冒充本机网络可用。发现本地 App 后已转向本地样本，不反复尝试安装包下载或真实认证。

## 接入边界

后续证据必须分为：静态发现、匿名只读实测、真实账号读取与本人写入。App 内出现 URL 不等于公开接口；公开接口需另证无 Cookie/认证头可读及返回字段。已实现的就业、学术文化、通知、校车和书目优先复核已有链路，新增研究优先教务/研究生院公开通知和办事指南；不开展全站抓取，不重建自有中转服务。

学校协议只有经过验证后才进入 API.md 并同步适配器/fixture；本报告不新增未经证实的端点、成功码或产品能力，不解除当前发布阻断。

## 本轮工具补齐与匿名查询结果

已增加固定 CLI 入口 `/opt/homebrew/bin/rea`，指向用户目录中的 REA 6.8.0。Ghidra 12.1.2 从 NSA 官方 GitHub Release 下载，发布 API 给出的 SHA-256 `b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d` 与下载校验一致，解压至 `~/.local/share/rea-engines/ghidra_12.1.2_PUBLIC`。REA 原生引擎 doctor 的目标、版本、macOS ARM64 decompiler、完整 JDK 检查均通过；使用已有 Android Studio JBR25，不另装 Java。经第二次 setup dry-run 后，将 `GHIDRA_INSTALL_DIR` / `JAVA_HOME` 绑定到 Codex 的 REA 注册项；对应备份摘要为 `48b672173a81f4deb24b6ab525a48ba9d473d8f6fdc24104dde6ca54d6d3a96b`。

`GINKGO_MANUAL_LIVE_NETWORK=1 cargo run --manifest-path rust/Cargo.toml -p ginkgo_upstream --example public_protocol_probe --features network --locked --offline` 运行一次既有匿名适配器，不读取 vault，不提交凭据或学校业务写入：学术文化 7 条、校园通知 5 条、校车 4 张表、当月就业 23 条、图书馆人数 2 校区、书目 20 条、首条公开书目的复本 2 条，均实际解析成功，结束报告 `no_authenticated_cookies`。`--offline` 只约束 Cargo 依赖解析，不表示学校查询离线。结果保存在 `artifacts/local/ibh-research-20261103/public-probe.jsonl`。

这些结果只覆盖本次各源的指定查询及现有适配器，不是新发现的 i 北航接口，不证明全部分页/权限、Android 实际网络、真实账号或学校写入。公开办事大厅 `n.buaa.edu.cn/v2/site/index` 本机 HTTPS 超时、HTTP 返回 404，尚未取得本轮页面脚本，未据此猜测后端路由。

另对已登记的就业月历执行一次独立匿名 GET，提取字段类型后丢弃记录值：HTTP200、`state=1`、23 条；全部观察字段为字符串，字段集合与响应摘要存于 `public-career-shape.json`。响应摘要 `363da96e96fc9c6ed2ac7e54d30497f86db98040dcc3f9b3789f123e9b6bba9e`，结果已窄范围同步 API §6G/修订106；不依据 `linkUrl` 等新增字段猜测业务含义或改变现有适配器。

## 定制配置离线解析结果

Ghidra 整包搜索在 600,000ms 导入/自动分析期限内未完成，返回 `provider_timeout`；未确认 OutOfMemoryError，不将此次调用计作反编译成功。错误 JSON 保存于 `native/config-search-rea.json`。未原样重跑或仅扩大期限；改以源字节映射、x86_64 RIP-relative LEA 候选定位，再用 Xcode LLVM disassembler 验证指令。此部分是普通离线汇编证据，不能冒称 REA Ghidra 伪代码。

确认 `wecrm_config.json` 的引用在 `0x1026830db` / `0x102684a1d`，同一邻近区域含编译路径字符串 `core/foundation/wecrm_config.cpp`。`0x102684624` 起的函数读取 `publicKey_1.pem` 和 `wecrm_config_aeskey.txt`，在 `0x10268468d` 调用 `PEM_read_bio_RSAPublicKey`，在 `0x102684762` 调用 `RSA_public_decrypt`，padding 实参为 1。`0x102684a02` 起的函数读取配置，`0x102684ac1` 调用 `EVP_aes_128_ecb`，随后调用 `EVP_DecryptInit_ex` / update / final。操作路径来自已验证的机器指令，不通过猜测 AES 模式试解。

以包内公钥恢复包内封装参数后，按上述 AES-128-ECB 路径只在内存解码，得到可解析 JSON：3,105 字节，SHA-256 `d0dcfe4530d20c48572c898cdf8af3d4ece414813127169495b3b4d5f7cd0b49`。保留 74 个字段的路径/类型和白名单服务元数据，不保存完整明文、参数值或身份数据。macOS LibreSSL 的 `pkeyutl` 不直接接受 PKCS#1 `RSA PUBLIC KEY` 头，先进行标准 SPKI 公钥格式转换；这不是更改密钥或放宽验证。

静态观测：`DEFAULT_ADMIN_SERVER_ADDRESS`、`DEFAULT_EXTERNAL_ADMIN_SERVER_ADDRESS`、`INTRANET_HOST`、`EXTRANET_HOST` 均为 `qywx.buaa.edu.cn`，对应端口均为 443；`intranet_homepage_url` 为空字符串。这里只能断言该样本的默认管理服务配置；不证明当前部署可达、匿名开放、所有业务均经此主机或手机端契约一致。未向该主机提交账号或变更请求。

原始汇编范围、候选映射、结构化结果及可复跑的离线解码脚本分别为本地忽略目录下的 `native/config-loader-disassembly.txt`、`config-rip-candidates.json`、`config-decoded-schema.json`、`decode-shipped-config.py`。这些派生件不入库；学校的具体业务端点/方法/认证/返回字段仍须后续取证，不从服务主机或字段名臆造。
