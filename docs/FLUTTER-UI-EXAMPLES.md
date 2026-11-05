> 2026-11-04 审查注记：这是接手前的设计草稿/过程总结，未绑定当前候选。文中“全部完成”“已部署”等表述不能作为全页面、真实功能或发布验收证据。当前范围与验证结果统一见 [Beta.10 审计](_audit/2026-11-04-beta10-code-and-visual.md)，未完成事项仅维护在 [MIRROR-TODO](MIRROR-TODO.md)。

# Flutter 设计优化实例集合

本文档展示如何在实际 Ginkgo 页面中应用新的设计系统。

## 例 1: 优化 Today 页面卡片

### 之前
```dart
VStack(alignment: .leading, spacing: 24) {
  Card(
    child: Column(children: [
      Text("接下来要做", style: .headline)
      // 内容...
    ]),
  )
}
```

### 之后
```dart
GinkgoCard(
  elevation: GinkgoElevation.md,
  borderRadius: GinkgoRadii.panel,
  padding: EdgeInsets.all(GinkgoSpacing.base),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "接下来要做",
        style: GinkgoTypography.headline,
      ),
      // 内容...
    ],
  ),
)
```

**改进:**
- 统一的阴影系统提供深度感
- 符合 Apple HIG 的圆角
- 一致的内间距

## 例 2: 课程项优化

### 之前
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
  ),
  child: Row(
    children: [
      Text(time),
      Column(
        children: [
          Text(courseName),
          Text(location),
        ],
      ),
    ],
  ),
)
```

### 之后
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(GinkgoRadii.compact),
    boxShadow: GinkgoElevation.xs,
  ),
  child: Padding(
    padding: EdgeInsets.all(GinkgoSpacing.base),
    child: Row(
      children: [
        Text(
          time,
          style: GinkgoTypography.body,
        ),
        SizedBox(width: GinkgoSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courseName,
                style: GinkgoTypography.headline,
              ),
              SizedBox(height: GinkgoSpacing.xs),
              Text(
                location,
                style: GinkgoTypography.callout.copyWith(
                  color: GinkgoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
)
```

**改进:**
- 微妙的阴影提升交互感
- 一致的间距和排版
- 更易于维护的间距定义

## 例 3: 作业截止项

### 之前
```dart
Card(
  child: ListTile(
    title: Text(homework.title),
    subtitle: Text(deadline),
    trailing: Icon(Icons.check),
  ),
)
```

### 之后
```dart
GinkgoCard(
  elevation: homework.isUrgent
      ? GinkgoElevation.sm
      : GinkgoElevation.xs,
  child: Row(
    children: [
      Container(
        width: 4,
        height: 60,
        decoration: BoxDecoration(
          color: homework.isUrgent
              ? GinkgoColors.statusDanger
              : GinkgoColors.statusPending,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(GinkgoRadii.compact),
            bottomLeft: Radius.circular(GinkgoRadii.compact),
          ),
        ),
      ),
      SizedBox(width: GinkgoSpacing.base),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homework.title,
              style: GinkgoTypography.body.copyWith(
                fontWeight: homework.isUrgent
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            SizedBox(height: GinkgoSpacing.xs),
            Text(
              "截止: ${homework.deadline}",
              style: GinkgoTypography.callout.copyWith(
                color: GinkgoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
      Icon(
        CupertinoIcons.check_mark_circled,
        color: GinkgoColors.statusSuccess,
      ),
    ],
  ),
)
```

**改进:**
- 根据优先级动态调整阴影
- 左侧彩色条显示状态
- 更清晰的视觉层级
- 易于扩展的设计

## 例 4: 操作按钮

### 之前
```dart
CupertinoButton.filled(
  onPressed: onTap,
  child: Text('添加待办'),
)
```

### 之后
```dart
GinkgoButton(
  label: '添加待办',
  onPressed: onTap,
  variant: GinkgoButtonVariant.primary,
  size: GinkgoButtonSize.medium,
  icon: CupertinoIcons.plus,
)
```

**改进:**
- 自动按下缩放动画 (95%)
- 自动无障碍支持
- 三种变体（实心、次级、幽灵）
- 更灵活的 API

## 例 5: 分段操作

### 之前
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    ElevatedButton(...),
    ElevatedButton(...),
    ElevatedButton(...),
  ],
)
```

### 之后
```dart
Row(
  children: [
    Expanded(
      child: GinkgoButton(
        label: '取消',
        onPressed: onCancel,
        variant: GinkgoButtonVariant.ghost,
      ),
    ),
    SizedBox(width: GinkgoSpacing.md),
    Expanded(
      child: GinkgoButton(
        label: '确认',
        onPressed: onConfirm,
        variant: GinkgoButtonVariant.primary,
      ),
    ),
  ],
)
```

**改进:**
- 统一的间距
- 清晰的视觉优先级
- 响应式布局

## 例 6: 加载态

### 之前
```dart
if (isLoading) {
  CircularProgressIndicator()
} else {
  // 内容
}
```

### 之后
```dart
if (isLoading) {
  GinkgoLoadingIndicator(
    message: '正在加载课表...',
  )
} else {
  // 内容
}
```

**改进:**
- 专业的加载提示
- 统一的间距和排版
- 无障碍友好

## 例 7: 空状态

### 之前
```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.inbox),
    Text('暂无内容'),
  ],
)
```

### 之后
```dart
GinkgoEmptyState(
  icon: CupertinoIcons.inbox,
  title: '暂无待办',
  message: '完成所有任务后会出现在这里',
  actionLabel: '创建待办',
  action: onCreateTask,
)
```

**改进:**
- 专业的空状态设计
- 可选的操作按钮
- 一致的排版和间距

## 例 8: 底部表单

### 之前
```dart
showModalBottomSheet(
  context: context,
  builder: (context) => Container(
    child: Column(children: [...]),
  ),
)
```

### 之后
```dart
showGinkgoBottomSheet(
  context: context,
  title: '选择截止日期',
  enableDrag: true,
  builder: (context) => ListView(
    children: [...],
  ),
)
```

**改进:**
- 拖拽指示器
- 标题和关闭按钮
- 统一的外观

## 例 9: 确认对话框

### 之前
```dart
showCupertinoDialog(
  context: context,
  builder: (context) => CupertinoAlertDialog(
    title: Text('删除待办'),
    content: Text('此操作无法撤销'),
    actions: [
      CupertinoDialogAction(child: Text('取消')),
      CupertinoDialogAction(
        isDestructiveAction: true,
        child: Text('删除'),
      ),
    ],
  ),
)
```

### 之后
```dart
showCupertinoDialog(
  context: context,
  builder: (context) => GinkgoAlertDialog(
    title: '删除待办',
    message: '此操作无法撤销',
    actions: [
      GinkgoAlertAction(label: '取消'),
      GinkgoAlertAction(
        label: '删除',
        isDestructive: true,
        onPressed: () => onDelete(),
      ),
    ],
  ),
)
```

**改进:**
- 统一的文本排版
- 更简洁的 API
- 自动无障碍标注

## 例 10: 页面过渡

### 之前
```dart
Navigator.push(
  context,
  CupertinoPageRoute(
    builder: (context) => DetailPage(),
  ),
);
```

### 之后
```dart
Navigator.push(
  context,
  GinkgoPageRoute(
    title: 'Details',
    builder: (context) => DetailPage(),
  ),
);
```

**改进:**
- 自动使用优化的动画时长
- 一致的过渡体验
- 易于修改全局过渡参数

## 迁移检查表

### Today 页面
- [ ] 使用 `GinkgoCard` 替换所有卡片
- [ ] 课程项添加 `GinkgoElevation.xs` 阴影
- [ ] 优化按钮为 `GinkgoButton`
- [ ] 更新操作间距为 `GinkgoSpacing` 常量
- [ ] 字体全部改为 `GinkgoTypography`

### Homework 页面
- [ ] 作业列表项改为 `GinkgoCard` + 彩色条
- [ ] 截止日期按钮使用 `GinkgoButton`
- [ ] 底部操作使用 `showGinkgoBottomSheet`
- [ ] 确认对话框改为 `GinkgoAlertDialog`

### Tasks 页面
- [ ] 列表项改为 `GinkgoCard`
- [ ] 添加按钮改为 `GinkgoButton`
- [ ] 空状态改为 `GinkgoEmptyState`
- [ ] 删除确认使用 `GinkgoAlertDialog`

### 全局改进
- [ ] 所有 `CircularProgressIndicator` 改为 `GinkgoLoadingIndicator`
- [ ] 所有 `CupertinoPageRoute` 改为 `GinkgoPageRoute`
- [ ] 所有间距数字替换为 `GinkgoSpacing` 常量
- [ ] 所有圆角替换为 `GinkgoRadii` 常量
