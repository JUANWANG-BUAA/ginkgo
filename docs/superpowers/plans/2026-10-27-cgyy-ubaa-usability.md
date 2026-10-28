# CGYY UBAA Usability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 让 CGYY 预约用途可降级、订单可查看详情、门锁码可查询，并提供三个清晰入口，同时保持单次写入和隐私边界。

**Architecture:** 复用 `CgyySource::load_cgyy` 与现有 `kind` bridge，不增加 FRB 函数签名。`Order` / `LockCode` 走独立、无快照的只读路径；现有场馆、日期和订单列表继续走原快照。Flutter 只消费净化后的领域 JSON。

**Tech Stack:** Rust、Flutter/Dart、现有 CGYY fixture、Flutter widget/integration tests。

---

### Task 1: 用途读取失败的内置降级

**Files:**
- Modify: `rust/crates/ginkgo_domain/src/features/cgyy_booking.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs`
- Test: `rust/crates/ginkgo_upstream/src/services/tests/cgyy_booking.rs`
- Modify: `flutter/lib/features/cgyy/cgyy_models.dart`
- Test: `flutter/test/cgyy_booking_widget_test.dart`

- [x] **Step 1: 写失败测试**

在 CGYY 上游测试增加两种 options 响应序列：day 成功 + codes 空列表、day 成功 + codes 业务拒绝。断言均返回 10 项内置用途、可选时段仍存在且 `uses_fallback_purposes == true`；另加 codes 401，断言 `SessionExpired` 且不返回 fallback。Dart 模型测试断言缺省字段为 false、显式字段为 true。

- [x] **Step 2: 运行并确认失败**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream cgyy_booking --locked`  
Expected: 新用例失败，当前没有 fallback 标记且空用途返回 `ChangedResponse`。

- [x] **Step 3: 最小实现**

在 domain `BookingOptions` 增加 `pub uses_fallback_purposes: bool`。在 protocol 增加固定 UBAA 十项 `Purpose` 列表；`booking_options` 先读 day，再读取 codes，空列表或允许降级错误时使用内置列表。`SessionExpired` / `CaptchaRequired` / `InvalidCredentials` 直接返回，不降级。`BookingOptions` 根据实际来源写标记，Dart `CgyyBookingOptions` 用 `json['uses_fallback_purposes'] == true` 解码。

- [x] **Step 4: 验证专项**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream cgyy_booking --locked`  
Run: `cd flutter && flutter test test/cgyy_booking_widget_test.dart`  
Expected: 全部通过，既有 prepare/submit 请求次数不变。

### Task 2: 订单详情与门锁码领域链路

**Files:**
- Modify: `rust/crates/ginkgo_domain/src/features/cgyy.rs`
- Modify: `rust/crates/ginkgo_domain/src/ports/cgyy.rs`
- Modify: `rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs`
- Modify: `rust/crates/ginkgo_upstream/src/codecs/cgyy.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/cgyy_service.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/contracts.rs`
- Test: `rust/crates/ginkgo_upstream/src/services/tests/campus.rs`
- Create: `fixtures/cgyy/order-detail-normal-v1.json`
- Create: `fixtures/cgyy/lock-code-normal-v1.json`
- Create: `fixtures/cgyy/lock-code-upcoming-v1.json`
- Create: `fixtures/cgyy/lock-code-empty-v1.json`

- [x] **Step 1: 写失败测试**

增加 `CgyyQuery::Order { order_id: 42 }` 与 `CgyyQuery::LockCode` 用例。订单详情断言 ID、地点、日期和审批字段；门锁码分别断言 `qrCode`、有效期与 `orderView`。检查 transport URL 精确为 `/api/orders/42`、`/api/orders/lock/code`，签名字段存在；锁码连续读取两次必须发两次请求，证明未进入快照。401 用例只允许一次 token 恢复。

- [x] **Step 2: 运行并确认失败**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream cgyy --locked`  
Expected: 编译失败或查询返回 `InvalidRequest`，因为新 query/codec 尚不存在。

- [x] **Step 3: 实现 domain 与 codec**

`CgyyQuery` 增加 `Order { order_id: i64 }` / `LockCode`；`CgyyData` 增加 `Order(Order)` / `LockCode(CgyyLockCode)`。`CgyyLockCode` 使用 `Serialize + Clone + Debug`，字段包括可空 `qr_code`、`due_date`、`trade_no`、`venue_name`、`site_name`、`space_name`、`order_name`、日期与时间，serde 使用 camelCase。

codec 抽取现有单订单投影供列表和详情复用；新增 `order(value)` 与 `lock_code(value)`。锁码只取 `data.qrCode/dueDate` 和 `data.orderView` 白名单字段，空串和 `"null"` 归一为 `None`。`services/contracts.rs` 注册 `cgyy.order` 与 `cgyy.lockCode`，保证递归 fixture runner 不因未知契约失败。

- [x] **Step 4: 实现 HTTP 与无快照 service**

`cgyy_http::load` 支持 `order`（site 参数作为正数 order ID）和 `lockCode`。`load_booking_read` 扩为 `pub(super)` 并允许这两种 GET。`cgyy_service` 对这两种 query 在快照逻辑之前分流：获取 booking owner，调用 `load_booking_read`，await 后 `check_booking_owner`，再返回新 `CgyyData`。这两种读取不写 `snapshots.cgyy`。

- [x] **Step 5: 验证专项**

Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream cgyy --locked`  
Run: `cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --test contracts --locked`  
Expected: 全部通过，fixture 不含真实个人数据。

### Task 3: bridge、demo 与 Dart 投影

**Files:**
- Modify: `rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs`
- Modify: `rust/crates/ginkgo_upstream/src/services/demo_campus.rs`
- Modify: `flutter/lib/features/cgyy/cgyy_gateway.dart`
- Modify: `flutter/lib/features/cgyy/cgyy_models.dart`
- Test: `flutter/test/cgyy_presentation_test.dart`

- [x] **Step 1: 写失败测试**

Dart 测试解码订单详情与三种门锁码领域 JSON，断言有效密码、未到开门时段、无预约三态和空值处理；辅助函数应产生 `kind=order/siteId=42` 与 `kind=lockCode/siteId=0` 的 loader 调用。

- [x] **Step 2: 运行并确认失败**

Run: `cd flutter && flutter test test/cgyy_presentation_test.dart`  
Expected: 新类型和辅助函数不存在，测试失败。

- [x] **Step 3: 最小实现**

bridge 的 `load_cgyy` 识别 `order` / `lockCode`，函数签名不变。demo 的 `load_demo_cgyy` 返回新 fixture 的 `expected` 投影；`cgyy_gateway.dart` 增加 `cgyyOrderDetail` 与 `cgyyLockCode` 辅助函数；`cgyy_models.dart` 增加 `CgyyLockCode` 和 `cgyyOrder(String)` / `cgyyLockCodeData(String)` 解码。`CgyyLockCode.hasPassword` 仅接受非空且非 `"null"` 的 qrCode，`hasUpcomingReservation` 检查 tradeNo/日期摘要。

- [x] **Step 4: 验证专项**

Run: `cd flutter && flutter test test/cgyy_presentation_test.dart`  
Expected: 通过；未修改 `flutter/lib/src/rust/` 或 `frb_generated.rs`。

### Task 4: 首页、订单详情与门锁页

**Files:**
- Modify: `flutter/lib/features/cgyy/cgyy_page.dart`
- Modify: `flutter/lib/features/cgyy/cgyy_day_page.dart`
- Modify: `flutter/lib/features/cgyy/cgyy_widgets.dart`
- Create: `flutter/lib/features/cgyy/cgyy_order_detail_page.dart`
- Create: `flutter/lib/features/cgyy/cgyy_lock_code_page.dart`
- Test: `flutter/test/cgyy_day_page_test.dart`
- Test: `flutter/test/cgyy_management_test.dart`
- Create: `flutter/test/cgyy_lock_code_page_test.dart`

- [x] **Step 1: 写失败 widget 测试**

覆盖首页三个入口、fallback 提示、订单点击详情、详情失败重试，以及门锁密码可用/未到开门/无预约/读取失败四种页面状态。大字号测试要求密码完整显示且不使用省略号；调用计数证明没有 30 秒轮询。

- [x] **Step 2: 运行并确认失败**

Run: `cd flutter && flutter test test/cgyy_day_page_test.dart test/cgyy_management_test.dart test/cgyy_lock_code_page_test.dart`  
Expected: 新入口和页面不存在，测试失败。

- [x] **Step 3: 实现页面**

首页将“预约研讨室 / 我的预约 / 门锁密码”置于首屏，再显示公开场馆。订单详情页复用 `CgyyOrder.summary` 与状态标签，独立加载并重试。门锁页使用 `CgyyLockCode` 三态，密码大字展示、有效期和预约摘要分区；手动刷新，dispose 后忽略迟到结果。fallback 说明只在 `usesFallbackPurposes` 时显示。

- [x] **Step 4: 验证专项**

Run: `cd flutter && flutter test test/cgyy_day_page_test.dart test/cgyy_management_test.dart test/cgyy_lock_code_page_test.dart test/cgyy_booking_widget_test.dart test/cgyy_booking_safety_test.dart`  
Expected: 全部通过，既有写保护测试不变。

### Task 5: 文档、全量验证与 Android 合成验收

**Files:**
- Modify: `docs/API.md`
- Modify: `docs/FEATURES-AND-PROTOCOLS.md`
- Modify: `docs/INTERFACE-INDEX.md`
- Modify: `docs/MIRROR-IMPLEMENTATION.md`
- Modify: `docs/MIRROR-TODO.md`

- [x] **Step 1: 更新协议与现状**

API §6B 记录订单详情、门锁码、用途 fallback 的来源和“真实只读未验收”；接口索引登记新 query/data 形状；实施现状只写工作树已实现。TODO 只保留真实预约/取消/门锁码验收，不把合成完成勾成真实完成。

- [x] **Step 2: 运行全量门禁**

Run: `bash scripts/check-mirror.sh`  
Expected: 架构、fmt、Clippy、Rust、FRB 漂移、Flutter analyze/test 全部通过；FRB 源码无差异。

- [x] **Step 3: Android 正常入口构建与合成截图**

Run: `cd flutter && flutter build apk --debug --target-platform android-arm64 --target lib/main.dart`  
使用现有 module-visual 流程或等效正常 main 入口，检查首页三个入口、订单详情、有效密码、未到开门、无预约及 320dp 大字号。不得安装 integration_test 包作为最终应用。

- [x] **Step 4: 最终检查**

Run: `git diff --check`  
Run: `git status --short`  
Expected: 无空白错误；只包含本批设计、实现、测试与文档改动。明确记录未执行真实预约、取消和门锁码读取，不宣称真实业务验收。
