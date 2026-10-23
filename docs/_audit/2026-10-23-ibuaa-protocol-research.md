# i 北航入口、官方前端协议与只读实测审计（2026-10-23）

> 性质：调研证据，不是实现／发布记录。主工程基线 `573fbc6`；本轮只修改文档，不修改业务代码，不构建／测试业务工程，不执行预约、取消、续借、购票、退款、打卡、点赞、上传或标记已读操作。
> 用户自行登录并打开目标服务；不复制所提供的口令，不读取浏览器凭据库、聊天、通讯录或他人资料。个人响应只在内存投影字段类型／成功码，报告不含书目、身份标识、Cookie、token、验证码或个人订单。
> 设计主文：[下一阶段方案](../NEXT-STAGE-PLAN-2026-10-23.md)；扩容布局：[信息架构方案](../NEXT-STAGE-IA-2026-10-23.md)；协议登记以 [API.md](../API.md) 为准；执行待办只记 [MIRROR-TODO](../MIRROR-TODO.md)。

## 1. 结论与证据边界

本轮把“入口可见”“官方前端静态表达式”“本人页面成功展示”“接口成功响应”分开记录。读接口也可能产生检索历史／访问日志，不承诺零副作用；允许的是功能查询，不是业务变更。

| 领域 | 本轮新增证据 | 尚不能声称 |
| --- | --- | --- |
| i 北航本体 | 本机为 macOS 原生 WeCom 定制客户端，不是 Android APK；工作台确有教学、图书、生活等服务入口 | 已恢复全部学校协议，或安装包包含所有远程业务代码 |
| 图书公开目录 | 匿名 search／hot1／new/books／holdings 返回业务数值 `code=0`；检索和新书非空；馆藏字段是内嵌 JSON 字符串 | 全分类／全分页／所有馆藏状态已验收；热门公式／月份已确认 |
| 本人借阅 | 当前已登录页刷新捕获 loans／loan_info HTTP 200、`code=0`；loans 为成功空列表 | 非空本人书目、过期会话、续借资格或全部分页已验收 |
| 智慧校车 | 用户手动查询后列表出现 12 班、不同余票；官方页面脚本明确请求与余票分支 | 匿名访问、票价／身份资格、实时性保证或购票可用 |
| CGYY | 官方移动端 page=0、weekStartDate 来源、info 响应传递、验证码坐标／成功码等静态链已定位 | 学校真实写故障根因；草稿占槽、token 轮换、提交／取消／审批成功 |
| 阳光打卡 | 体育／艺术表单、照片先上传、公开开关、clockin、记录详情与getCount单字段消费静态已定位；用户明确要求下一阶段手动提交 | 已真实提交／有效考勤验收；服务器幂等／权限已确证；全系统绝不使用定位 |

时间为本机观察 2026-10-23（北京）；无服务端时间校准保证。匿名 curl 无认证参数，使用系统默认 TLS 校验，没有关闭证书校验。只记录结构，不把 HTTP 200 当业务成功。

## 2. 工具与生命周期事件说明

最初用 Cua 托管独立 Chrome 是错误的工具选型：REA 观察不能维持 Cua 生命周期；空闲会话结束导致独立浏览器两次退出。没有调用显式关闭命令，仍由本轮调研承担责任；`get_session` 不能作为已验证保活措施。用户明确反对后停止该路径。

恢复调研使用 macOS `open -n -a 'Google Chrome' --args ...` 原生启动，独立配置 `IBuaaProtocolResearch`，仅 loopback CDP；REA 和临时 Node CDP 连接是外部附着，结束观察只断开连接，**不关闭浏览器／标签页、不重启进程、不删除配置**。未修改或复制原 Edge 配置。报告不把先前被拒绝的 existing-profile 连接改称已授权成功。

直接 CDP 仅使用页面／脚本／DOM／网络观察及限定查询动作；没有执行页面 Runtime JS、没有读取 Cookie／localStorage／登录表单。个人在借探针仅刷新已选本人只读页、在内存读取已完成的 loans／loan_info 响应并输出成功码与形状。校车自动点查询未产生可确认证据，明确记失败，后由用户手动查询，REA 读取已呈现列表；不把失败动作报告为成功。

REA `capture_browser_scenario` 校车试验报告 cleanup=`disconnected-external`，但它会开始页导航并施加 viewport／locale 等场景选项；此后不再用它接管页面交互。页面附着无法回溯既往网络事务；用户操作后能看到列表，不代表已保存其请求／响应原文。

本轮临时脚本、静态 JS 和工具 spill 在仓库外；没有把原始 HAR／截图／个人响应加入 Git。浏览器 profile 仍可能保留用户手动登录的会话，由用户管理退出；不能称本机从未存储会话。REA 内部观察证据也可能保留页面元数据，不应直接导出完整 bundle 到公开仓库。

## 3. 本机应用与远程加载机制

- 路径 `/Applications/i北航.app`，主程序 `Contents/MacOS/UniWeCom`，Bundle ID `com.tencent.WxWorkMacEntCustomized`，版本 3.5.0／build 3451；thin x86_64 Mach-O。
- 主程序 SHA-256：`10cdb9c3bbd9356934fc13165fc3f80cae0b2a92d04dfc17d256d8f45d65cc60`；安装包目录 inventory 根摘要 `71ee393239895d72de7b8bb306fbb3e03c3565bdc35be14bfee81fe0f839b859`。
- 完整 inventory 为 5,630 occurrences，无完整性矛盾；符号与 Interface Builder 解码覆盖受限，不能据此声称完整本体逆向。
- `Resources/xworker.js` SHA-256 `9c223e656c24ceec91af08a37be5b9c5f056bfe5261196fd4bf3a89b04edb9d4`，24,772 行。L3030 `batch_project_config`；L3044–3053 拼离线包根目录；L3211–3250 下载／MD5／解包；L3324 使用配置 url/md5/project_alias/patch_id/status；L3578–3588 根据配置 entry 构造 `https://app.work.weixin.qq.com/xwebEntry/{appid}/{entry}`；L23479–23490 合并 vendorType/webviewType/preUrl；L24670–24684 拉 runtime config。
- 以上是通用 WeCom 包加载能力，不是 BUAA 特定业务域名／认证协议，也不是观察到学校业务实际通过该离线包执行。没有执行下载器或其中环境测试代码。
- 限定静态文本扫描、WeDrive renderer.zip 扫描未发现目标业务文字，只能说明所扫范围未命中。业务可远程下发／压缩／换编码，不能以未命中否定存在。
- Ghidra／Kuna 未配置；native dispatch 受到 64 MiB 输入预算限制，不能靠降低输出行数解决。没有安装引擎、修改客户端或附着其内存。

### 3.1 已观察工作台入口（不等于接口已接入）

教学：课表、智慧教室、全校课表、空教室、考试、成绩、博雅、智学北航、研究生管理、学生注册／请假、证明／打印／第二课堂。

图书：座位、研讨间、寄存柜、图书检索、热门图书、当前借阅、我的书架、当前图书预约／委托、借阅违章、个人图书信息。**教学楼研讨室、图书馆研讨间和图书馆座位须分清系统。**

生活与其他：智慧校车、校园卡、生活导览、美食导航、报修、校园活动、网络、办事、就业、预约挂号／公费医疗／心理服务、阳光打卡。仅记录服务名称，没有访问聊天／通讯录，未枚举所有底部条目。

## 4. 官方公开 JavaScript 身份与定位规则

静态文件按原站公开 GET 取得，不携带登录 Cookie；下载脚本不代表执行脚本。源位置以下默认 **零基 UTF-16 code units、半开区间**；webpack module ID 不是原始 Vue 文件名。字节大小不能与 UTF-16 偏移混用。URL 的文件名/hash 是部署名称，不是 SHA-256。

| 代号 | 原站路径 | 字节数 | SHA-256 |
| --- | --- | ---: | --- |
| LS | `space.lib.buaa.edu.cn/space/js/space.35058fb9.js` | 297254 | `a16c2eef370d190cf89cf67bb9744a5d9ab4f4f890e52cb7746568535ec8fbf9` |
| LC | `/space/js/chunk-common.a68bbfcc.js`（同图书站） | 87779 | `6ecf5874372b129eb828acee3da1a0d1b39a9342c404d77bcbd13b1053d5f5fe` |
| LF | `/space/user/config/app.config.js` | 1817 | `5833a9cb82d97f97b86f33c7e2f51913902bbcd977a1d8224d40669045156bfd` |
| LR | `/space/js/chunk-56c3fc0e.62ce98d6.js` | 11346 | `3debee467a19987daa2b446d2d8e29f7097cc201acc1c36384006fa3bbb1f730` |
| LH | `/space/js/chunk-d90842e8.fba90576.js` | 8014 | `9802feada01dc4b4752c9a76e574d8f4fbfa1388f02d3813967071bdbc1b3731` |
| LL | `/space/js/chunk-4ca8889a.faf39b4e.js` | 11319 | `6850e7cba679259b6bbc6ba5f6b94567e7f3ca175148d9a9f32945c9cf2eb659` |
| CM | `cgyy.buaa.edu.cn/venue-zhjs/js/chingo.b6b5f918.js` | 274064 | `23a61eb6d50e55473f2826dd952ba1fa9cfa4930d9c7b95bc2bca80dd8142474` |
| CR | `/venue-zhjs/js/chunk-12db6be5.716e1d3c.js` | 151145 | `605d86f6b55c90dbdeee8106a926b2b1f5b5efc3fd068f4dd1f666189768e42e` |
| CO | `/venue-zhjs/js/chunk-30ebe396.f1980542.js` | 40575 | `2384db5a41b09f63faa37c7856171e2c9b14b4900c911e53c4ad5f8c1d7a2b7c` |
| CV | `/venue-zhjs/js/chunk-73a1ec7a.74cd0e48.js` | 8692 | `ff20b553934f546aedfea3267baceb0352765ec101f0039620aae2a1efecf7d8` |
| YM | `ygdk.buaa.edu.cn/js/index.5e2fec5a.js` | 41007 | `5c94b7a126aecb14cfcb186fef0e4c1543c5d698c9c55cf998649ed86cd4984f` |
| YH | `/js/chunk-b2a55222.247b8167.js` | 12655 | `dcaee125c49dff33f0376cdf64d774f809b186ee388f1d7b5136c2fad096cb74` |

CGYY 另下载共享 b8869836／87cabb6a；它们的名称不能与订单 mine 或草稿自动关联。图书详情 chunk 按 runtime 映射下载失败，未尝试猜 hash 绕过；下面馆藏结构来自实际公开读取，不依赖未取得详情模块。

REA 对选定四个小 chunk 做了惰性静态应用图：完整 parent `ev_f50277843286f644c8951b50897be5d6815ebc25e8547579a3376d377be8ea7c`，14 个文件未选、400 semantic unknowns 达预算；图只作定位辅证，**不代替精读表达式或宣称全图完整**。旧安装资源大图也曾部分取消，不能引用“无匹配”为不存在。

## 5. 图书：已从候选推进至部分只读响应验证

### 5.1 基址、成功与检索

LF 配置 base 为同源 `/meta-local`（UTF-16 31–53）；LS/e650（285964–287073）创建 axios，LS/74b9（98236–99309）与 LC/aacb 将数值 `code===0` 视为业务成功并解 `data`。语言与 CSRF 头由运行态生成，不记录值。

| 方法与 path（接 `/meta-local`） | 静态来源 | 本轮实测 |
| --- | --- | --- |
| POST `/opac/search?coverFirst=false&disable_facet=false` | LS/6237 87381–89055；LR/1f1c 7820–9139 | 匿名 JSON 查询“计算机”、page1/pageSize2，`code=0`，非空 dataList |
| GET `/opac/search/search_confs`；`/opac/search/_suggest?fieldName=...&query=...&size=7` | LS/6237 | 仅静态；配置完整字段／排序未逐项实测 |
| GET `/opac/bibs/{编码bibId}/holdings?isMobile=0&relateStat=1` | LS/0edb 34771–36151 | 实际检索返回 bibId→同源馆藏，`code=0` |
| GET `/opac/commend/hot1?count=2` | LS/fc9d 294740–295563 | 匿名 `code=0`，数组含 rank/hotValue；不等于公式已解释 |
| GET `/opac/new/books?page=1&pageSize=2` | LS/4b0e 82227–82915 | 匿名 `code=0`，dataList 非空 |

SearchParam 默认 `page=1,pageSize=20,indexName=idx.opac,sortField=relevance,sortType=desc,collapseField=groupId,queryFieldList=[],filterFieldList=[]`；普通综合词项 `{logic:0,field:"all",values:[输入],operator:"*"}`。这是官方配置／调用结构，不是新定义学校字段。

响应实际包含 `tookTime,total,actualTotal,offset,limit,dataList,facetList,extraInfo`；本次 extraInfo=null。书目项有 `bibId,isbn,title,author,publisher,pub_year,docType,callno,groupId,itemCount,circCount,holdings,eholdings,thumb` 等；检索样本 callno 为数组，热门样本为字符串，模型须区分，不能强制一律字符串。HTML／内嵌 JSON 不是可以直接显示的普通文案。

LR/1f1c 把 total 保留为 maxTotal，但 UI 分页封顶 10000；不应把封顶值误报学校真实总量。“仅可借”追加 `circCount` 范围过滤（9999–10302），不是具体复本可借／可续借的保证。

### 5.2 馆藏、封面与编号

馆藏响应本次是 `data.holdings: string`，**再 JSON 解码才得到复本数组**。一条非空公开样本呈现字段类型包括 `classMethod,callNo,barCode,itemId,library,location,locationName,locaCode,tempLocation,circStatus,itemStatus,status,itemsCount,itemsAvailable,totalCircTimes,yearCircTimes,inDate,itemUpdatedDate,shelfMark,vol`；空值如 shelfMark=null。状态编码完整映射、馆藏地与校区映射仍待确认，不能凭数值猜“可借”。

编号继续区分 ISBN／bibId／索书号／册条码；`itemsAvailable` 等不能不看层级就直接加总。`totalCircTimes/yearCircTimes` 字面字段存在不等于验证了统计年份、累计口径或可以跨书相加。

封面 LS/6237 与 79bc：GET `/opac/search/extend/{id}?coversOnly=true`；POST `/opac/search/extend3?coversOnly=true`，后者 body `{isbns:[],bibIds:[]}`，按 bibId 取数组首项 imageUrl（107636–109990）。**只证实调用构造，未取图片／未确认图片主机白名单**；thumb 的实际非空和占位规则也未验收，不引入第三方封面商。

### 5.3 热门：数据可读，解释仍不完整

LH/be78：GET `/opac/commend/{sort}/byclass` 或 `/bysubject`，query `dcpCode,page,pageSize`（7011–7746）。分类来自配置，中图类读 `/opac/classes/clc/classes?level=1`、学科读 `/opac/classes/GBT13745/disciplines`（6389–6947）；初始首项取 id，点击项取 code，dcpCode 存在预编码再 URLSearchParams 的路径，勿擅改编码。

排序枚举 `top/top_loans/top_favorites/top_scores`、默认 top（4983–5158），实际 render 没有引用排序控件。没有月份／年份／统计公式证据。首版可诚实叫“官方推荐（来源标为官方热门模块，统计口径待说明）”，或只显示新书；不得叫“本月借阅人数排行榜”，也不把 hot1 与完整分类榜强行视为同一指标。

### 5.4 个人借阅与写隔离

LL/02d9（1218–2014）固定 `GET /opac/users/loans?page=1&pageSize=100`，读取 `data.items`；非空才另读 `/loan_max_renew_times`，按 `item.barCode` 合并 `maxRenewTimes-renewTimes`。这只是官方页最多首 100 条的行为，不是完整遍历规格；服务端是否可继续分页另验。

本轮本人已登录页面返回 loans HTTP200/code0、items=[]，分页形状 `currentPage,pageSize,total,items,totalPage`；`/opac/users/loan_info` HTTP200/code0、data 是字符串。没有非空私人数据 fixtures、没有验证续借上限请求实际响应。

非空字段仅静态确认：`loanId,bibId,item.barCode,bibAttrs.title/author/callno,loanDate,dueDate,renewTimes,location,loanType,loanTypeDesc,requestStatus,loanStatus`。`soon/overdue` 是 UI 状态；按钮只排除两种 loanType，不是完整资格校验。**剩余次数、按钮可见、HTTP200 均不等于当前允许续借。**

仅识别不调用：POST `/opac/users/renew`、`/batch_renew`；图书预约／委托／取消、书架写与读者资料更新均排除。图书馆通知详情 GET 也可能标记已读，未试验，不能默认读写无害。个人查询首版主动打开、内存保留、离页／切账号清理；到期通知需持久化读取信息，另做隐私评审。

## 6. 智慧校车：页面验证与动态余票语义

真实站点 `https://zhihuixiaoche.buaa.edu.cn/wechat/indexPage`，不是 UBAA 中转。当前首页还有官方通知及失物招领／意见入口；页面展示定期时刻表图片，发布时刻和图片适用日期必须分开。

同页已加载 inline script 的 UTF-16 7354–9200：查询按钮 `#shift_search` 读取站名和日期；POST `/wechat/ShiftsSearch`，form 字段 `up_origin_name,up_terminal_name,shifts_date,act=search`；动态 CSRF header 使用运行态值。回调以 `data.success` 和 `data.list` 判断，不能套用图书 code0。

脚本 8380–8900 的票数逻辑：非摆渡班次先算 `open_seat_num-student_num-teacher_num`；当 `type!=1 && is_parttime!=1` 且服务端 `currentTime` 早于发车时间减 `ticket_all_minute` 时，再减 `seat_retain_num`；小于0夹到0。列表 `is_shuttle==1` 显示“摆渡车”而不是数字票数。**这属于当前页面面向当前身份的展示算法，不是全部乘车资格或售票契约。**

列表模板约 19599 起消费 `depart_time,shifts_number,up_origin_name,up_terminal_name,is_shuttle,ticketNum`。用户手动点查询后，REA 观察 2026-10-23 沙河→学院路列表 12 班，有 0 与非零不同余票；报告不把具体瞬时票数保存为固定数据。用户特定条件、日期、保留政策、更新时间都会影响展示，不能用容量／计划人数或旧截图代替实时余票。

另外静态出现 POST `/wechat/getNotification`、`/wechat/waitingOrder`（带 status/page）、`/wechat/applicationForDrawback`。waitingOrder 涉及本人订单，本轮不主动查询；退款端点只识别，不调用。预定／支付／团体票／签到／司机入口全部不测。自动查询尝试没有捕获可确认事务，**当前 ShiftsSearch 的 method/body/响应字段来自脚本，列表来自用户操作后 UI，不是完整网络成功样本**。

下一步门禁：由本人驱动捕获单次查询的脱敏字段形状、服务端时间单位／时区／放票窗、身份分支、空班次／售罄／摆渡／权限／限流样本；只读展示也必须注明“查询时余票，购票以官方为准”。

## 7. CGYY：官方移动端链对现有疑点的更新

本节是公开官方 JS 静态证据，不执行 draft／captcha check／submit。基址 CM/a49f 为 `https://cgyy.buaa.edu.cn/venue-zhjs-server`。

### 7.1 请求与认证

CM/6909（132140–134048）按 path／排序字段／timestamp 等构造签名，签名在表单 URL 编码之前；顶层对象／null 等有排除规则。CM/7d3a（155313–157664）传输时可把对象 JSON.stringify、顶层 null 省略；**嵌套 JSON 内的 null 不会因此自动省略**。访问 token 的 localStorage／cookie 回退与预约 orderToken、captcha token 是不同角色；未读取实际存储或输出配置材料。

### 7.2 直接链与定位

CV/567f 的 5593 将 StepOne 对象交给 StepTwo.setData。CR/4ce9 为第一步，CR/8d0f 为第二步／验证码；CO/d119 为 `/mobileOrders`。

| 断言 | 官方静态表达式／位置 | 对本项目的意义与限制 |
| --- | --- | --- |
| 订单第一页 | CO 26961 初始 currentPage1/pageSize5；28458 发 `{page:currentPage-1,size:pageSize}`；28800 非管理员 `/api/orders/mine`；29216 解 content/totalElements | 官方这条移动端首请求 page0/size5；Rust `cgyy_http.rs:198–200` page1/size20、Swift 默认1/20不是同一首请求。但不能证明服务端默认排序／新单落页 |
| weekStartDate | CR 70891 GET `/api/reservation/day/info`；72555 `reservationDateList[0]||""` | Rust/Swift 用 bookingDate 存在来源差异；应跟 day 响应，不把首项叫必然周一 |
| day token | CR 71648 响应 token→orderToken；82848 info 回调 `t.token=e.orderToken` | 前端传下一步的值明确源于 day；不能据此证明再 day 不轮换 |
| info（项目称 draft） | CR 81467 submitDate、82342 POST `/api/reservation/order/info`；82544保留响应对象 | 返回 tradeNo、详情、倒计时、isCaptchaCheck 等被后续读取，不应在协议模型里全部丢弃；仍不证明必填或占槽 |
| ID 类型和 group | CR81801 info 的 split 值 spaceId/timeId 为字符串、group 未得到时显式 null；129682起 submit 值来自响应，reservationType==-1 强制 group null | 不能笼统把 Rust null 当错；Swift nil 省略与官方对应分支不同；draft 字符串也不证明 submit 必须字符串 |
| 验证后链 | CR133068 verifySuccess→submitData；131715 POST `/api/reservation/order/submit` | 这条链无验证码成功后额外 day；Rust追加复核与旧token组合仍需生命周期证据，不直接删保护 |
| 有条件验证 | CR131175 isCaptchaCheck==YES 且无验证值才展示 | 不能单凭静态跳过验证；先完整解析 info 模型 |
| 成功≠审批 | CR131780读 orderInfo；checkStatus!=PASS提示等审批 | 不把提交响应、官网文案等同学校审批通过；本项目强回查仍需保留 |

info 后 StepTwo.setData（127688）消费 `orderDetailList,venueInfoBean,tradeNo,orderCloseTime,orderGmtCreate,remainSecond,weekStartDate,token,isCaptchaCheck` 等。官方还存在旧待处理订单提示（CV5863 `/api/orders/wait_order`）及 release 路径，不能为“清理”而自动调用，也不能据提示证明草稿已占槽。

### 7.3 验证码新证据（不破解、不提交）

CR 约105650传显示尺寸 **330×155**，BLOCK_PUZZLE。117405 GET `/api/captcha/get` 带 captchaType/clientUid/ts；115647 POST `/api/captcha/check` 仅 pointJson/token。get/check 均按 **repCode=="0000"**，成功读 repData；现 Rust/Swift 看 success，需验证是否双字段共存／冲突，不能只因静态不同宣称服务端失败。

115542 的协议 x 为 `310*parseInt(moveBlockLeft)/parseInt(setSize.imgWidth)`、y=5，可为小数；它不是“天然图像宽减拼图宽”的坐标。显示330→归一310与 Flutter 天然图宽后 round、Rust整数0..310 之间有明确契约风险，**不能简单把上限放到1000**。point JSON 和 token 构造 verification；有挑战 secret 才加密，未记录任何值。

clientUid 是本地保留的 UUID 风格值，而项目当前每次时间戳生成；静态不同尚不能证明强制持久要求。图片天然尺寸、坐标允许误差、有效期和挑战重用规则仍待合法样本。此研究不提供验证码绕过，也不取消用户操作／写前确认。

### 7.4 下一阶段纠正顺序

先把以上表达式固化为合成 fixtures：page0边界和多页；day首项与选择日不同；info/string ID 与 submit/response ID 分阶段；null／省略／非空组；repCode/success/冲突字段；330显示到310协议坐标；tradeNo与计时／可选验证。现存 Apple signature golden 不能当这些新表单字节已验。

再以本人手动完成的合法样本确认服务端行为，不自动探测占槽／取消、不盲目重发。保留“写前 guard 在首个 info POST 之前；一次提交；未知结果查单；有界分页＋日期/空间/时段/状态匹配”的项目安全规格；官网本身缺强回查不是降低规格的理由。

## 8. 阳光打卡：新增明确的手动提交需求（本轮不写）

用户后续明确要求“阳光打卡需要写操作提交的功能”，因此不再把提交永久排除或只做P2查询。下一阶段P1范围是**本人真实活动→手动填写→照片→公开性确认→单次提交→记录回查**；本轮仍仅静态研究与文档，不执行上传／打卡，也不把需求理解成自动打卡、补卡或造假授权。

### 8.1 新增静态来源

按 YM runtime 确认的文件名匿名下载，未执行脚本；偏移仍为零基 UTF-16半开区间。

| 代号 | `https://ygdk.buaa.edu.cn/js/` 下原文件 | 字节数 | SHA-256 |
| --- | --- | ---: | --- |
| YS | `chunk-0a609116.4bc124df.js` | 26338 | `5162f0e6161f67cd06b8e9ec57d48507bc30fa28659e516b323095dbcafc17cd` |
| YA | `chunk-e3cb01c4.390ee340.js` | 27501 | `ba80ab32f5d5bb07696ce67f6a9a4c8d5785499bd604dc89da0ea1dad0b90983` |
| YC | `chunk-4d954bb1.4142bd70.js` | 316855 | `3aa242712acdc2cb9de477506b19102dc35592e77a2137937aa78525e387d015` |
| YD | `chunk-15920974.d1ec8577.js` | 216548 | `18e7c9cfb367ea99c18c8687746dd85dd7ccec710adca2ca0ccacc613ed250e6` |

REA选定YS/YA部分图parent `ev_34e2ab0a98f45514801a19b36088bd7af7c4e7de9521ece624a978da7ba2c460`：160 semantic unknowns达预算、21文件未选。不因图显示已穷尽当前view就声称全系统已恢复；目录摘要变化来自追加文件，不是原站版本已更新的证据。

### 8.2 认证、读取与统计更新

YM/1172 3996–5231列逻辑路径：记录 `/Front/Clockin/Clockin/getList`、统计 `/Front/Clockin/Clockin/getCount`、详情 `/Front/Clockin/Clockin/get`、打卡 `/Front/Clockin/Clockin/clockin`、上传 `/Front/Upload/File/post`、点赞 `/Front/Clockin/Clockin/praise`。YM/14ac 7000–7081根据页面origin/path构造base再拼api；这里是静态路径，**完整最终URL仍需实网确认**。

YM/1172 5343–6142将非登录get包装转POST并合并身份字段，响应6142–6608按code==1解result.data/list/total；不能按POST一刀认写，也不把身份存储依赖安全性当已验。提交中已带UTP，拦截器还合并，实际线缆重复字段／编码需合法样本。

YH/7abe 1855–2196查询记录带page/limit10/本人范围/分类/可选起止时间，消费list/total。最初只看YM/YH时getCount仅路径；追加YA/4c28 **10160–10286** 已看到 `{classify_id,...UTP}`→getCount→sync_count，但只赋局部变量。现应修订为“单一统计字段消费已静态见，完整聚合周期／成功响应未知”，不是“完全没有调用”。YD/2860 **1792–2187**按record_id调用详情，消费images_fmt、时间、本人归属字段；没有读取真实记录／他人身份值。

### 8.3 两表单、字段与校验

| 范围 | 官方静态行为 | 下一阶段注意 |
| --- | --- | --- |
| YS/73d6 12617–12767；YA/4c28 8318–8488 | K含 start_time/end_time/place_type/place/isopen/form_time_fmt/images/classify_id/item_id/item_name；艺术加thought/issync。place_type初值1、isopen初值1、issync初值0 | 客户端domain模型不是照搬全K；冻结最终form类型与空值，公开性另做确认 |
| YS12869–13165；YA8596–8892 | 路由cid→动态分类，get_clockin_types/get_notice page1/limit1000；item_id取返回项目 | 不硬编码ID，不将入口可见性当授权；公告和规则先展示 |
| YS13233–13509；YA8899–9175 | 同日日期＋起止时分，用moment format X生成Unix秒字符串，仅本地检查结束>开始 | 明确学校时区、跨天／未来／最短时长／补录政策仍未知；不凭picker推允许补卡 |
| YS13509–14229；YA9175–10060 | 检查时间、地点、至少1图；艺术issync==1需thought | 项目type初选变量未初始化、艺术疑似检查错字段，不能复制验证漏洞；thought UI max250不是已确认服务端上限 |
| YS17077附近；YA13127附近 | 地点类别1校内/2校外，place用户手填 | 已读链无坐标／定位SDK调用，不因此新增定位权限，也不伪造位置；宿主/服务端未知留待核 |
| YS18366–18574；YA14416–14625 | JPG/JPEG/PNG、多图最多3、每图5MiB，提示本人出镜照片 | 相册或用户主动相机最小权限；不自动抓相册，不生成或篡改证明照片 |
| YS18930–19703；YA14994–15740 | isopen1公开到广场／0不公开，官网默认1 | 自有客户端可**请求默认关**，但必须确认后端是否允许及私密提交的业务效力；验证前不得标成“已私密”，无法验证则阻断真实提交 |

艺术issync在已读代码未见可达切换路径，只有初值、校验和thought条件控件；某个弹窗称同步博雅不能证明完整同步协议可用。首期不承诺博雅同步，不自行把issync设1。

### 8.4 上传也是业务写，提交成功与计数分开

YS14316–14600、YA10363–10650：逐图FormData字段file→postFile(逻辑file_post,UTP,form)，Promise.all并行上传；返回每个file_name拼数组，再JSON.stringify赋K.images。没有表单层压缩／重编码／EXIF剥离逻辑，不能称官网已处理照片元数据；底层组件／OS转换未知。

随后一次POST逻辑clock_in，body为UTP＋K＋所选项目item_id。YS回包取period_id/term_id/week_count/week_num，YA取period_id/term_id/month_count/month_num；非周期和周／月超额提示**在提交之后**，优先于record_id判断。警告不是前置拒绝，不能自动重发为“再试计数”。普通分支检查record_id再本地提示成功；官网跳首页而不强回查。

两业务模块未见显式单飞锁、loading先验、业务catch/finally、幂等键或自动重试；遮罩不能证明严格防双击。上传封装new Promise(async...)异常可能悬挂，console输出响应／文件对象不应照搬。部分上传成功后提交失败存在残留；没有查到授权删除残留文件契约，不能猜删除接口。

### 8.5 拟议手动写安全门禁（不是已实施能力）

- 写前确认包含活动类型／项目、真实时间、地点类别与文本、照片数量、是否公开、艺术附加字段；照片上传前即触发用户同意和账号绑定。拍照／选图不自动上传。
- 一次授权至多一个上传批次＋一个clockin；应用层单飞锁覆盖全部批次。重认证不重放写，断网不排队后台补发；所有上传／提交自动重试关闭。
- 分别标记“上传未发／部分上传／上传完成未提交／提交发送中／结果待核实／已记录／计数受限或待规则核验”。接口成功与有效考勤／周月计数／博雅同步拆开，不用一个绿色成功统包。
- 取得record_id后可按详情候选只读回查并匹配本人、类型、时间、项目；尚无实测强匹配契约。丢响应时只给本人记录人工核验，不用模糊列表匹配证明成功，也不因空列表认定未提交。
- 相册、相机、临时照片留存、EXIF／压缩政策单独评审；不做未证实的变换或对外分享。不预加载私人照片，不把姓名／具体地点／感想／图片URL写日志或公开fixtures。
- Windows无法满足学校真实要求时明确官方回退，不伪造宿主或坐标。当前证据无需定位；未来若确有要求，另审能力与最小权限，不暗加SDK。

尚未验证：真实最终URL、服务端字段类型／必填／时区／校历、认证合并和安全校验、上传权限与残留处理、图片元数据、幂等／限流／审核、隐私开关与计数关系、成功后可见延迟、宿主定位能力。本轮不请求任何真实照片、不上传、不提交。需业务合成契约和用户另授权真实写入验收后才能称功能可用。

## 9. 可加入能力与取舍

| 阶段 | 能力 | 依赖／风险门禁 |
| --- | --- | --- |
| P1 | 公开图书检索、书目与馆藏、新书 | search样本已读；内嵌JSON、编号、状态映射、分页／配置尚需 fixtures；不执行借阅写 |
| P1条件 | 本人当前借阅／到期只读 | 成功空已测；非空、过期、隐私、完整性仍需样本；默认内存，提醒持久化另审 |
| P1条件 | 校车班次／查询时余票、官方通知时刻 | UI已见；网络形状、身份／保留／时区／摆渡分支待补；不把票数变成购票保证 |
| P1 | 现有作业／课表／空间查询可靠性和入口整合 | 不为扩容拖延明确的截止筛选与状态修正；CGYY先合成契约，不未经确认改写 |
| P2 | 官方热门分类榜、就业／办事公开指南、考试／全校课表 | 热门方法已静态但统计口径未明；其他多为入口证据，逐源确认 |
| P1（明确需求、写门禁） | 阳光打卡手动填写／照片／确认提交／记录回查 | 静态链已定位；先合成契约／隐私评审，再另授权真实写验收；不自动打卡、不默认公开 |
| 官网入口候选 | 校园卡、报修、注册／请假、证明／打印、健康／心理、柜／图书馆研讨间新写系统 | 目的地／身份跳转需验证；不把仅入口名变成可用本地功能，不默认加载敏感值 |
| 排除 | 支付／充值／退款代理、自动抢票／占座／续借／打卡、代审批／作答、他人数据聚合 | 不作为本次研究自然延伸，不实现也不发试探写 |

工作台不承载所有来源卡。用“全部服务→领域 hub→具体动作”承接扩容，维持已有主题、状态语言、稳定 ID 和按账号偏好；布局详见独立 IA 文档。学院／图书／生活的名字是客户端组织提议，不是假称上游统一服务模型。

## 10. 可追溯证据索引与剩余缺口

| Evidence ID | 范围／用途 |
| --- | --- |
| `ev_6ae06390983301f2d2b1da6f27f0d9a3f8856b5a4f2471db086abc80073d58be` | 本机 plist |
| `ev_46c4626a8db830dc0495da3d3b071cac101e906b31ef15cbe4807ab3968d9152` | 安装包完整 inventory |
| `ev_d27dd5beffb527ab49a2d1d6a1e89b5fd07e2f516c14369da80cd264066ce306` | Mach-O 分析 parent，符号覆盖有限 |
| `ev_bbbc091dc7282a56ee87e46648ead92bf4e88c12563e5099285bb640a87548cd` | 旧安装资源部分 JS 图，取消／预算限制 |
| `ev_473830daec42cd1cf581c0f3b26aa3495822971e22e4ff74e5915236baf6e76e` | 原生Chrome五页目标元数据（不含业务成功声明） |
| `ev_066711835975914a82dc8fe4a2d01d7f848425bcf0e4b572d14674f00325b0cf` | 校车被动资源／脚本元数据 |
| `ev_97a5a34f7ec6ebeb0f72de787c032b64adce1b71fb86b4bce489a118ff7d45a2` | CGYY被动资源／脚本元数据 |
| `ev_23fc487cfbb3d3ff2fec063982927f5cc3be75ea522f099bfae9ab47ac3c03bd` | 公开脚本下载摘要；后续chunks见§4原站+SHA |
| `ev_f50277843286f644c8951b50897be5d6815ebc25e8547579a3376d377be8ea7c` | 新选定chunk部分静态图 |
| `ev_5671aa4b440529e3b2d4ab917c2a0175421476831c3930c0a4fced778e15f671` | 匿名图书读取的字段类型投影；rendered terminal受输出预算限制，不宣称完整原始响应 |
| `ev_0d5a71314b745a797d632276369d5f5cc6e7a7ad814d5263166b09594c97c67e` | 本人loans成功空／loan_info字符串，原文不落盘 |
| `ev_f2b86d355696c003ffb8acb0f3d26eb92d2da68884e6383fc63ece7f99a3af76` | 用户校车查询后页面AX，列表12班与不同余票，非事务原文 |

这些 ID 是 REA 会话证据，不保证永久外部下载；报告另列原站／hash／偏移以便复核。报告中的直接 CDP、curl 表达式精读与 REA 静态图是不同证据来源，不能统称全由自动图推导。

剩余取证：图书配置／排序／非空借阅／状态和封面；CGYY合法提交前后的脱敏网络与生命周期（需另明确真人写授权）；校车完整单次查询响应形状及权限分支；新增入口的真实目的地／登录边界。未完成不靠名称补猜，不提前加入可用 UI。

## 11. 文档交付边界

本次输出审计、API 断言修订、设计方案增补与 IA；不把它们计入应用已实现／真机／TalkBack／真实写入验收。文档验证包括相对链接、围栏、换行、尾随空格、Git diff 范围和隐私字段人工复核；不运行无关业务构建。浏览器继续由用户持有，本轮完成也不退出它。

### 11.1 2026-10-23 文档评审复核

- 重新匿名下载审计列出的 16 份公开前端文件，字节数与 SHA-256 均与 §4／§8.1 表一致；未执行页面脚本。
- 复核匿名图书读取：`search`、`hot1`、`new/books`、`holdings` 均为数值 `code=0`，馆藏 `data.holdings` 为可二次解码的 JSON 字符串；本机响应形状与 §5 一致。
- 在用户自行登录的图书馆读者页复核 `loans` 与 `loan_info`：均为 HTTP 200／`code=0`，`loans.data.items=[]`，`loan_info.data` 是字符串；未记录任何个人字段值。
- 一次程序化触发校车查询返回 HTTP 403／空响应体，页面显示“网络异常”，未取得完整事务；该失败不作为协议结论，也不把既有页面列表升级为接口成功样本。
- 本轮复核只用匿名／本人已登录的只读查询；没有执行预约、续借、购票或打卡写请求。
