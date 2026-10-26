# 本人借阅认证链复核（2026-10-26）

## 本次范围

接续真实借阅认证循环的调查。只核对当前 adapter/service、原会话已保存的脱敏错误和
少量官方公开 GET/静态脚本；没有读取真实凭据、复制浏览器 Cookie、提交登录表单，
也没有执行续借、归还或其他学校写操作。未创建第二份待办清单。

## 新增观察

1. 匿名访问 `https://space.lib.buaa.edu.cn/meta-local/opac/cas/rosetta`
   返回 HTTP 302，目标为官方 SSO `/login`，query 只有 `service`。
   解码后的 service 为
   `https://space.lib.buaa.edu.cn:443/meta-local/opac/cas/rosetta`，无附加 query。
   首响应不设置 Cookie。本次匿名入口本身没有出现重定向自循环。
2. 公开 `search_confs` 成功一次，HTTP 200，`data.baseConfs.loginType=1`，
   `casUrl/casBaseUrl` 为学校 SSO。整个公开响应本次 SHA-256 为
   `9e997bdc8228bdc6332b35b54b3b58c23498b3ac16a0bbcb8825554e47786f87`。
   配置响应的其他内容可变化，哈希变化不能单独证明认证配置变化。
3. 主脚本 `space.35058fb9.js` 仍为 297254 字节，SHA-256
   `a16c2eef370d190cf89cf67bb9744a5d9ab4f4f890e52cb7746568535ec8fbf9`；
   CAS 登录分支仍直接导航到 `spaceUrl`。它没有表明需要在 rosetta 前额外调用
   本人借阅、完整读者资料或任意激活写接口。
4. CasBoard 懒加载脚本 `chunk-2d0a3577.9bea817c.js` 仍为 1813 字节，SHA-256
   `3e51358ee035b29e9ee7e4846ee9442f4af57e8b8d0ec4fa1d2f941f73a4a3a9`。
   普通 CAS 分支读取已有 Cookie 会话的用户资料，然后只设置前端 store 状态并导航；
   token 参数交换仅在 UNION 分支中。静态脚本没有证据支持给当前 CAS 模式臆造 token 参数。
5. 匿名 SSO 后续 GET 在本机遇到 TLS `WRONG_VERSION_NUMBER`，随后公开配置复读也有网络失败。
   未放宽 TLS、未绕过认证、未自动重登；停止继续请求。该失败不能证明凭据、读者资格或
   学校服务配置有误。

公开图书馆请求使用默认系统信任并补入仓库现有的 GlobalSign 中间证书，
没有使用 `-k` 或禁用证书校验。查询串中的认证票据、Cookie 值、个人信息均未保存。
这些是普通 HTTPS/静态文本检查结果，不能称为 REA 运行态 Evidence；本会话无 REA MCP 工具，
CLI 的只读 doctor 启动未能及时完成，已终止，没有修改 REA 或客户端配置。

## 对当前实现的判断

当前 Rust 入口与公开 CAS 分支一致：rosetta → 受限 SSO/图书馆 GET → CasBoard → loans。
上次真实账号循环的脱敏阶段链未保存在导出的工具结果中，不能仅凭 `RedirectLimit`
判定循环发生在 SSO、服务票据回调还是读者会话建立阶段。本次没有用猜测替换认证流程，
也没有增加 profile 查询、Cookie 注入或密码重发。

**真实 App 读者认证、成功非空字段及第二页仍未接通/未验收。** 本次只排除了
“公开 rosetta 已经匿名自循环”和“必须给普通 CAS 添加 UNION token”这两种未经证实的判断，
不能写成已修复借阅链路。

下一次本人受控只读验证应保留现有 adapter 的路径类别阶段链（`entry/sso/board/loans/other`），
只记录状态码、类别和是否重复，不记录 Location、service ticket 或 Cookie 内容。
没有相应证据前，不改协议参数或请求更多私人字段。

## 用户日常移动端入口复核

用户补充日常页面 `https://space.lib.buaa.edu.cn/mspace/reader/lendList` 后，
匿名 GET 返回 HTTP 200（1347 字节）；页面加载 mspace 应用，路由基址 `/mspace/`。
继续有限读取公开 JS 和已有 search_confs，不执行下载代码、不读取私人借阅或提交认证。
TLS 沿用默认校验加仓库已有 GlobalSign 中间证书，没有关闭校验。

| 资源 | 字节数 | SHA-256 |
| --- | ---: | --- |
| 移动 lendList HTML | 1347 | `77059c9029e54ecb1fe987aaf8ec420d87c1c79e6cc9a97c6aee979096e52892` |
| mspace.e16ceef9.js | 115845 | `b08764d05baf5a994d205d11a0296b5953bb5766dbe5db3233a465a84b045dbe` |
| chunk-common.a68bbfcc.js | 87779 | `6ecf5874372b129eb828acee3da1a0d1b39a9342c404d77bcbd13b1053d5f5fe` |
| chunk-04739719.e7733bf7.js | 9559 | `7edd1fdcf926b3d52ca0f3dd8e6c2216bd044c45ac78e09dc967eeb4404f3abf` |
| chunk-b5f1f978.651a0b37.js | 3411 | `fe5f7d47d5e8fdbea5baa233bbc1454e28bb11e82218c68c01a2221372a7f9fa` |

新增静态观察：

- `ReaderLendList` 路由为 `reader/lendList`，有 `loginBlocking=true`，加载 `41a1` 组件。
- `41a1.getLendList` 按 page/pageSize（默认1/20）读已有 loans，题名/著者仍取 bibAttrs，条码取 item.barCode。
  借出日期的前十字符是官网呈现处理，不是后端字段格式保证。移动页不是另一个借阅 API。
- mspace 的 axios 包装含 `X-Hw-explorer=m` 及动态 CSRF 头；这证明官网请求构造，未证明 App 当前借阅认证失败由缺该头造成，因此不以猜测修改认证。
- LoginBoard 优先使用 `space.m.space.url`，缺省回退 `spaceUrl`；公开配置本次仍为 loginType=1，
  `spaceUrl` 是原 rosetta，未提供移动 URL/移动 CAS target，PC target 仍是 `/space/casBoard`。
  用户移动页面成功返回 HTML 不能证明建立了本人读者会话。
- 移动 CasBoard 普通分支读取 Cookie 身份后初始化前端 store；UNION token 交换仍是单独分支。
  还含可选微信绑定 POST，本次不执行，也不将其当成普通 CAS 必要步骤移植。

最小修复：`library_loans_http::portal_url()` 从通用 `/space/` 首页改成用户已确认、当前公开可加载的
`/mspace/reader/lendList`，让“打开图书馆官网”直接定位本人借阅。没有添加 profile、通知、
绑定/续借请求，没有复制 Cookie，没有改变内部 rosetta 认证链。

新增官网链接回归在修复前明确失败（旧值 `/space/`），修复后借阅定向 8 项通过；
完整门禁及正常入口产物由本轮主流程验证。此前真实认证循环、非空/分页仍未修复或验收。

本轮总门禁 `bash scripts/check-mirror.sh` 返回 0：Rust 架构/fmt/严格 Clippy/全量测试、
Flutter analyze、509 项 Flutter 测试及 FRB 再生成一致性通过。自动化不代替真实读者认证。
