# SPOC 作业详情、附件与提交可行性探查

日期：2026-10-25。范围：Android / Flutter + Rust；不开发冻结的 Apple 客户端。

## 结论与证据边界

**可以继续集成研究；当前不是已实现或已通过真实写入验收。**

- 用户授权账号登录成功，实际打开学生学习 → 作业库 → 一项学生课程作业详情。页面有教师附件、总分、文件上传方式、无限次提交、精确起止时间及“去做作业”入口。这里不保留姓名、账号、课程/作业标识或截图。
- 未选择或上传文件、未点击正式提交、未修改已有提交。未保存原始 HAR、Cookie、token 或学校个人响应。
- 当前公开 SPA 的路由 → 页面组件 → API 导出 → 请求包装形成了可定位的静态调用链，强于过去仅发现未导出的包装函数；**不等于已观察实际提交请求、后端成功条件或回查一致性**。
- 浏览器探查在详情页之后中断，因此没有把提交编辑页记为实网已验收。

## 公开资源定位

来源均为 `https://spoc.buaa.edu.cn/spocnew/js/`，下列 SHA-256 只绑定本次下载字节，不保证网站未来不变：

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `app.c5dc702c.js` | 2252654 | `5948f338c36a9925426fe7e563be5ecc43ae890564f571232cd05e9552d1d6df` |
| `chunk-5669dd74.6bab02af.js` | 21257 | `cc31da15d5beb39dc78418b3403669be130dcb8fefccded6fb716825041a9d62` |
| `chunk-8b944e98.0b2ea7d4.js` | 28884 | `a4a8f9c857a86039348185d0d305164f3e65aef89b3d7a0a9dafe2f0a41c38bb` |

另检查 `chunk-6b38d5f2.2b9369cc.js` 中 `f86c` 的提交内容组件。公开 bundle 不入库。

## 已定位的调用关系（静态证据）

### 学生作业详情与更多信息

- 路由 `workinfoxs/:zyid/:lmid?` → `chunk-8b944e98` / `1506`（WorkInfoXs）。
- `getZyInfo()` → API 导出 `wd` → `GET /spocnewht/kczy/queryKczyInfoByid?id=...`。
- `queryXsSubmitKczyInfo()` → 导出 `ie` → `GET /spocnewht/kczy/queryXsSubmitKczyInfo?kczyid=...`。
- 教师作业字段：`zyfjid`、`zyfs`、`bhtjlx`、`xztjcs`、`bjmcarr`、`zykssj`、`zyjzsj`；提交页还使用 `xzwjlx`、`zswjid`、`sskcid`。
- 详情页以 `sfzysjn` 判断开放状态；`pyfs == "2"` 显示教师完成打分不可再做，`xztjcs == 9999` 显示无限次。以提交结果 `ytjcs` 计算剩余次数；`tjzt == "-99"` 单独显示“退回”。这些是官网 UI 逻辑，不是完整状态码枚举或授权保证。
- “查看提交内容”打开 `ZyTjInfo`（`f86c`），仍读上述两个详情接口：按 `tjlx` 选择 `mtlywjid` / `pzwjid` / `scwjid`，还有 `fjxx2List` 评阅附件、`pfbzwjid` 评分标准文件。并未证明所有作业都返回这些字段。
- 文件元数据：`getFileInfo(id)` → `POST https://spoc.buaa.edu.cn/inco-filesystem/fileManagerSystem/queryFileById?wjid=...`，包装设置 form Content-Type、Token、RoleCode，参数在 query 中；下载使用同文件服务 `/fileManagerSystem/downLoadFile?scjlid=...`。**POST 不一定是写操作**；这里是元数据读取包装。
- 正文空白不等于无作业要求：本次实际详情中的要求由教师 PDF 附件提供。

### 提交

`WorkInfoXs.toNewUp()` → `mycourse/coursecenter/newup` → `chunk-5669dd74` / `61b4` → `save()` → `d891.hf` → 包装函数 `T` → `POST /spocnewht/kczy/submitKcz2`，`application/x-www-form-urlencoded`，`qs.stringify` 编码。

- 提交页加载详情额外传 `id`、`sskcid`、`falg: "xstj"`（拼写照官网）。
- 方式映射：1 文本 `wbsrnr`；2 URL `wzurl`；3 录音 `mtlywjid`；4 注释 `pzwjid`；5 文件 `scwjid`。
- `save()` 合并 `{kczyid: workid}`、`formData` 和 `{tjlx: formData.tjfs, ytjcs: 2, xztjfs: route.params.xztjfs, ssxzid: route.params.teamid, sskcid: data.sskcid}`。`formData.tjfs` 亦保留；文件回调还设置对应 `_name` 字段。
- `ytjcs: 2` 是官网代码字面量，**不能解释成可提交两次或可靠计数**。未验证缺省字段经 stringify 后的实际请求形态，不能直接据此冻结客户端契约。
- 成功分支显示“操作成功”并返回详情；仅此不足以判断上传/提交已持久化。必须回查并比较实际提交内容/文件 ID。
- 小组作业另有 `newup1`、任务/组长条件；首版应明确不支持，不能套用个人作业协议。

### 上传并非编辑器图片上传

`61b4` → `67186`（InconUpload）→ `ace4`（GlobalUploader）→ `fileSuccess` → `uploadFile(files, field)` → `files[0].id` 与 `files[0].fileName` → `formData.scwjid` / `scwjid_name`。

当前配置文件服务基址为 `https://spoc.buaa.edu.cn/inco-filesystem`：

- 分片目标 `/fileManagerSystem/uploadFile`；`chunkSize: "2048000"`，文件字段 `file`，`testChunks: true`、`maxChunkRetries: 3`，请求带 `Token: Inco-...`。
- 文件 MD5 被用作 `uniqueIdentifier`；响应存在 `mc` 时取 `data`（可复用文件分支），否则调用 `POST /fileManagerSystem/mergeFile`。
- merge 参数：`identifier`、`filename`、`totalSize`、`czxt`、`czmk`、`czr`、`cclj`，取合并结果加入 fileList。
- `accept` 来自作业 `xzwjlx`，组件有 `acceptdx` 大小限制支持；本次**未确认作业后端大小上限**。
- 分片完整字段、GET 探测语义、边界片大小、响应成功码、合并失败与取消后孤儿文件清理仍未知。MD5 在这里是分片标识，不是安全完整性证明。
- 不得把 TinyMCE 的 `uploadFullfile` / `editorUploadFile` 当作学生作业附件链路；官网分片自动重试也不授权 Ginkgo 对最终提交自动重试。

## Ginkgo 当前接入点与推荐设计

现有链路：Flutter homework_detail_page → Homework gateway → FRB → core Workspace → domain `HomeworkSource` → upstream `homework_service` / `adapters/homework_http.rs` / `codecs/homework.rs`。

当前 `HomeworkDetail` 只保留正文、时间、分值、状态及官网入口。已有两个详情接口，无需为更多字段另造业务中转服务。

推荐分层（不是新增重复待办清单）：

1. 优先只读详情增强：有类型的教师/已提交附件、提交方式、限制、次数、退回/批改信息；未返回与不支持保持可空/未知。详情部分读取失败不伪装为空成功；合成 fixture 与响应类型漂移测试先行。
2. 附件下载：新增受限流式二进制传输，鉴权 URL 不直接交给无会话外部浏览器。验证重定向、域名、文件名、大小与 Android 文件保存权限；WebVPN 使用同一会话和路由。
3. 上传：Flutter 文件选择 / URI 适配 → 有界流/分片 → upstream 上传服务；domain 给出上传凭据的业务句柄，不暴露学校 token 或任意 URL。
4. 最终提交：独立 `HomeworkMutationSource`，确认页展示课程、作业、文件、截止和覆盖风险；提交前复读权限及次数，阻止助教/未知归属及小组误提交。上传成功只显示“已上传、尚未提交”。
5. 提交单次发送；超时返回结果未知，回查 `queryXsSubmitKczyInfo` 与文件 ID，**禁止自动重发**；处理账号切换、并发点击、过期、取消和缓存失效。

关键工程缺口：`foundation/http.rs` 的 `HttpRequest.body: Option<String>`、`HttpResponse.body: String` 不适合任意二进制 multipart 和文件下载；须扩展请求/响应及 transport/WebVPN 原样转发测试，不能用 UTF-8 字符串承载文件或只改页面。写后回查还需功能读写排他及账号代次约束。

## 仍需何种验收

在明确选定作业和最终文件后，由用户正常操作官网完成一次授权上传/提交，或使用学校提供的测试环境，捕获脱敏的分片/合并/提交/回查形态。没有可安全撤销的测试作业时，不使用真实课业做空白或占位提交。需覆盖首次提交、已有提交覆盖、截止/次数耗尽、退回、大小/格式拒绝、上传中断与最终提交超时。当前只证明技术可行方向，不宣称后端写入闭环验证完成。
