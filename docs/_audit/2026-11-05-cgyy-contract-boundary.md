# 研讨室契约与展示边界（2026-11-05）

## 问题与改动

application/mirror_service.dart 的研讨室网关，以及 infrastructure 中 native_mirror_service、demo_mirror_service、cgyy_decode 原先都引用 features/cgyy/cgyy_models.dart，导致应用契约和数据适配依赖页面目录。

共享值类型迁入 application/cgyy_models.dart。构造参数、可空字段、写入状态分类与未知状态保护保持原样；订单状态文案、摘要和门锁地点拼接留在 feature 的两个展示扩展中。feature 文件转出应用契约，现有页面与演示测试无需维护第二套类型。三个适配器和应用网关直接依赖 application，不通过页面转出获取契约。

架构门禁禁止 application/infrastructure 依赖 features/widgets/workspace/app，兼容 package、相对路径及包含 .. 的路径解析。自测同时覆盖 import/export，允许依赖 application。本轮不改变 Rust、FRB API、学校协议、CGYY 确认/提交/回查或网络冻结清单。

## 验证

- 完整 `bash scripts/check-mirror.sh` 返回 0：Rust fmt/Clippy、分层及 workspace 测试、错误变体回归、Flutter 分析、857 项测试与 FRB 零漂移通过；上一轮依赖下载阻塞已恢复。
- 研讨室管理、写入安全、详情隔离、门锁及 DTO 映射五个测试文件共 52 项通过。
- 正常 lib/main.dart、--pub、Android ARM64 Debug APK 构建通过。
- 新增门禁在完整脚本启动后写入，另行执行架构检查及 26 项自测通过；取 HEAD 旧门禁验证同一反向导入不会被拒绝，确认新增回归能识别旧缺口。
- 生成索引脚本修正“Dart 无方向门禁”的旧表述，两项生成器自测通过；接口索引、文档/契约、网络冻结与差异检查通过。
- 日志归档 artifacts/local/cgyy-contract-boundary-2026-11-05/。未执行真实学校预约、实体设备或 Windows 主机构建，本轮未发布。

生成依赖图中的 application → features/cgyy 边已移除；原五组强连通分量缩小为 application/shared 两组，剩余循环并未宣称消除。
