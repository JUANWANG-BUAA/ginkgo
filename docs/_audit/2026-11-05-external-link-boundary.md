# 官网外链职责拆分（2026-11-05）

## 范围

移除 shared/school_links.dart 对 url_launcher 和 Flutter 弹窗的直接依赖。application 定义 ExternalLinkLauncher，platform 实现 externalApplication 打开，ginkgoApp 统一注入 ExternalLinkScope；shared 保留 HTTPS、非空主机、拒绝嵌入凭据及异常转失败规则；widgets 承担上下文解析与原失败弹窗。

全部既有调用点迁移：就业、学术文化、作业详情、学习课程、本人借阅、通知、校车、服务目录和发布说明。导航器上方注入使后续推入的详情路由继承同一能力。无作用域时返回 false，不隐式启动系统插件。既有页面继续处理自身异步生命周期和失败提示。

不改学校协议、认证、HTTP、Cookie、WebVPN 或恢复行为，也不为本人借阅失败添加重登或猜测性修复。Rust 与生成桥接 API 不变。普通 Android 和 Windows 使用同一个既有 url_launcher 平台实现。

## 验证

- 完整镜像脚本已实际执行：架构/文档/契约、Rust fmt/Clippy、core/upstream/workspace 与 22 项错误变体回归通过；随后主包 pub get 在下载阶段约五分钟无进展，人工终止，脚本退出 241。因此本轮完整门禁未通过，不能以分项结果代替。
- 单独 flutter analyze --no-pub 通过；全量 Flutter 测试显式指定本次构建的宿主 bridge，857 项通过。首轮有四项校车测试宿主未注入能力而失败，补齐作用域后保留原 URL/平台调用断言，全量复跑通过。
- 外链六项定向测试通过，架构门禁自测证明把 url_launcher 重新放回 shared/school_links.dart 会失败。
- 正常 lib/main.dart、--pub、Android ARM64 Debug APK 构建通过；仅证明构建，不代表设备浏览器验收。
- 单独 FRB 重新生成完成，绑定与 HEAD 零差异；生成接口索引检查、协议摘要检查、网络冻结及 git diff --check 通过。
- 原始日志保留在 artifacts/local/external-link-boundary-2026-11-05/（忽略目录）。真实学校请求、物理设备及 Windows 主机构建未执行。本轮未发布。

客户端契约锁仅刷新本轮 Dart 接线和对应文档摘要，学校协议和网络冻结清单未改变。完整门禁复跑缺口保留在唯一 TODO。

## 后续完整门禁复跑

2026-11-05 研讨室契约拆分批次中依赖解析恢复，完整 scripts/check-mirror.sh 返回 0，857 项 Flutter 测试和 FRB 零漂移通过。此前下载阻塞的复跑项已从唯一 TODO 移除，原失败过程保留。记录见 [研讨室边界审计](2026-11-05-cgyy-contract-boundary.md)。
