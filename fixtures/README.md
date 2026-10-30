# Shared contracts

每份 JSON 使用 `contract`、整数 `version`、`source`、`input`、`expected` 信封。`source` 只允许 `synthetic` 或 `redacted-upstream`；不保存真实身份、凭据、票据或校园个人内容。本文不维护随提交变化的数量，范围以 runner 和目录为准。

## 两端如何使用

| 消费端 | 入口 | 实际覆盖 |
| --- | --- | --- |
| Rust | [tests/contracts.rs](../rust/crates/ginkgo_upstream/tests/contracts.rs)、[execute_contract](../rust/crates/ginkgo_upstream/src/services/contracts.rs) | 递归执行本目录全部 JSON，对未知契约失败 |
| Dart 规则 | [rules_parity_test.dart](../flutter/test/rules_parity_test.dart) | `rules/` 下的规则表：作业截止分类与签到窗口，与 Rust 领域规则共用同一份 `expected` |
| Swift 规则 | ClassroomViewModelTests、BykcCourseCatalogTests、SharedHelpersTests、WorkspaceIntegrationTests | 教室筛选、博雅过滤、北京时间、课表已知周次保留的共享黄金样例 |
| Swift 解析 | [SharedParserContractTests](../BUAA-AssistantTests/SharedParserContractTests.swift) | 递归读取同目录；CAS 登录页、教务学期 / 周次 / 本科课程 / 考试、成绩与学期码、SPOC 分页加密 |

Swift 解析 runner 支持 `auth.cas_login_page`、`schedule.terms`、`schedule.graduate_terms`、`schedule.weeks`、`schedule.undergraduate_courses`、`schedule.exams`、`grades.buaa_score`、`grades.term_parts`、`homework.spoc_encrypt`。两端调用各自生产解析器，对同一 `expected` 投影断言；Swift 仅归一化属性命名、可选 null 和错误码，不复制 Rust 算法或生成另一份 JSON。

此覆盖不是“全部契约两端一致”：签到、图书馆、博雅上游解析、研究生、SPOC 列表 / 详情及部分认证错误目前仍主要由 Rust runner 检查。后续共享测试应扩展现有 runner；新增支持的契约必须有样例，已有样例不能被静默跳过。

`rules/` 是规则表而非协议响应：一次给出多组输入，`expected.results` 逐条对应。Rust 的领域规则是权威（`homework::classify_deadline`、`checkin::sign_in_window`、`reminders::plan_checkin_homework_reminders`、`library_mutation::parse_result`），Dart 侧用同一份表断言自己的实现或替身，两边任何一边改出差异都会红。表覆盖跨零点、日期型与精确时刻型截止、无法解析的输入，以及签到窗口的开放前一刻、开放瞬间、关闭瞬间、跨日与畸形时间，以及图书馆写结果的受理/拒绝/待确认。Swift runner 按既有约定跳过未登记的契约，因此这些规则目前是 Rust↔Dart 共享。

## 语义约束

- 无效输入用 `{"error":"invalid_request"}`；无法识别的响应用 `changed_response`；明确业务拒绝用 `business_rejected`。不将后两者变成成功空列表，不将业务拒绝当作登出。
- 空课程保留已知周次；空学校日期是无效输入。未标为空闲的教室节次不表示已确认占用。
- 课程签到覆盖正常、无课、漂移、拒绝与同课程状态冲突；历史复用同一按日协议，不虚构第二种响应。
- 图书馆覆盖登录交换、场馆 / 区域 / 时段 / 座位 / 当前预约和历史分页；数量矛盾、页码漂移、缺分页依据与业务拒绝各自有预期。公共人数中缺指标保留 null，确认零值保留 0。
- SPOC 的教师通过课程 ID 关联，不从标题猜；缺教师不伪造，重复 ID 和类型漂移拒绝。详情区分合法缺正文与对象 / 数组类型漂移。
- 博雅详情只投影“签到配置存在”，不输出配置正文；研究生待考核学分不计入已获。
- 签到 / 图书馆写结果区分受理、拒绝、未提交与不明确，样例均为合成。测试通过不代表真实写操作验收。
- Android 更新只接受独立 Android tag 与可信资产；不把 macOS 发布、草稿或不可信 URL 当作可安装更新。
- 校园卡余额覆盖正常金额、合法零余额、未登录与畸形金额；标识和金额均为合成值，业务 `type=401` 映射会话失效，未知余额不伪造为 0。
- `synthetic-must-not-cross-bridge` 是投影隐私哨兵，不是真实票据。待办无效文档不能覆盖已有文件；通知没有确认空标记的空 HTML 属于结构变化。
- 待办文档支持旧 v1 与新 v2：v2 可含作业来源、未设截止（空字符串）及带偏移的精确截止；日期保持学校全天语义并按当日日末排序。本地完成与学校提交独立，关联按账号/稳定来源 ID 事务防重且不覆盖用户编辑。fixture 外层契约信封仍为 version=1，与 input 文档版本分别校验；未知文档版本使用 99，不再把已支持的 v2 当漂移。

协议修正先记录 [API](../docs/API.md) 证据；领域语义变化必须明确升级版本并同步消费者，不以改 `expected` 掩盖差异。验证命令与本次覆盖结果见 [TESTING](../docs/TESTING.md)。
