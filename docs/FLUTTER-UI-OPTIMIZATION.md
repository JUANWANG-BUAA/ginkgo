> 2026-11-04 审查注记：这是接手前的设计草稿/过程总结，未绑定当前候选。文中“全部完成”“已部署”等表述不能作为全页面、真实功能或发布验收证据。当前范围与验证结果统一见 [Beta.10 审计](_audit/2026-11-04-beta10-code-and-visual.md)，未完成事项仅维护在 [MIRROR-TODO](MIRROR-TODO.md)。

# Flutter UI 优化指南 - Swift 质感升级

## 概述

本指南说明如何将新增的设计系统组件应用于 Ginkgo Flutter 项目，达到 Swift 级别的设计质感。

## 新增系统组件

### 1. 增强的动画系统 (`tokens/motion.dart`)

**改进：**
- 多层次的动画时长（snappy: 120ms, quick: 150ms, normal: 180ms, smooth: 240ms）
- 更多的曲线选项（easeOut, easeInOut, swiftSpring, gentleSpring）
- 内置无障碍支持

**使用示例：**
```dart
// 替代 GinkgoMotion.normal
withAnimation(Duration: GinkgoMotion.snappy) {
  // 快速闪烁反馈
}

withAnimation(GinkgoMotion.smooth, .easeInOut) {
  // 平滑过渡
}
```

### 2. 阴影与海拔系统 (`tokens/elevation.dart`)

**6 个海拔级别：**
- `xs`: 1pt - 交互元素（按钮、可点击项）
- `sm`: 2pt - 浮动效果
- `md`: 4pt - 标准卡片
- `lg`: 8pt - 强调浮动表面
- `xl`: 12pt - 高强调模态框
- `xxl`: 16pt - 顶层内容

**使用示例：**
```dart
// 应用到容器
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: GinkgoElevation.md.shadows,
  ),
)
```

### 3. 高级组件库 (`widgets/ginkgo_polished_widgets.dart`)

#### GinkgoButton - 精致按钮
```dart
GinkgoButton(
  label: '确认',
  onPressed: () {},
  variant: GinkgoButtonVariant.primary,
  size: GinkgoButtonSize.medium,
  icon: CupertinoIcons.check,
)
```

**特性：**
- 按下时自动缩放动画（95% 缩放）
- 三种样式：primary（实心）、secondary（填充）、ghost（边框）
- 三种尺寸：small、medium、large
- 加载态支持

#### GinkgoCard - 精致卡片
```dart
GinkgoCard(
  elevation: GinkgoElevation.md.shadows,
  borderRadius: GinkgoRadii.panel,
  child: // 内容
)
```

#### GinkgoDivider - 平滑分隔线
```dart
GinkgoDivider(
  height: 1,
  color: GinkgoColors.separator,
)
```

### 4. 对话框与底部工作表 (`widgets/ginkgo_dialog_widgets.dart`)

#### 底部工作表
```dart
showGinkgoBottomSheet(
  context: context,
  title: '选择操作',
  enableDrag: true,
  builder: (context) => // 内容
)
```

#### 警告对话框
```dart
showCupertinoDialog(
  context: context,
  builder: (context) => GinkgoAlertDialog(
    title: '确认删除',
    message: '此操作无法撤销',
    actions: [
      GinkgoAlertAction(label: '取消'),
      GinkgoAlertAction(
        label: '删除',
        isDestructive: true,
      ),
    ],
  ),
)
```

#### 空状态
```dart
GinkgoEmptyState(
  icon: CupertinoIcons.folder,
  title: '暂无内容',
  message: '点击下方按钮添加内容',
  actionLabel: '添加',
  action: () {},
)
```

#### 加载指示器
```dart
GinkgoLoadingIndicator(
  message: '正在加载...',
)
```

## 迁移现有页面

### 第 1 步：更新动画
```dart
// 之前
withAnimation(.easeOut(duration: 0.22)) {
  // ...
}

// 之后
withAnimation(GinkgoMotion.normal) {
  // 自动处理无障碍
}
```

### 第 2 步：增强卡片
```dart
// 之前
Container(
  child: content,
  decoration: BoxDecoration(
    color: GinkgoColors.secondaryGroupedBackground,
    borderRadius: BorderRadius.circular(12),
  ),
)

// 之后
GinkgoCard(
  elevation: GinkgoElevation.md.shadows,
  child: content,
)
```

### 第 3 步：优化按钮
```dart
// 之前
CupertinoButton.filled(
  onPressed: () {},
  child: Text('确认'),
)

// 之后
GinkgoButton(
  label: '确认',
  onPressed: () {},
  variant: GinkgoButtonVariant.primary,
)
```

### 第 4 步：改进对话框
```dart
// 使用 GinkgoAlertDialog 替代 CupertinoAlertDialog
// 使用 showGinkgoBottomSheet 替代 showCupertinoModalPopup
```

## 最佳实践

### 1. 动画优先级
- 快速反馈（按钮按下）：`GinkgoMotion.snappy`
- 页面过渡：`GinkgoMotion.normal`
- 平滑展开/折叠：`GinkgoMotion.smooth`

### 2. 海拔使用
- 可交互的单个元素：`xs` 或 `sm`
- 内容卡片：`md`
- 模态/工作表：`lg` 或 `xl`
- 不要过度使用 - 大多数页面使用 `none` 或 `xs`

### 3. 组件一致性
- 所有按钮使用 `GinkgoButton`
- 所有卡片使用 `GinkgoCard`
- 所有对话框使用 Ginkgo 对话框组件

### 4. 无障碍
- 所有动画自动尊重系统的"减少动作"设置
- 不需要额外处理 `MediaQuery.disableAnimationsOf`

## 验证清单

- [ ] 页面过渡使用 `GinkgoMotion` 的适当时长
- [ ] 卡片使用 `GinkgoCard` 并应用正确的海拔
- [ ] 按钮全部迁移到 `GinkgoButton`
- [ ] 对话框使用新的 Ginkgo 组件
- [ ] 在设置中禁用动画后测试页面（无障碍）
- [ ] 在浅色和深色模式下测试阴影
- [ ] 检查页面在不同屏幕尺寸下的表现

## 后续优化方向

1. **微交互** - 为列表项添加按下反馈
2. **列表组件** - 创建 `GinkgoListTile` 和 `GinkgoListSection`
3. **输入组件** - 增强文本输入框和表单字段
4. **状态指示** - 更精致的加载和错误状态
5. **动画页面** - 创建具有共享元素过渡的页面路由

## 性能考虑

- 阴影不会显著影响性能（使用原生 Flutter 阴影）
- 按钮的缩放动画使用单一 `AnimationController`（高效）
- 所有组件都尊重系统的 `disableAnimations` 设置

## 兼容性

- 最低支持：Flutter 3.0+
- 平台：iOS、Android、macOS、Windows
- 与现有 Cupertino 组件完全兼容
