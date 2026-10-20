# Shared contracts

每份 JSON 使用 `contract`、整数 `version`、`source`、`input`、`expected`。`source` 只能是 `synthetic` 或 `redacted-upstream`，不存真实个人数据。

当前三十六类 v1 契约共有 114 份合成样例：教室筛选与上游解析、博雅筛选、北京时间、课表已知周次保留、CAS 登录页解析、UC 会话状态、本科课表学期/教学周/周课表/考试、今天课程、成绩响应与学期码、SPOC 作业页/详情与分页加密、BYKC加密信封/目录、研究生执行报告、本地待办文档、通知HTML、CGYY公开场馆/时段/订单、iclass app 登录与当天课程、booking.lib 登录交换/场馆/区域/时段/座位/当前预约。覆盖成功、空结果、缺字段、类型漂移、重复记录冲突和无效输入。应用边界拒绝无效输入时，`expected` 使用 `{"error":"invalid_request"}`；结构无法识别使用 `changed_response`，不把它转换为成功的空列表；上游明确拒绝使用 `business_rejected`，不当作空结果。

签到样例覆盖 STATUS="0" 正常课程、STATUS=2 无课、缺字段、业务拒绝和同课程状态冲突；图书馆样例覆盖正常、空列表、数量矛盾（结构漂移）和当前预约的空/非空。所有样例均为合成或脱敏数据，不含真实学号、姓名、Cookie、票据、座位号或课程数据。

Rust runner 位于 `rust/crates/ginkgo_core/tests/contracts.rs`，递归读取本目录全部 JSON。Swift 现有测试读取四份起始黄金样例；新增的错误码与认证样例目前由 Rust 应用边界验收，不能据此声称 Swift 也已验证这些错误契约。

`school_time.beijing_day` 的空输入不是成功空日期，而是 `invalid_request`。课表空课程是已知周次的空结果，不是缺失周次。未标为空闲的教室节次不表示已确认占用。

SPOC 详情新增四份合成契约（正常/空/结构漂移/业务拒绝），不含真实作业内容。

新增模块均在application/contracts.rs登记；通知空HTML因没有可确认的上游空标记而为changed_response；本地待办的无效文档为changed_response，不覆盖文件。CGYY样例中的synthetic-must-not-cross-bridge是投影隐私断言哨兵，无真实票据或个人信息。

`library.history` 新增六份合成契约：正常分页、确认空、页码漂移、缺分页依据、下一页矛盾、业务拒绝；在application/contracts.rs登记，使用真实只读adapter信封分类，不含真实记录。签到历史复用原课程日期响应四类契约，不新增虚构响应结构。
