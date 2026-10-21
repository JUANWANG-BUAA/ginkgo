# 博雅学习记录与完成统计验收（2026-10-21）

## 协议依据

`BUAA-Assistant/Features/BYKC/BykcClient.swift` 的 `load`、`chosenCourses`、`statistics` 与 `BykcSemesterPolicy.swift`，以及 API.md §7.3 / EDUCATION-DATA-MAP §2.3。沿用已有加密信封，已选查询使用当前北京时间学期的 startDate/endDate；累计统计独立查询。不新增接口假设。

## 完成范围

Rust 领域、HTTP、application、FRB 和 Cupertino 分段页面贯通。三个分段分别缓存、首次访问才读，刷新合并同页重复请求，失败保留该分段旧结果；离开分段后返回保留搜索及加载结果。已选详情来自已取快照，打开不再联网。500 门目录懒构建可见行；缺字段保留未知，缺学期范围不当作零条。统计保留超额计数，进度条最多填满，0/0 显示暂无要求。学校时间按北京时区显示，成绩/考勤使用文字与语义色同时表达。

## 缓存排队修复

独立检查发现三个读取在等待 BYKC 认证锁后未重新检查缓存，因此并发相同读取可能重复完整网络链。新增确定性测试先排队三类读取，再模拟先前请求填入快照；原代码失败，增加锁后身份与缓存复核后通过，HTTP 增量为0。强制刷新仍走网络，已有新鲜快照仍可绕过锁返回。

## 验证

隔离工作树 `/tmp/ginkgo-bykc-verified`：BYKC 4 项 Rust 定向测试、142份 fixture 的契约遍历、Clippy workspace/all-targets/all-features、fmt check、Flutter 产品目录 analyze、12 项 widget（学习记录/详情/时间）通过。未重跑 mirror_test.dart。Android 单项 `bykc_test.dart` 46秒通过：真实 FFI 解析合成 fixture，覆盖目录搜索、已选详情、累计统计。Android Gradle 同时交叉编译 aarch64 bridge 成功。本文件不据合成数据认定真实账号、Windows 或写入验收。

## 真实验收计划

正常登录页由用户本人建立会话后，读目录、当前学期已选和累计统计，分别记录首次/缓存/强制刷新耗时、状态及条数；再观察分段返回、失败旧结果和刷新后无须切页即可更新。不得保存真实页面截图、响应正文或凭据。选退课与博雅签到仍未接入，不在本切片中宣称完成。
