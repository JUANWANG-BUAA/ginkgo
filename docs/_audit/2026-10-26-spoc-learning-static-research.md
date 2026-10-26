# SPOC learning 静态协议研究（草稿）

日期：2026-10-26。范围：当前未提交的 `ginkgo_upstream/src/adapters/learning` 与 `codecs/learning`。

## 1. 证据边界

- 第一阶段只读本地公开 SPA 静态文件、指定的前轮脱敏形状日志及仓库源码；第二阶段按父代理追加授权，匿名 GET 了当前 E1 hash-map 指向的 7 个官方公开 JS（见 §10）。**没有登录、没有业务 API 请求、没有学校写操作、没有查看凭据或个人业务数据文件**。未修改代码。
- 下文“静态确认”仅表示学校前端发布代码含该构造/字段读取，不表示服务器本次接受该请求，也不证明所有分支无副作用。
- `/tmp/ginkgo-learning-probe2.log` 是**前轮**结果，不是本轮实测。该日志只给 path/status/code/content 形状，未保留完整请求参数/方法，因此不能用它倒推缺参也被正式支持。
- 未读取其他个人日志/抓包/课程数据；不记录账号、课程、栏目、文件或个人标识的实际值。下文 `kcid`、`nodeid`、`id` 等仅为字段名/变量。
- 本稿是来源研究，不把推测写进 `docs/API.md` 的已验收结论。后续协议修正需单独更新唯一事实源及修订表。

## 2. 文件身份与复查方式

E0 `/tmp/ginkgo-spoc-index.html`：SHA-256 `9e0ee46431b49a476ae2431d5cbb26a4615462bf6afe7fbff8fff9cf5bf5203e`。HTML 引用 `https://spoc.buaa.edu.cn/spocnew/js/app.c5dc702c.js`。

E1 `/tmp/ginkgo-spoc-app.js`：SHA-256 `5948f338c36a9925426fe7e563be5ecc43ae890564f571232cd05e9552d1d6df`。

以下本地公开 JS 具有 webpack chunk/module 声明；E1 runtime 的 JS hash map 给出对应发布文件名。这里只核对本地内容与声明，不声称本轮从网络重新取得这些文件。

| 证据 | 本地文件（`/tmp/` 下） | E1 JS 映射文件名 | SHA-256 |
| --- | --- | --- | --- |
| E2 | `ginkgo-chunk-53b053d4.js` | `chunk-53b053d4.8a266977.js` | `aba26052534bc81ab1801a660cba92dd775a1caf7e5657eccdf60e9fc99528c2` |
| E3 | `ginkgo-chunk-87feec84.js` | `chunk-87feec84.65ad6ecc.js` | `100fd5dfe459e111eb40ed3b3a6abe0bd5da63ec5332ae4187a35f5a5ad69135` |
| E4 | `ginkgo-chunk-4f0c6c5c.js` | `chunk-4f0c6c5c.a389b57b.js` | `96194ff7faca9d6b35e2adf59c6804433fb48814b3ce4de2a1252e45fb10032b` |
| E5 | `ginkgo-chunk-6bb3159b.js` | `chunk-6bb3159b.b241d2d5.js` | `73532b172ecbbbe8e1fbbc2fb032aebc3a660af42dbf8f5bcf0668da423952f7` |
| E6 | `ginkgo-chunk-61640d18.js` | `chunk-61640d18.3a0b9b9e.js` | `1d9585a1cb97041d7862c3865ede8abae4dae1300417d1551f44e024945c3588` |
| E7 | `ginkgo-chunk-5d2e1dd8.js` | `chunk-5d2e1dd8.5dc1fdf7.js` | `830764000c76a264e75b49f2e7b23149a709908d02f0cbe7e000c0fb42db1807` |

主要文件为压缩单行；用 webpack module ID、函数名与精确字面量复查比引用“第 1 行”有效。下列 offset 是 Python 解码 UTF-8 后的 **0-based 字符位置，非字节地址**，只用于辅助定位，模块/字面量为主。

## 3. 公共请求层

E1 `d708` 设置 `apiBaseURL = https://spoc.buaa.edu.cn/spocnewht`、`uploadBaseURL = https://spoc.buaa.edu.cn/inco-filesystem`。

E1 `b6bd`（起点约 1337770）建立 Axios 实例：

```js
m.defaults.headers.post["Content-Type"] = "application/json";
m.defaults.headers.get["Content-Type"] = "application/x-www-form-urlencoded";
// request interceptor: Token = "Inco-" + token; RoleCode = userinfo.jsdm
// response interceptor: code === 200 时 return content
```

这是静态协议形状，不读取上述存储值。`data:{...}` 在普通请求层是 JSON 对象，`params:{...}` 在 URL query；显式 form 接口除外。Axios 实际序列化字节未在本轮抓取，不能把 JS 数字/字符串类型当服务器唯一可接受类型。鉴权头和包裹 `code/content` 与现有 homework request/content 复用一致。

## 4. 课程列表

### 静态 API

E1 module `9a8c`：导出 `s → c(e)`（端点约 1115144）：

```js
return request({url:"/kc/queryXskcListPage",method:"GET",params:e});
```

当前 adapter `learning::courses` 用 GET、query `pageNum/pageSize`，与该透传形式一致。前轮日志形状确认 content 是 PageInfo，包含 `list/pageNum/pageSize/hasNextPage/total`；行含 `kcid/kcmc/xnxq` 字符串、`jsmc:null`，另有 `kcfzrmc` 字段。

### UI 调用证据限制

E1 dynamic import map 把 `./mycourse/index` 指向 module `d412` / `chunk-cbf73164`，当前 JS hash 为 `62331701`；该 chunk 不在本轮已有的公开 JS 文件集合，因此**没有在当前 c5dc702c 版本独立复核 getXsList UI 函数**。

历史仓库记录 `docs/_audit/2026-10-21-spoc-course-roles.md` 的 E2 是另一个版本：`mycourse/index.getXsList() → 9a8c.s(pagetion)`、默认 `{pageSize:100,pageNum:1}`，`list → dataList1` 学生分组、卡片取 `kcid`。这是**历史静态佐证**，不能冒充当前版本本轮证据。

### 字段结论

- `kcid/kcmc` 与分页元数据：前轮非空形状支持。
- `jsmc`：前轮为 null，当前 optional 可容纳；但把它当“任课教师”可展示字段仍未确认。`kcfzrmc` 只是候选“课程负责人”字段，不应未经证据替代为授课教师。
- `xnxq` 存在不等于展示学期名称；其值语义、`xnxqmc` 空值、source URL 的浏览器可达性仍未验收。
- 50 页上限、跨页重复 ID 拒绝是本地策略，不是学校协议保证。

## 5. 公告列表、详情、附件

### API 与 UI（当前版本静态确认）

E2 module `5373` / `coursecenter-gg-xs`：

```js
getKcgglistPage() {
  d891.Fb({sslmid:this.nodeid, kcid:this.kcid, sfxs:1})
    .then(content => this.noticeList = content);
}
showXq(id,index) {
  request({url:"/kcgg/queryDgKcgg",method:"POST",data:{id}})
    .then(content => { this.xqData = content || {}; this.xqModal = true; });
  // 网页另外有标读 GET；只读客户端不可照搬。
}
```

E1 module `d891` 的 `Fb → se(e)`：`POST /kcgg/queryKcggList`, `data:e`，普通 JSON 请求。E2 getKcgglistPage 约 7533、详情字面量约 7299。E3 module `ca77` 的教师公告页面亦传 `sslmid/kcid/sfxs`，学生条件使用 1，不是凭空挑选。

列表 render：`noticeList[]` 的 `id/bt`；`fbzt == "1"` 时显示 `fbrmc/zhxgsj`（标签“发布时间”），否则显示 `fbrmc/cjsj`（标签“创建时间”）。

详情 render：`xqData.nr` 作为 HTML；`xqData.fjlist[]` 中 **`wjid/wjmc`**。下载按钮把 `wjid` 传入：

```js
window.location.href = uploadBaseURL + "/fileManagerSystem/downLoadFile?scjlid=" + id;
```

故附件下载静态是浏览器 GET/navigation，base 为 `inco-filesystem`，参数 `scjlid` 取附件 `wjid`，**不是资源行 id 与 grwj1 路径**。E2 downloadFile 约 7790，E3 亦同。此导航未显式设置 Token/RoleCode；当前客户端额外带头的效果未验收，不能由网页调用证明其必要性。

### 只读红线

同一学生 `showXq` 会在尚未读时另调用 **GET `/kcgg/updYdb` query `{id}`** 并本地设置 `dd=1`。它是标读写语义，不能因 HTTP GET 自动当只读。现有 adapter 不调用它是正确边界，应保持。

### 候选对照

- `announcements::list` **遗漏静态 UI 的 `sslmid`**，只传 kcid/sfxs 不能宣称完整复现网页栏目列表。服务器是否允许省略并返回全课程结果，本轮未知；前轮空数组不能证明完整性。
- codec 取 `fssj` 为 published_at **无本次公开 UI 佐证**；当前发布态 UI 明确取 `zhxgsj`。这属于展示映射不符，不能称服务器永不存在 `fssj`。
- `nr/fjlist/wjid/wjmc` 有直接 render 证据，现有候选对应正确；详情 `bt/id` 的响应必有性未由本轮非空响应确认，不能用列表字段证明详情一定重复这些字段。
- 前轮公告仅空数组；没有详情/附件非空日志，附件字节、MIME、权限、正文 HTML 可空/漂移均未本轮实测。

## 6. 资源根列表与子目录

E7 module `a2ee` / `coursecenter-kcwj` 用 `xsst==1` 选择学生 component `c630`。E4 module `c630` 学生资源 `doQuery`（约 11637）：

```js
params = {
  pageNum: pagination.current_page, pageSize: pagination.pageSize,
  pid: currentId, mcTab: queryPara.ssvalue, kcid,
  lmlxdm: queryPara.lmlxdm, wjlx: queryPara.wjlx, pxfs: queryPara.pxfs
};
// sfwjj == "1" -> 646e.j(params)
// 根且 sflx == "2" -> 72b1.f(params)
```

E5 API module `646e`：`j → s(t) → POST /grwj1/queryKcwjListgr`, **params:t（URL query）**。
E5 API module `72b1`：`f → s(t) → POST /kcwj/queryListPageXs`, **params:t（URL query）**。
根的非学生分支调用 `72b1.e → /kcwj/queryListPage`，不应混进学生协议。

初始学生 state：`sfwjj:"0"`、`currentId:0`、分页 `pageSize:10/current_page:1`。`selectFun(row)` 仅在 `row.sfwjj=="1"` 时设置 `currentId=row.id`、`sfwjj="1"`、回第 1 页重读。故当前候选根 `pid=0` 与初始 UI 相符，子目录传 **row.id** 与单独 endpoint 也相符。候选 pageSize=20 是本地选择，不是本次 UI 默认值；query 漏 `pxfs` 与 UI 形状不完全一致，但 UI 初始也未显式初始化 pxfs（可能 undefined 被省略），不能断言为服务器必填。

学生 UI 用 `content.list/content.total`，资源行读取 `id/wjmc/sfwjj/sfkxz/wjhzm/czsj/lmlxdm/lmmc2/mlmc/wjsize`。`sfwjj=="1"` 画文件夹；非目录按后缀选图标；`sfkxz=="1"` 显示下载按钮。资源 codec 当前主要字段与这些静态读取及前轮根列表非空字段形状一致。前轮日志未区分根/子目录 path，也未保留筛选参数，**不能拿它证明子目录已验收**。

`hasNextPage/pageNum` bool/number 在前轮资源形状存在，支持当前 codec 分页。所有 flag 值范围、目录是否一定只用 0/1、根/子目录字段完全一致及严格 requested page 相等仍是待验证点；UI 比较用 `"1"` 而非对范围作完整校验。

## 7. 资源下载权限与下载 method

E4 module `c630.downloadFile`（约 10700）和 `downLoadFiles`：

- 单文件先 `646e.l({ids:row.id})`；E5 `646e.l → j(t)` 是 **GET `/grwj1/getWjids` query params**。
- 返回 content 的 `flag == "0"` 展示 `msg` 拒绝；`flag == "1"` 才继续文件下载。`getWjids` 不应被理解为返回文件 ID 列表；在该 UI 分支它是权限 gate。
- 单文件放行后 `145c.a("/grwj1/downLoadFile?id="+row.id, {}, row.wjmc)`。
- **E5 module `145c.d` 明确 `method:"POST"`、`responseType:"blob"`、`data:{}`，Token/RoleCode 头。** query id 在 URL，不是表单 body。这是与当前 `learning::binary` 的 GET **确定静态 method 不一致**。不能进一步推断服务器 GET 一定拒绝，因为本轮未试。
- 多选先 getWjids，放行后 POST `/grwj1/downWjZip?ids=<逗号连接 row.id>`；单目录走 POST `/grwj1/downWjidZip?ids=<row.id>_0`。目录分支没有上述单文件 gate。这里只记录静态差异，不建议增加未经授权的批量下载或把 `_0` 套到单文件。

候选当前以 `sfkxz==1 && !folder` 才可下载、并二次检查 getWjids，属于保守策略；不支持目录下载不是协议错误，但不应写成学校绝对禁止目录下载。候选 20MiB 上限、HTTP 200/拒绝 JSON/HTML 是本地安全策略，不是已验证上游契约。

## 8. 测验只读列表（不能进入/开始考试）

E6 module `5798` / `coursecenter-ktcs` 按 xsst 选择学生 module **`4ec3`**；学生 `getKccsList()`：

```js
d891.z(qs.stringify({kcid:this.kcid, flag:"xs", id:this.$route.params.nodeid}))
  .then(content => { this.tableList = content.list; /* 标题可取 kczxdhlEntity.lmmc2 */ });
```

E1 `d891.z → At(e)`（端点约 1585723）：

```js
request({url:"/csgl/queryCsglXsList",method:"POST",
  headers:{"Content-Type":"application/x-www-form-urlencoded"},data:e});
```

所以 **POST、form body、`kcid/flag=xs/id=nodeid`** 有静态端到端调用证据；不能把该 `id` 当测验 ID，它是当前栏目/route nodeid。

学生 render 读取 `id/csmc/kssj/jzsj/mf/treemlmc/sfygkssj/sfygjssj`，其中 `mf` 标签为 **“满分”**。候选 codec `id/csmc/kssj/jzsj` 与静态一致，`score <- fs` **未证实**：本轮 UI 不读 `fs`，前轮列表为空，既无个人得分字段证据，也无此分值类型保证。**绝不可用 `mf` 替换 score 当个人成绩。**

现有 adapter 只传 kcid/flag，**漏静态 UI 的栏目 id**。缺参空列表即使 code=200 也不能证明课程内无测试。UI 的“去考试”会导航 `mycourse/coursecenter/ktcsinfo`（带 csid/sfcs/sfxs 等）；本轮不跟进、不调用详情/开始/作答/试卷生成相关接口，不能宣称打开考试无副作用。

## 9. 修正优先级与未证实项汇总

| 候选位置 | 本次结论 | 证据 |
| --- | --- | --- |
| `adapters/learning/resources.rs` download → `binary(GET)` | 下载 verb 与发布 UI **确定不一致**；应在协议修正时区分资源 POST blob 与公告 GET/navigation，不能全局把 binary 改成 POST | E4 c630、E5 145c |
| `adapters/learning/announcements.rs` list | 缺 `sslmid`，未完整复现学生栏目请求；必填性/全课程省略语义未知 | E2 5373 → E1 d891.Fb |
| `adapters/learning/assessments.rs` list | 缺 `id=nodeid`，未完整复现学生栏目请求；不能以空列表验收 | E6 4ec3 → E1 d891.z |
| `codecs/learning/announcements.rs` fssj | 无本轮证据，发布态 UI 时间取 zhxgsj | E2 render |
| `codecs/learning/assessments.rs` fs | 个人分数字段未证实；mf 是满分，不能替换个人成绩 | E6 render + 前轮空列表 |
| `codecs/learning/mod.rs` jsmc | 字段形状存在但为 null，授课教师展示语义未知；kcfzrmc 也不能直接冒充授课教师 | 前轮日志 |
| `adapters/learning/mod.rs` courses pagination | GET/query 与 PageInfo 形状有依据；当前版本 UI chunk 未在本地，历史 UI 默认分页另记，不冒充当前实测 | E1 9a8c、历史审计 |
| `codecs/learning/resources.rs` | 主要字段有根列表形状与 UI 证据；严格 flag 范围、子目录非空响应、下载 flag 实际值待验证 | E4/E5、前轮日志 |

前轮 `/kczxdhl/queryKcdhlList` 为业务 code=400/content=null，仅说明当时请求被拒绝；本轮 E1 静态包装确认该接口 GET/params 透传，**没有足够证据修复其具体缺参**。不能把前轮拒绝作为栏目不存在，更不能因此省略栏目上下文并声称已复现 UI。

后续最小待验证证据应由获得授权的人工浏览器正常只读操作提供脱敏请求/形状：课程卡片→栏目映射、非空公告列表与详情/附件、根→子目录、单文件 gate 与下载、非空测验只读列表。禁止复制标读 GET、考试入口、上传、删除、同步、发布等写操作。自动化测试仅能证明客户端对这些合成形状的处理，不能替代上述真实证据。

## 10. 第二阶段补充：当前公开 JS 的栏目上下文来源

按父代理追加授权，本阶段仅匿名 GET 官方公开静态 JS：`https://spoc.buaa.edu.cn/spocnew/js/<下表文件名>`，使用 Python urllib 无登录、无 Cookie/Token、未调用任何业务 API、未执行抓取的 JS。以下本地副本在 `/tmp/ginkgo-public-<chunk>.js`。因此 §4“当前 UI chunk 不在本地”与 §9“没有足够证据修复具体缺参”是**第一阶段结论**，已由下述静态证据部分补齐；仍无本次业务实测。

| 证据 | 发布 JS 文件名 | 字节数 | SHA-256 |
| --- | --- | --- | --- |
| E8 | `chunk-338602ec.d9287a17.js` | 20563 | `f599d1d703e9d130bb6c2eff31e0609155d89f78e36ff8aec6160fa4575006a5` |
| E9 | `chunk-cbf73164.62331701.js` | 24483 | `825438db7e9cc1d7632b14933b720455d2e1eeb08548348109689b87d2fee363` |
| E10 | `chunk-942e330e.7fd8075c.js` | 28800 | `e3d4eca81ba56e3f3075815797515bfaa1230c6f4808dbfdc7c20b1e839a55d6` |
| E11 | `chunk-2d216257.69e90091.js` | 203479 | `309457acf6f23ca3955953aea06c272a2ee0a9718694f3c1cc8db7696ccfd8d2` |
| E12 | `chunk-40664da5.315adac7.js` | 483248 | `95dc5d3655260f7a62b3366d9783a6d7f0181f4bb0223b5d328a3bdb18a34cc5` |
| E13 | `chunk-6d22b2bc.4b7818ee.js` | 1898321 | `733e7e9d30fcf23f91113095056811c914700c9d8f5bb16203d5b5abc0c28c83` |
| E14 | `chunk-12d53628.d00c414d.js` | 9344 | `745f0c15005c1c7040e4606af279808564b4a785583203023dd0f32c971b5ed9` |

### 10.1 已补齐的课程列表与卡片公告入口

E9 module `d412` 的 `getXsList()` 当前版本直接调用 `9a8c.s(this.pagetion)`，`pagetion:{pageSize:100,pageNum:1}`，取 `content.list → dataList1`。这与历史记录一致，但现在已有**当前发布 chunk 的独立证据**。

E9 module `c9f8` / `course-item` render，公告按钮（字符位置约 5490）：

```js
itemBtn("tz", data, data.lmid_gg)
```

`itemBtn(type,course,node)`（约 11485）先 `d891.xc({kcid:course.kcid})`，然后 `tz` 路由为：

```js
"mycourse/coursecenter/" + course.kcid + "/notice/" + node
```

E1 `d891.xc → a(e)` 是 GET `/kc/queryYhSflx` params。此为业务 API 包装静态证据，本轮未调用。这里 `lmid_gg` 从**课程列表行**取得，而不是固定栏目名、课程 ID 或 `lmid_gg` 这段字符串。前轮课程列表形状确实列出 `lmid_gg`；其是否为空、类型/归属与有效性仍需样本验证。

E8 module `c5c3` 课程中心：`created` 调用 `d891.rc({kcid})` 后赋 `kcjbxxInfo`；E1 `rc → it(e)` 是 GET `/kczxdhl/queryKcxxInfo` params。该课程信息对象在切换学生视图的 fallback 读 **`kcgglmid`** 作为公告 nodeid（E8 约 16519），并非列表的 `lmid_gg` 字段。应严格区分两个响应对象的字段，不能凭相近命名互换。测验栏目未发现对应 `lmid_cs/cslmid` 直出字段证据。

### 10.2 学生栏目树的完整请求

E8 module `c5c3` 引用 `51d7` 为 teacher、`65e4` 为 student；学生 component 来自 E13。

**E13 module `65e4`（模块起点约 631769）`getKcjgList()`（约 635338）：**

```js
d891.sd({kcid:this.kcid, sflx:"2"}).then(content => {
  // content 为顶层栏目数组；递归处理 children
  // 对节点：title = lmmc2；对 children 继续映射
  this.kcLm = content.map(...);
  this.defaultTo();
});
```

**E1 module `d891` 的 `sd → u(e)`：**

```js
request({url:"/kczxdhl/queryKcdhlList", method:"GET", params:e});
```

所以学生树的静态完整请求是 **GET `/kczxdhl/queryKcdhlList`，query `{kcid,sflx:"2"}`**，不是 body，也不是 `sfxs`。sflx 是当前课程视图类型（这里学生为 `"2"`），**不等于账号 `RoleCode`**。教师 component `51d7` 的 `getKcjgList` 传 `{kcid,sflx:this.sflx}`，另 `getKcDhlList` 传 `sflx:"1"`；不能把教师路径用于学生。

前轮只带何种参数未完整保存，故本轮只确定**当前学生 UI 确实补了 `sflx:"2"`**，不能下结论“400 一定是缺 sflx”或“现在调用必定成功”。

### 10.3 树节点到公告/测验的确定静态映射

E13 `65e4.clickNode(child,index,parent)`（约 636576 开始）构造：

```js
params = {nodeid:child.id, title:child.title, isZjDhl:child.isZjDhl, kcmc:child.kcmc};
```

根据 parent/child 的 **`lmlxdm`** 决定路由：

| 父节点 lmlxdm | 子节点 lmlxdm | 路由 | 后续读请求的栏目参数 |
| --- | --- | --- | --- |
| `"0"` | `"01"` | `mycourse/coursecenter/notice` | E2：`sslmid = route.params.nodeid = child.id` |
| `"3"` | `"32"` | `mycourse/coursecenter/ktcs` | E6：`id = route.params.nodeid = child.id` |

父类别 `"3"` 下 `"31"` 是作业、`"33"` 是成绩中心，不要以父类别 alone 决定测验。不要用可编辑 `lmmc2/title` 的中文字样做唯一类型判断。学生默认 `defaultTo` 寻找 children 中 `lmlxdm === "01"` 的公告节点，路由的 `nodeid/lmid` 若存在则以它匹配 child.id。

这是完整的**静态流**：

```text
学生 GET queryKcdhlList(kcid,sflx="2")
  → content[] / children[]
  → 按父/子 lmlxdm 精确匹配对应节点
  → child.id 写入路由 nodeid（或读取既有 route lmid）
  → 公告 JSON sslmid / 测验 form id
```

生产只读实现可依据该来源取真实栏目 ID，而非猜 ID 或漏参。不过没有本轮非空树响应，字段可空性、ID 类型、树深度/多同类型节点与权限过滤均未验收。实际 UI clickNode 的选择是**用户选中的一个栏目**；若 API 返回多个相同类型栏目，不能静态推断只有一个，不能随意选第一个并称全课程完整。可显式暴露上下文/受控合并，或对歧义返回待确认，不可降级成无栏目参数请求再把空结果当无数据。

### 10.4 绝不能执行整套课程页面的副作用

本轮没有运行任何 component 或 JS。导航 component 同时含：

- `clickNode` 最后 `addKczxFwjl(child.lmlxdm)`，E13 `65e4.addKczxFwjl` 明确 **GET `/kc/addKczxFwjl3` query `{kcid,lmlxdm}`**，是访问记录写语义。只读客户端仅取树和列表，不能复制该 GET。
- `myTask` 调用 `d891.sf`，不属于本轮所需来源，未执行、未纳入安全只读白名单。
- 教师中心还有更新缓存、发布等写方法。只读证据提取只保留构造字面量，不触发。

因此“协议是 GET”不等于“可执行整个官方页面取证”。当前需要的 queryKcdhlList 本身在静态代码中作为树读取；是否读取也存在服务器侧隐式记录仍需要人审核，不由本次静态研究保证。
