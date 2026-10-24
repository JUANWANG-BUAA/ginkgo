# Android 视觉语言、加载反馈与纸感栏目过渡（2026-10-24）

## 范围与结论

本轮针对 Android/Flutter 工作树完成一轮“iOS 组件纪律 + 银杏品牌辨识度”的视觉迭代，同时收敛工作台周边的高频信息权重。没有修改 Apple 源码、Rust 生产协议、认证、TLS、签名或发布配置，也没有执行学校写操作。

用户可感知变化：

- 整页和局部加载统一为银杏叶反馈；品牌叶色不随蓝、紫、珊瑚等强调色变化。
- 页头 icon 底座、分区徽标和常用服务图标收敛为同一尺寸与语义色。
- 主栏目切换从轻移 18dp 改为整页宽纸感滑入，页缘有短暂阴影和书脊渐层。
- 查书工具区压缩，搜索结果更早出现；只读说明可收起。
- 馆藏优先展示馆藏地、学校原始状态，重复索书号用“同索书号”降噪。
- 校车首屏增加“下一班计划”，仅展示静态计划时间与公布容量，不推断余票。
- 图书馆与在馆数据的余量条降低视觉重量；充足、紧张、未知保持文字区别。

## 实现边界

### 共享视觉原语

- `GinkgoIconTile`：默认 44dp、12dp 圆角，选中态仅改变底色透明度。
- `GinkgoBadge`：徽标只承担强调，文字始终保留语义。
- `GinkgoLoadingView`：品牌叶 + 主文案 + 可选说明，使用单一 live-region 语义。
- `GinkgoActivity`：品牌叶固定使用 `AppleDesign.accent`；系统减少动态或 `TickerMode` 关闭时静止且不安排帧。
- `flutter/lib/` 中已无 `CupertinoActivityIndicator` 残留。

### 页头与图标

- `ApplePageHeader` 显式接收 `section`、`subtitle`、`icon`。
- 已删除按标题字符串推断身份的整张映射表；页头身份由各调用方持有。
- 桌面页头、常用服务、今日分区头和快捷入口复用同一 icon tile / badge 原语。
- 功能登记表图标唯一且非空；研究生教务与空教室不再共用同一图标。

### 纸感栏目过渡

- 保留 `CupertinoTabScaffold`、每栏独立 Navigator、懒挂载与单一动画时钟。
- 新页从方向侧整页滑入，230ms 结束，透明度恒为 1。
- 页缘阴影和书脊渐层只在新页入场时出现，结束、后台页或减少动态时透明。
- 不复制 Navigator、不保留旧页绘制、不新增横向拖拽识别器。
- 因此本轮是 **B 档纸感过渡**，不是保留旧页内容的真双页卷页，也不是跟手 3D 翻书。

### 信息权重

- 图书馆主入口与共享 `ResourceMeter` 使用更细、更低饱和的余量条；紧张或未知仍用文字与状态色区分。
- 查书搜索框内嵌提交按钮，排序与方向合并到一行；结果区更早进入首屏。
- 馆藏行按“馆藏地 → 原始状态 → 索书号 → 册条码”排序；同索书号连续复本使用辅助文案。
- 校车“下一班计划”从公开静态表按北京时间本地推算，最多显示三班；页面明确计划容量不是实时余票。

## 实际设备观察

环境：macOS 主机、Android QEMU `emulator-5554`、1080×2400/420dpi；临时切换 540dpi（约 320dp）与系统字号 2.0、深浅色。应用使用正常入口 Debug APK，保留原有模拟器会话；未读取、输入或导出凭据，未执行签到、预约、借阅或购票。

验证路径：

1. 工作台 → 预约 → 图书馆 → 在馆与空间 → 返回。
2. 图书馆 → 查书目与馆藏 → 输入 `Python` → 键盘搜索提交 → 书目详情/馆藏。
3. 工作台 → 校车时刻表，实际捕获银杏加载态与加载完成后的“下一班计划”。
4. 深色模式复看图书馆、校车和工作台。
5. 540dpi + 2.0 字号复看工作台和校车。
6. 用 `screenrecord` 记录栏目切换并抽取中间帧，确认整页滑入和页缘阴影。

公开、无个人记录的精选截图保存在 [assets/2026-10-24-android-visual-language](assets/2026-10-24-android-visual-language/manifest.json)。工作台、课表、作业和个人借阅记录截图留在 ignored 的 `artifacts/local/2026-10-24-visual-language/`，不纳入仓库。

## 验证结果

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub test`：372 项全部通过。
- `bash scripts/check-mirror.sh`：exit 0；包含架构检查、Rust fmt/clippy/测试、Flutter analyze 与全量 widget 测试。
- `git diff --check`：通过。
- 正常入口构建：`flutter build apk --debug --target-platform android-arm64 --target lib/main.dart`，exit 0。
- 最终 APK SHA-256：`960d82fa89dfc362d1d10bc2f9ac44057f443703faeb463e77b060634013ca34`；设备 `base.apk` 摘要与本地一致。
- 已对 `emulator-5554` 执行 `install -r`、`am force-stop` 和冷启动；安装与启动成功。

## 未覆盖项

- 未做物理 Android 真机验收；模拟器截图不能替代真机。
- 未验收预测返回动画、TalkBack 全流程、release/profile 帧率和低端机连续切换性能。
- 减少动态由 widget 矩阵测试覆盖，未在设备设置中逐项截图。
- 未验证旧页绘制的真双页翻书、跟手 3D 卷页或横滑翻页。
- 未执行签到、图书馆预约/取消、CGYY 预约/取消、购票、续借或任何学校写入。
- 未修改或验收 Apple SwiftUI 端。
