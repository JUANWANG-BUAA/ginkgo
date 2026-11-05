# 时间值与展示边界（2026-11-05）

## 范围

application/local_tasks.dart 为校验本机截止时间依赖 shared/school_timestamp.dart，后者同时持有解析和显示文案；shared 中的提醒/外链等又依赖应用契约，形成 application/shared 目录循环。

纯 parseSchoolTimestamp 提取至 application/school_timestamp.dart。shared 保留日期、星期、时段的格式化并转出原函数，既有页面无需改入口；本机待办直接消费应用层函数。函数体与父提交逐字比对一致，无新增解析策略、时区策略、持久化格式或 Rust 业务规则。明确返回值是 UTC 容器表示的北京时间墙钟，不是 UTC 瞬间。

应用层禁止导入 shared 的门禁覆盖 package/相对路径及 export，反例证明旧门禁允许该依赖，新门禁拒绝。生成依赖图中的 application/shared 强连通分量消失；其他 platform/学习/设置循环保留，不宣称全工程无环。

## 验证

- 完整 `bash scripts/check-mirror.sh` 返回 0：架构与文档门禁、Rust fmt/Clippy/分层/workspace 测试、错误变体回归、Flutter 分析、857 项测试及 FRB 零漂移通过。
- 时间与本机待办两个定向测试文件共七项通过，覆盖时区、跨午夜/跨年、无效日期和偏移、原分数秒保留及未知时间。
- 新架构门禁 27 项自测通过；使用父提交门禁验证旧反向依赖未被拒绝，证明新增约束抓住原缺口。
- 正常 lib/main.dart、--pub、Android ARM64 Debug APK 构建通过；无设备运行或 Windows 主机构建结论。
- 网络冻结、接口索引、文档/契约与 git diff --check 通过。原始日志保留于 artifacts/local/time-value-boundary-2026-11-05/。

本轮不涉及网络认证或学校协议，未执行真实账号、学校写入或发布。
