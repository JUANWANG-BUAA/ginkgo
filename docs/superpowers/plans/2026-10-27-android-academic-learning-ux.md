# Android Academic and Learning UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让手机课表更直观、研究生教务不再重复、SPOC 课程详情更易浏览且按页加载。

**Architecture:** 只调整 Flutter 呈现与页面状态，复用现有 gateway、Rust 学校协议和缓存。研究生学分地图抽成共享 sliver 内容，旧导航 ID 保留为兼容别名；SPOC 各分区继续使用独立 `RefreshSection`。

**Tech Stack:** Flutter/Dart、现有 widget tests 与 Android integration tests。

---

### Task 1: 手机课表默认当日清单

**Files:**
- Modify: `flutter/lib/features/schedule/schedule_page.dart`
- Modify: `flutter/lib/features/schedule/schedule_views.dart`
- Create: `flutter/lib/features/schedule/schedule_day_strip.dart`
- Test: `flutter/test/schedule_page_test.dart`

- [ ] **Step 1: 写失败测试**

窄屏打开课表时断言默认是每日清单而非周网格；显示星期条，选择星期二后只显示星期二课程；搜索时仍返回全周匹配。宽屏保持周网格默认。

- [ ] **Step 2: 运行并确认失败**

Run: `cd flutter && flutter test test/schedule_page_test.dart`  
Expected: 当前默认 `weekGrid`，没有逐日选择与默认日逻辑。

- [ ] **Step 3: 最小实现**

`SchedulePage` 增加 `selectedDay` 和按宽度决定的初始视图；成功响应后优先选今天，其次首个有课日。`ScheduleDayStrip` 只负责七天的日期/选中/今天显示。`ScheduleCourseBrowser` 在清单模式只显示选中日，搜索时显示全周匹配。保留现有周次、课程详情、大字号和宽屏网格。

- [ ] **Step 4: 验证专项**

Run: `cd flutter && flutter test test/schedule_page_test.dart test/schedule_week_position_test.dart`  
Expected: 全部通过，既有周次定位和旋转行为不回退。

### Task 2: 研究生教务去重

**Files:**
- Modify: `flutter/lib/features/graduate/graduate_page.dart`
- Modify: `flutter/lib/features/graduate/graduate_credit_map_page.dart`
- Modify: `flutter/lib/workspace/workspace_catalog.dart`
- Modify: `flutter/lib/workspace/service_directory.dart`
- Test: `flutter/test/graduate_page_test.dart`
- Test: `flutter/test/workspace_catalog_test.dart`

- [ ] **Step 1: 写失败测试**

断言研究生教务的 credits 视图包含严格学分地图；目录和侧栏不再出现第二个“研究生学分图”；旧 `graduate-credit-map` ID 仍打开研究生教务 credits 视图。

- [ ] **Step 2: 运行并确认失败**

Run: `cd flutter && flutter test test/graduate_page_test.dart test/workspace_catalog_test.dart`  
Expected: 两个独立入口仍存在，主教务页使用旧概览。

- [ ] **Step 3: 最小实现**

把 `GraduateCreditMapPage` 的内容抽为共享 sliver 列表，独立页与 `GraduatePage` 复用。`GraduatePage` 接收可选 `initialView`，在 credits 视图展示严格地图；旧 ID 设为 `sidebar:false` 并作为 credits 别名，移动目录移除重复项。保留独立加载、错误、旧数据和账号代次。

- [ ] **Step 4: 验证专项**

Run: `cd flutter && flutter test test/graduate_page_test.dart test/workspace_catalog_test.dart test/graduate_credit_map_page_test.dart`  
Expected: 全部通过，既有严格学分语义不变。

### Task 3: SPOC 课程详情分页与课程列表清理

**Files:**
- Modify: `flutter/lib/features/learning/learning_page.dart`
- Modify: `flutter/lib/features/learning/learning_course_page.dart`
- Test: `flutter/test/learning_page_test.dart`
- Test: `flutter/test/learning_course_page_test.dart`

- [ ] **Step 1: 写失败测试**

课程列表只有一个刷新入口，无课程时不显示搜索框。课程详情默认只显示资料；公告/测验在首次选择对应分页时才读取，来回切换保留旧内容且不集中发起三类请求。

- [ ] **Step 2: 运行并确认失败**

Run: `cd flutter && flutter test test/learning_page_test.dart test/learning_course_page_test.dart`  
Expected: 当前存在重复刷新，课程详情启动即加载所有分区并长页堆叠。

- [ ] **Step 3: 最小实现**

课程列表移除分区刷新按钮，搜索仅在有课程时出现，错误仍用 `SectionFeedback`。课程详情增加 `LearningCourseTab`，默认 resources；首次选择公告/测验才调用对应读取，栏目发现不隐式拉取全部内容。分页 UI 使用分段控件，状态对象和目录路径保持不变。

- [ ] **Step 4: 验证专项**

Run: `cd flutter && flutter test test/learning_page_test.dart test/learning_course_page_test.dart test/learning_files_test.dart`  
Expected: 全部通过，下载、附件和目录行为不回退。

### Task 4: 文档与最终验收

**Files:**
- Modify: `docs/FEATURES-AND-PROTOCOLS.md`
- Modify: `docs/MIRROR-IMPLEMENTATION.md`
- Modify: `docs/MIRROR-TODO.md`

- [ ] **Step 1: 更新现状**

只记录工作树实现和实际验证，不把本科培养方案、真实账号或物理设备标为完成。

- [ ] **Step 2: 全量门禁与正常包**

Run: `bash scripts/check-mirror.sh && git diff --check`  
Run: `cd flutter && flutter build apk --debug --target-platform android-arm64 --target lib/main.dart`  
Expected: 全部通过；FRB 无手写改动。

- [ ] **Step 3: Android 合成验收**

在 ARM64 模拟器检查手机默认课表、星期切换、研究生单入口学分地图和 SPOC 三个分页；补 320dp 大字号与深浅色。集成测试后重新构建正常 main 包，真实账号验收仍单列。
