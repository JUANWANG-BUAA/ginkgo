# Android CGYY 研讨室预约写操作闭环（2026-10-22）

## 范围与结论

本轮按用户“先把研讨室预约的写操作落地”的直接要求，完善 Android 主线 Flutter＋Rust 的教学楼 CGYY 预约／取消。不是图书馆 seminar，未修改独立 SwiftUI 产品、TLS、保险库、签名或发布版本；未执行真实预约、取消、签到或读取真实账号。现有入口和 native FFI 本已接通，本轮补的是可交付的表单、状态、故障恢复和防重复闭环，不重复建设另一套客户端。

本记录区分源码、离线合成、模拟器与真实验收。协议继续采用 API.md §6B 和既有 Swift/UBAA 证据；本轮没有新增学校端点、字段猜测、自动验证或学校网络探测。真实成功往返仍只能由用户逐次人工操作，见文末。

## 用户流程

1. 预约→研讨室→场馆／日期→填写预约信息。选择同空间最多 12 时段，手机 11 位、人数 1–100、用途以及主题／内容／参与人必填。
2. 第一次确认完整摘要：场馆、日期、空间、全部时段、人数、用途、手机、主题、内容、参与人和两项声明。确认后创建学校草稿，取消不执行。
3. 人工拖动学校拼图。图片无效、无有效正位移、challenge 已消费均不能提交；不自动匹配／绕过拼图。最终提交前再次显示完整摘要。
4. 最终预约只发送一次。写忙时系统／按钮返回均禁用，弹窗前同步门闩防叠窗；未保存表单离开先确认，选项只读加载可离开。
5. accepted 仅说明已查回记录，**不等于审批通过**；uncertain 明确结果待核实。返回后进入真实的预约记录页，不只刷新原场馆空档。
6. 预约管理依据明确订单状态、审批状态及开始时间提供取消；确认显示订单号／地点／日期／时段／状态。Rust 再强读复核开始前 4 小时及状态条件，不满足不发送。
7. 待核实保护在时段及订单页面可见。进入专门核对页，本次强读最近 20 条先显示；只有用户确认并再次确认解除后，携一次性核对 ID 解锁。失败、返回、刷新或仅查看记录不解锁，不自动重发。

取消人工验证／中途离开可能没有发送最终预约，但为防学校草稿或中断结果不明，先保留保护，再核对后解除；页面已说明这一保守选择。

## 三层写入保护

### 呈现与 native gateway

- cgyy_booking_page.dart：options加载与写busy分开；两阶段摘要、12段限制、草稿离开提醒、有效人工拼图、challenge单次、晚回包mounted保护。
- cgyy_page.dart：从Rust读取ready/uncertain，状态未知时禁写；提交返回订单；取消摘要与单次保护，失败后强读共享状态，不仅依赖页面局部布尔值。
- cgyy_review_page.dart：强读失败撤销本地凭据，不展示旧快照当本次成功；空列表有“不能证明未提交”说明；确认只认core清盘成功后的ready。
- cgyy_order_presentation.dart：依据已有CgyyModels.swift:131–195映射审批结果，未知审批明确待确认；不能由订单存在推断成功。
- GinkgoRoot为正常入口建立NativeMirrorService(expectedAccount: session.account)；每次经path_provider取得本机Application Support，JSON携storage_root及expected_account。后者仅前置比较，真正账号仍由Rust会话取；await后旧回调不能进入新账号。未绑定的standalone native写直接拒绝，演示／loader不提供学校写入口。

### 应用层跨重启标记

core application/cgyy.rs 与 cgyy_pending_store.rs：

- 标记文件 cgyy-pending-<SHA1(account)>.json，唯一内容 {"version":1,"pending":true}；文件名摘要不是加密。没有账号明文、手机号、主题、参与人、学校token或验证码。
- prepare/cancel派发前create_new、write、flush、sync（Unix目录sync），Unix权限0600。不可写则不调用upstream；损坏、超大、不可读、目录或符号链接拒绝覆盖／继续写。
- challenge、uncertain、错误和未知结果保留文件；submit允许已有有效标记继续，由Rust一次性内存challenge限制。重启后没有challenge，不能据磁盘标记重放。
- status以磁盘pending优先；同账号重启／重登保留，其他账号独立。查询缓存清理不删除此文件。
- 只有显式accepted/rejected/notSubmitted（含旧本机拼写）终态可清。ack须upstream有效review凭据返回reviewed，再删除文件成功后才归一ready；删失败不报告解锁。
- 原String FFI不变；受保护命令无绝对storage_root拒绝。options/review可兼容低级无root调用。expected_account若提供必须与当前Rust账号一致，先比较再做任何文件／port动作；不接受调用方account作为身份。

此机制依赖现有FFI SESSION_ACCESS.write对整个命令／认证操作串行化。create_new防第二个初始writer，但不宣称多进程submit／ack／清理全流程原子协议。卸载／系统清除应用数据会删除本机标记，重新安装前后仍应自行核对学校订单。

### 上游与身份

- 所有mutation POST不重试。预约草稿／最终提交／取消派发前设pending并失效CGYY快照；未知清缓存并保锁。
- HTTP 200 body code=500、陌生业务码、HTTP 5xx、认证、格式漂移、transport错误均不能证明没落单。为兼容共享读契约，read envelope仍可返回BusinessRejected，但mutation booking_failure不据其清锁。
- 内存pending按账号独立于Identity保存，显式／静默重认证／注销不抹除。身份代次覆盖challenge、CGYY登录token发布、回查及取消前置，旧await结果不得进入新身份。
- review强读而非cache fallback；成功返回最近20条Order与随机一次性id，绑定账号／身份代次、严格小于120秒；新review尝试先撤旧凭据，失败仍不清pending。
- 原Order status保留；live补order_status、check_status和can_cancel，未知资格false（审批码仅已知0–6可进入取消资格判断，99等不发POST）；不回传审批个人文本、表单或token。共享解析v1明确保留原五字段，历史fixture断言不放宽。

## 实际回归证据

最终统一门禁 `bash scripts/check-mirror.sh` 已完整执行，exit 0（架构、Rust fmt/clippy/最小core/上游/workspace、Flutter analyze及全量test）；日志 `/tmp/ginkgo-cgyy-final-gate.log`。正常入口 `flutter build apk --debug --target-platform android-arm64 -t lib/main.dart` exit 0，产物 `flutter/build/app/outputs/flutter-apk/app-debug.apk`，是开发Debug而非Release；日志 `/tmp/ginkgo-cgyy-normal-debug.log`。构建未提高版本、不代表公开包或真账号验收。

### Rust（均不访问学校）

- cargo +stable fmt --all --check，通过。
- cargo +stable clippy --workspace --all-targets --all-features --locked -- -D warnings，通过。
- cargo +stable test --workspace --locked，通过：core lib22、core集成7＋3、domain6、bridge3、upstream lib222及共享fixture1；另doc test1。合计264项非doc测试、1项doc测试，无失败。
- cargo +stable test -p ginkgo_core --no-default-features --locked，通过（core最小依赖门禁另计）。
- 定向CGYY36项、session20项均通过；core新增20项最小标记测试包含真实临时文件、重建、权限／损坏／重复字段／超大／符号链接、账号及root隔离、expected_account错绑所有动作零调用、8线程create仅一winner、ack清理失败。
- HTTP合成覆盖7类unknown×草稿／提交／取消，缓存失效及单次POST；captcha明确失败、token／identity晚回包、同账号重认证／退出重登、A→B→A、Review过期／错id／旧凭据／失败／新尝试撤旧、drop时pending保留、提交回查不匹配／解析失败／HTTP失败。
- 初次全workspace失败发现code500读分类和Order新增字段改变共享v1精确契约；已保留只读分类与显式v1五字段投影，不改fixture／Swift、不丢live新信息，重跑通过。写入unknown矩阵仍保留，未降级写保护。

### Flutter

- 最终 flutter analyze --no-pub 无问题；连同 flutter test --no-pub test 命令链 exit 0。
- 全量flutter test --no-pub test已通过271项（原244＋新增表单安全20＋管理7）。表单专属27含原7；管理与呈现合跑9。
- 关键合成：PNG人工拖动、坏图／无位移禁提交、两次确认取消零submit、双回调、延迟prepare／submit系统返回、dirty退出、12段上限、notSubmitted兼容、unknown／throw保锁、强读失败不解锁／空记录警示／审批状态／一次cancel、320dp2x深浅布局。
- 新device场景 integration_test/cgyy_write_flow_test.dart使用纯内存gateway与合成PNG，从场馆入口填表→摘要→人工拖动→一次submit unknown→订单→强读展示→确认解锁→取消摘要并选择保留预约；不初始化native账号或发送学校请求。ARM64 Android 17/API 37（1080×2400）模拟器已实际运行通过，命令 exit 0、场景1项＋tearDownAll；prepare/submit各1次、选择保留预约时cancel为0。四张截图见 flutter/build/visual/cgyy-write-summary.png、cgyy-manual-captcha.png、cgyy-fresh-review.png、cgyy-cancel-summary.png，已人工目视检查；绿色PNG是合成图，不是学校验证码。初次device脚本误写最终按钮名，已按实际“提交一次”修正并完整重跑通过。
- 架构边界检查与5项脚本回归、git diff --check通过。

## 人工真实写入验收规程（尚未执行）

1. 用户登录，确认本轮包入口、账号及学校环境可用；自选可真实使用、人数／用途符合规则的一个空间和时段，不为测试虚占资源。
2. 对照学校页面确认当前无重复预约，填写本人真实资料并人工解拼图；核对两次摘要后由本人提交一次。
3. 记录结果类别与时间（脱敏，不入日志／仓库），强读订单核对id、地点、时段及审批，受理不等于通过。
4. 如结果不明，停止写，先只读核对，包含应用重启／重新登录后保护仍在；目标不在最近20条时到学校查完整历史，不能用空列表证明未提交。
5. 用户自愿且订单明确允许取消时，核对4小时时间门禁，确认取消一次并强读学校取消状态；不可取消时不强试。
6. 真机补TalkBack、系统大字、预测返回、前后台中断、网络断开；代理不自动执行这些真实写操作，不自动选时间或重复尝试。

## 限制与后续记录位置

- 最近20条，不是订单全历史；本轮未加订单分页、门锁码、自动预约、自动验证或批量操作。
- 真机／真实账号预约取消与审批、Windows实际打包、发布签名与覆盖升级未验收。
- 未发布、未提交、未提高minBuild。已有上一轮主题/首页改动保留；pre-existing scripts/__pycache__/未删除。
- 未完成项统一保留MIRROR-TODO.md，不在本记录新增另一套执行清单。
