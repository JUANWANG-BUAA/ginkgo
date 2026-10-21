# 研究生培养方案与原文（2026-10-21）

本切片在 `feat/mirror-graduate-plan` 独立分支开发，依赖课程字段提交 `6673cb7`。尚未并入发布包，也未占用真实账号验收使用的模拟器。

## 源码与协议

依据 `GraduateAcademicClient.swift:87–154` 和 `EDUCATION-DATA-MAP.md` §4.2，按需激活 `wdpyfaappbuaa`，查询账号对应 `FADM`，读取 `facx.do?DM=…&EN=zh`、`gjfadmhqdydpyfanr.do?DM=…`，再以 `setting=[{"name":"FADM","value":…}]` 读取课程池。表单和查询参数均编码，GET 带应用 Referer；全部请求沿用 Session 路线/重定向和一次认证恢复。

头部仅导出名称、学院、专业、最低总/学位课学分、校企课程要求和审核状态。章节以 `MC` 为标题，正文 `MRZ` 优先、缺失/null 时取 `SM`，空内容保留“未返回正文”。HTML 只转纯文本，不执行；类型漂移拒绝。课程池沿用课程字段白名单，不推算已完成状态，不将池内学分当作毕业要求。

## 数据与页面

新增 `GraduatePart::Plan`，使用既有 graduate 快照容器中的独立 `plan` 键、五分钟 TTL、共享 GSMIS 认证锁、失败旧快照以及清缓存/退出路径。既有学籍/报告首次加载不请求方案。FRB 新增正常/演示只读入口，由 2.12.0 代码生成，library stem 仍为 `ginkgo_flutter_bridge`。

“学分地图”内提供“培养方案与原文”入口，打开独立 Cupertino 导航页才请求。章节默认折叠、正文可复制，课程池按需展开；外层列表懒构建，计数在数据变化时计算。刷新合并重复调用，失败保留原文与展开状态。大字号头部改为左对齐纵向字段，浅/深色采用既有分组和语义色。

## 离线验证与待验收

- 19 项研究生相关 Rust lib 测试通过，其余 144 项未重跑；新增应用回归覆盖按需请求、参数/Referer、白名单、独立缓存、失败保留与清缓存。
- 契约遍历 1 项通过；新增 normal/empty/drift/rejected 四份合成 `graduate.plan`，本分支递归实数 45 类/149 份 JSON。
- workspace Clippy（all targets/features，warnings denied）、fmt check、Android aarch64 bridge 交叉检查通过。
- 定向 Flutter analyze 无问题，研究生 7 项 widget 通过，含按需导航、深色 1.8 倍字号、合并刷新及失败保留。
- 使用产品字体生成并亲自读图：390×844 浅色/深色/深色1.8字号；修正读图发现的大字号字段居中。图片仅 `/tmp/ginkgo-plan-{light,dark,large}.png`，全部合成，不入库。此为 widget 渲染读图，不是 Android 设备验收。

模拟器由另一项任务独占，本切片未跑设备 smoke、未真实查询方案，也未发布 APK。下一步在正常账号会话中核对章节、课程池、首次耗时/缓存命中/强制刷新以及返回状态；结束后退出并检查保险库为空。已准备 `flutter/integration_test/graduate_plan_test.dart`（analyze 通过，尚未执行），用于单项合成 FFI smoke；新页面仍待该项设备验收，完整学分地图和其他研究生服务不据此宣布对齐。
