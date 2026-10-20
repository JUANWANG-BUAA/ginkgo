# 镜像视觉审查

> 2026-10-20。目标：颜色、组件、层次、字体、布局、动画和状态与对应 Apple 产品尽量一致。当前先审查空教室切片，不宣布整个镜像或“100% 相似度”通过。

## 参照与方法

Android 直接参照 `BUAA-Assistant-iOS/Sources/Native/IOSClassroomView.swift`；Windows 参照 `BUAA-Assistant/Features/Classroom/ClassroomView.swift` 与 `docs/UI-DESIGN.md`。

2026-10-20 已重新运行 `Ginkgo iPhone 17 Pro / iOS 27.0` 的 `GinkgoSmokeUITests.testAuthenticatedShellIsReachable`：1 项通过，导出 12 张原生页面截图（本机 `artifacts/local/ios-attachments/`），其中 `iOS classroom` 作为本轮初始页参照。使用现有演示环境，没有真实账号验收。

原生截图与 Android Flutter 表面截图的分辨率、系统状态栏和全局导航不同，应按逻辑尺寸和内容区域比对。当前没有定义可证明“接近 100%”的像素分数，不采用不同视口的整图 SSIM 作为通过凭据。

## 官方依据

- [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials)：导航/控件与内容层分开；玻璃效果节制使用。
- [Apple Color](https://developer.apple.com/design/human-interface-guidelines/color)：颜色按语义使用，适配明暗与可读性。
- [Apple Typography](https://developer.apple.com/design/human-interface-guidelines/typography)：层级、可读性、字重与可访问字号；系统字体不嵌入应用分发。
- [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion)：动效服务于状态反馈，支持关闭动态效果。
- [Apple Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、[Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)、[Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/)：按平台组织高频操作与导航。

同时检查本机 Flutter 3.47 的 `cupertino/list_section.dart`：默认 inset group 的采样注释仍指向 iOS 14，因此不把默认 Cupertino 尺寸视为当前 iOS 原生外观的保证。

## 本轮调整

| 维度 | 实现 | 验证与剩余差异 |
| --- | --- | --- |
| 颜色 | 语义背景、label、separator；品牌绿直接对照 Apple 资源 `#189840` / `#47bd6b` | 深色与高对比需分别复核 |
| 分组与层次 | 16pt 页边、26pt 连续圆角、52pt 基础行；查询、筛选、结果、楼栋分组 | 尺寸是项目截图校准值，不是 HIG 通用常量 |
| 控件 | 日期胶囊、着色快捷按钮、浮动选择菜单、圆形刷新、详情节次网格 | SF Symbols 与 Cupertino 图标的字形仍有差异 |
| 字体 | Inter 变量字体 + Noto Sans SC 变量字体，正文 17、主标题 34，区分字重与字距 | 近似 SF / 苹方；不声称字形完全相同 |
| 材质 | 模糊与高光限于导航按钮和临时菜单；内容保持纯净表面 | Flutter 近似实现，不是原生 Liquid Glass 折射 |
| 动画 | 按压 90/260ms，分组 220ms，菜单 180ms，保留 Cupertino 页面过渡 | 时长/曲线是 Ginkgo 调整值；减少动态效果时自定义动画为零 |
| 可读性 | 放大文字、深色、语义标签；14 节状态由 Rust 提供 | 需要进一步 TalkBack 人工复核，widget 测试不等于读屏验收 |
| 导航外壳 | 手机端现有“今天 / 空教室 / 课表 / 成绩”四项 Cupertino Tab；桌面侧栏同步 | iOS 参照为“今天 / 课表 / 作业 / 图书馆 / 更多”，作业与图书馆待接入 |

## 复现截图

```sh
cd flutter
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/mirror_test.dart \
  --dart-define=GINKGO_CAPTURE=true \
  -d emulator-5554
```

PNG 写入 `flutter/build/visual/`；保存初始、结果、详情、零匹配、错误，以及深色放大文字状态。驱动只检查截图文件完整性，视觉一致性另行人工审查。

本机证据可复制到 `artifacts/local/mirror/`，该目录不入库。原生参考 `.xcresult` 与完整日志位于本机临时目录，具体命令与结果以本次执行记录为准。

## 后续审查

1. 当前完整导航外壳、iOS 27 的玻璃细节及 Windows/macOS 布局仍要按模块接入后继续对齐。
2. 相同页面状态、固定视口、固定字号分别采集浅色/深色截图，标注字体、图标和系统表面的不可直接共享之处。
3. 对滚动、选择菜单、详情返回、加载/失败切换做动态检查；静态截图不替代动效验收。

## 已确认差异（初始页）

- 参照页从“更多”推入，因此左上角有返回圆钮；镜像的空教室是根 Tab，暂不显示返回钮。等外壳按 iOS 五 Tab 重排后再补。
- iOS 底部为五项 Tab；镜像当前为四项，覆盖已迁移模块，作业/图书馆随 P3 接入。
- 镜像保留了“离线合成样例 / 查看共享规则示例”演示说明，iOS 演示模式没有这两个页脚；这是有意的可验证性差异，不作为像素一致项。
- 初始页的页边距、卡片圆角、语义色、大标题和空态结构已接近；字体仍为 Inter/Noto Sans SC 近似 SF/苹方。

## 设备证据（2026-10-20）

使用带窗口、硬件 GPU 的 Android 模拟器（非 headless/SwiftShader）：

- `integration_test/mirror_test.dart`：真实 FFI、查询/详情/返回、14 个空闲节次、最少空闲/连续空闲/三种排序均通过（前 3 项）。第 4 项校区/日期流程在设备测试框架内长时间未收敛，已中止，未标记通过。
- `integration_test/schedule_test.dart`：课表 Tab 经真实 FFI 通过，包含周网格课程块、考试区、切换未缓存周次的空态。测试结果：1 项通过。
- `integration_test/grades_test.dart`：成绩 Tab 经真实 FFI 通过，包含加权平均/绩点汇总、课程分数与学分。测试结果：1 项通过。
- `integration_test/today_test.dart`：今天 Tab 经真实 FFI 通过，包含日期/星期、课程数量与当天课程行。测试结果：1 项通过。
- 空教室筛选菜单曾整体压到底部 Tab 下方，导致第 3 节以后不可点击；已在 `choose` 中加入移动端底部安全区并复测。
- 课表截图保存在本机 `artifacts/local/mirror/android-schedule-grid.png`（宽度调整前）。iOS 演示课表截图为“会话过期”空态，不能作为网格像素参照；只用于外壳、刷新按钮和空态结构对照。
