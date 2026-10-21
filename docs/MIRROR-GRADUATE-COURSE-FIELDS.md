# 研究生课程字段对照（2026-10-21）

本切片基于 `2692add`，在独立工作树开发；尚未并入 Android 发布包，不覆盖正在进行的设备验收。

## 源码证据与行为

`BUAA-Assistant/Features/Graduate/GraduateAcademicClient.swift:252–265` 将执行报告中的 `kcdm/cjxsz/kclbmc/kksx` 分别解析为课程代码、成绩、类别和课程属性；`:131–143` 将课程池中的 `KCDM/KCLBLXMC/KCLBDM_DISPLAY/KKSX_DISPLAY/SFBX_DISPLAY` 解析为代码、类别、考核方式和必修标记。镜像现在沿用这些字段，白名单投影为可选 `courseInfo`，没有新端点或新增请求。

课程详情使用现有 Cupertino 分组和可复制信息行分别展示学校字段，保留原摘要。课程代码纳入搜索；打开详情与返回使用已有快照，保留搜索。学校未返回的字段不补造，也不根据成绩、必修标记推断课程完成状态。缺失 `courseInfo` 的旧快照仍能显示。

## 本切片验证

- Rust `cargo test -p ginkgo_core graduate --lib`：18 项通过（其余 144 项未运行），包含字段白名单、未知完成状态及原有缓存回归。
- `cargo test -p ginkgo_core --test contracts`：1 项契约遍历通过；当前切片递归统计 44 类、145 份 JSON，新增一份合成执行报告字段契约。
- workspace Clippy（all targets/features、warnings denied）和 fmt check 通过。
- Flutter 定向 analyze 无问题；新课程字段 widget 与原分区 widget 共 5 项通过，覆盖深色 1.8 倍字号、代码搜索、详情返回、缺值和不增加请求。

以上均为离线验证。模拟器由另一项验收任务独占，本切片未执行设备测试、人工设备读图或真实账号查询，也未发布 APK。实网需要核对学校字段实际返回、缓存/强制刷新及页面更新；人工外观和单项设备 smoke 仍待验收。完整学分地图、其他研究生服务、Windows 验收不属于本次完成项。
