# 智慧校车公开入口与认证接续调查（2026-10-26）

本次仅进行有限匿名 GET 和公开前端静态阅读，没有使用真实账号、浏览器 Cookie、
订单、购票、退款或身份伪造。协议登记仍以 [API §6C](../API.md#6c-智慧校车脚本静态本人查询页面观察未购票) 为准；
本记录不另建 TODO，不把未建立的余票会话写成已接通。

## 新增观察

| 来源 / 操作 | 本轮结果 | 能说明与不能说明的边界 |
| --- | --- | --- |
| `GET https://zhihuixiaoche.buaa.edu.cn/wechat/indexPage` | HTTP 200，100 字节，仍为“未获取到认证信息，请退出后重新进入”脚本；SHA-256 `3c6d942c91de033f293764bfae96a6a959448c9f5ecc2362d49d705d33b3d7f5` | 裸入口本次无校车会话；不证明账号被拒或余票永久不可接入 |
| [后勤服务中心官网](https://bhhq.buaa.edu.cn/)“校车预约”锚点 | 实际 `href` 为 `http://zhihuixiaoche.buaa.edu.cn/` | 官方仍存在该入口；并非已证实可用的 HTTPS 授权链 |
| `GET http://zhihuixiaoche.buaa.edu.cn/` | HTTP 404 | 按官方锚点做一次无凭据公开 GET；不在明文链传递身份或口令 |
| `GET https://zhihuixiaoche.buaa.edu.cn/` | 本机默认 TLS 下连接失败，`SSL: WRONG_VERSION_NUMBER` | 没有关闭证书校验、回退弱 TLS 或用 HTTP 传递身份；不能从一个网络失败推断全校不可用 |
| [办事大厅](https://n.buaa.edu.cn/v2/site/index)公开代码与 `GET /api/home/all-search?keyword=校车` | HTTP 200，业务 `e=0`，找到“智慧校车”服务卡片；`id=1333,type=4,jump_type=1,terminal=0,details_page=1`；`url` 仍为 `http://zhihuixiaoche.buaa.edu.cn/`，不含 query | 本次卡片元数据没有提供额外授权参数；不证明已登录 / i北航宿主中的行为也相同 |
| `GET /api/home/hot-apps?more=0` | 一次 HTTP 504，未重试 | 不用暂时失败宣布服务不存在 |

官方公开说明另可确认：历史[智慧北航使用指南](https://nic.e1.buaa.edu.cn/info/1044/3785.htm)
将校车归于生活服务，并说明当时 App 基于企业微信；[2026 新生报到须知](https://news.buaa.edu.cn/info/1002/69624.htm)
将智慧门户与 i北航 App 列为官方登录入口。这些是入口背景，不是校车授权协议或当前余票成功事务证据。

## 公开前端静态证据

从 `https://n.buaa.edu.cn/v2/static/js/` 获取公开部署资源，不执行脚本：

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `index.de26f26017c398128e6b.js` | 146396 | `3c74ed333f536285df974b441afdad285abef3718f496a2cd9506bfcce158527` |
| `chunk-common.c5d8c347596c57a01398.js` | 438129 | `9a15a004bed486c68ec7a2683651057cf44653cce8018ff6157cf9a3a63f4860` |
| `chunk-vendors.7633ad76527b9c52fb57.js` | 460034 | `7e55c1a0b7aac3667b85be46aba6a315037409b235f0ca2e15ab4530882cbfb5` |
| `chunk-a0ffc3e0.533857a779fbfb5081a2.js` | 11939 | `b35a36b5e3304f84e73cb099379b7a207c3d62f92c3c47d4b050a1044e9b4b52` |

`chunk-common` 的 `e425` 模块是公开接口名称表，以三位 base36 字符码编码，按静态表达式解码为 JSON；
其中 `allSearch` 映射 `/api/home/all-search`，`getAppDetail` 映射 `/api/apps/detail`。
本次只按已见搜索调用的 `GET` / `keyword` 形状读取公开服务卡片，没有猜测未见详情参数。

同文件的 `thirdAppToUrl` 先请求 `recentappssave`，再请求 `thirdClickNum`，然后按服务对象的
`jump_type`、`terminal`、`url` / `url_pc` 选择外链或站内详情；另一处通用链也区分 `url_mobile`。
`recentappssave` 是保存最近应用的 POST，本次未执行；浏览计数 GET 也未执行。
因此不能宣称本次走完了官方点击后的完整实际链，更不能以匿名卡片的 URL 替代已登录宿主中的事务。

## 工具与结论

REA MCP 在本会话不可调用；找到的缓存 CLI 为 3.1.0，其 doctor 显示 Codex 注册缺失。
一次静态分析调用被 CLI 自身的 `investigation_input` 管理上限拒绝（`ceiling.roots=[]`）。
未修改 REA/客户端配置，未重试被拒操作；上述结论来自普通 Python 标准库的只读网络与静态文本分析，
**没有新增 REA Evidence ID**，不可冒称 REA 已完成图分析。

首轮匿名公开读取未取得可用校车会话，办事大厅公开卡片也没有附带授权参数。
随后用户给出日常准确入口，补充调查找到真实 CAS 入口，见下节；首轮 404 与“认证入口仍未知”
不能作为最终结论。没有新增真实余票网络适配器，没有把静态容量转换为余票，也没有降低票务写入门禁。

## 用户准确入口补充：根地址会进入 CAS

用户确认日常使用 `http://zhihuixiaoche.buaa.edu.cn/` 后，针对该精确入口核对：

| 请求（均无凭据、不跟随下一跳） | 本轮结果 |
| --- | --- |
| 主代理 Python urllib，浏览器式 `Mozilla/5.0` UA，HTTP 根地址 | HTTP 302，`Location: /wechat/CASLogin`，空正文 |
| Android Chrome UA，curl，HTTP 根地址 | HTTP 302，同一 `/wechat/CASLogin`，空正文 |
| Android Chrome UA，默认 TLS，`GET https://zhihuixiaoche.buaa.edu.cn/wechat/CASLogin` | HTTP/2 302，目标 `https://sso.buaa.edu.cn/login`，`service=http://zhihuixiaoche.buaa.edu.cn/wechat/CASLogin` |

环境代理变量没有设置；Python `urllib.request.getproxies()` 为空，macOS `scutil --proxy`
的 HTTP / HTTPS / SOCKS / 自动代理启用标志均为 0。本轮没有改变 Host、DNS、代理或 TLS。
初次 Python 默认 UA 的 404 未在浏览器 UA 下复现；这只是相关观察，尚不足以认定服务端以 UA
区分路由，也可能受瞬态状态影响。不能再将 HTTP 根入口报告为稳定不可用。

**已定位此前漏掉的官方 CAS 引导路径**：直接访问 `/wechat/indexPage` 绕开了根地址提供的
`/wechat/CASLogin` 入口；此前 CAS 会话负结果没有验证这条业务认证链。
但本次学校给出的 `service` 是 HTTP 回调，尚未证明 HTTPS service 重写可被学校接受；
本轮没有改写 service、向 SSO 发请求、登录或携带 ticket 跟随明文回跳。

最小修复仅调整现有外链元数据：真实和演示时刻表的 `liveSource` 指向已验证可达的
`https://zhihuixiaoche.buaa.edu.cn/wechat/CASLogin`，由用户主动在外部浏览器打开官方认证入口。
App 不捕获或导入该浏览器会话，不自动处理认证回跳。页面改称“前往官方认证并查看余票”，
并明确应用内余票会话尚未接通；移除此前“校车独立认证”的未经证实推断。

内部只读余票仍需合法认证回程和完整查询事务证据，不能用上述匿名 302 宣布余票已接通。

验证：`cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream codecs::shuttle:: --locked`
通过 5 项；新增 CAS 入口回归在修复前因旧 `indexPage` 值失败，修复后通过。
`flutter test test/shuttle_page_test.dart --reporter expanded` 通过 30 项，含外链精确使用 DTO、
外部浏览器模式、不增加业务请求及演示入口一致性，原有 320dp / 2× 深浅色布局回归仍通过。
`git diff --check` 通过。本批次未修改 bridge API，无需重生成绑定；全量门禁由主代理统一执行。

主代理完成本轮总门禁：`bash scripts/check-mirror.sh` 返回 0，Rust 架构/fmt/严格 Clippy/全量测试、
Flutter analyze、509 项 Flutter 测试及 FRB 再生成一致性通过。外链已修不等于应用内余票已接通。

正常 main 入口 Android ARM64 Debug APK 已重新构建并安装到独立 QA emulator-5580，启动成功；
未执行账号认证或公开发布。
