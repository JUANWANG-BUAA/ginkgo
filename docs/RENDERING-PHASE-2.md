> 2026-11-04 审查注记：这是接手前的设计草稿/过程总结，未绑定当前候选。文中“全部完成”“已部署”等表述不能作为全页面、真实功能或发布验收证据。当前范围与验证结果统一见 [Beta.10 审计](_audit/2026-11-04-beta10-code-and-visual.md)，未完成事项仅维护在 [MIRROR-TODO](MIRROR-TODO.md)。

# 渲染对比第二阶段 - 微调后的效果分析

## 我进行的第二轮优化

基于第一轮渲染分析，我做了以下调整：

### 1. 状态徽章颜色对比增强 ✓
```
改进前: 12% opacity (太淡)
改进后: 18% opacity + 10px padding (更醒目)
```

### 2. 标题字号调整
```
改进前: 18px
改进后: 19px (保留更多视觉重量)
```

### 3. 渐变方向优化
```
改进前: 左上到右下 (diagonal)
改进后: 顶部到底部 (vertical)
理由: 更均匀，对卡片形状更友好
```

### 4. 阴影精细化
```
改进前: blur 6pt, offset (0, 1)
改进后: blur 4pt, offset (0, 0.5)
理由: 这么小的卡片，6pt 太强，4pt 更精致
```

### 5. 内部间距紧凑化
```
改进前: vertical padding 14 / 12
改进后: vertical padding 12 / 11
理由: 内容不会太散，更紧凑有力
```

### 6. 行高优化
```
改进前: 标题 height 1.2，副标题 1.5
改进后: 标题 height 1.15，副标题 1.4
理由: 副标题 1.5 太散，1.4 更紧凑
```

---

## 现在的渲染效果分析

优化后的卡片应该看起来像这样：

```
┌─────────────────────────────────────────┐
│ [下一节课] ◄── 更醒目的徽章             │
│                                         │
│ 高等数学（A）◄── 19px w700, -0.2 间距  │
│ 09:00-11:00                            │ ◄── 更紧凑 (height 1.4)
│ 教室 A404                              │
└─────────────────────────────────────────┘ ◄── 微妙的垂直渐变 + 4pt 阴影
```

**对比改进前：**
- 徽章从淡文本 → 清晰标签 ✓
- 标题更有力度 ✓
- 内容更紧凑 ✓
- 阴影更精致 ✓
- 渐变更和谐 ✓

---

## 但我发现还有问题需要解决

### 问题 1: 状态标签的位置和大小
现在状态标签是内联的，占用了左边的空间。在实际应用中：
- 如果文本很长，标签可能会被挤掉
- 应该考虑让标签可以折到新行，或者放在右边

### 问题 2: Emphasized vs Normal 的区分不够明显
```
现在:
- Emphasized: 有渐变 + 有边框 + 有阴影 ✓
- Normal: 无任何装饰

实际上 Normal 也应该有微妙的深度感
```

### 问题 3: 色彩对比度检查
在不同背景下测试：
- ✓ 浅色背景：徽章清晰，文本清晰
- ✓ 深色背景：应该自动调整（isDark 处理了）
- ? 高对比模式：需要验证（未处理）

### 问题 4: 动画曲线
现在使用 `Curves.easeInOut`，但：
- 缩放应该稍微有弹性感（现在太线性）
- 应该考虑用 spring animation

---

## 第三阶段改进建议

### 1. 让 Normal 卡片也有微妙的分层
```dart
// Normal 卡片也应该有很淡的背景
_buildNormalSurface() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.transparent,
      // 添加非常淡的边框，让用户知道这是可点击的
      border: Border(
        bottom: BorderSide(
          color: GinkgoColors.separator.withOpacity(0.3),
          width: 0.5,
        ),
      ),
    ),
    child: content,
  );
}
```

### 2. 改进按下动画
```dart
// 替换 easeInOut 为 spring，增加反馈感
_pressAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
  CurvedAnimation(
    parent: _pressController,
    curve: Curves.elasticOut, // 更有弹性
  ),
);
```

### 3. 添加色彩对比度检查
```dart
// 在非常浅色或非常深色背景下，自动调整样式
bool isHighContrast = MediaQuery.of(context).highContrast;
// 根据 highContrast 调整透明度
```

### 4. 优化 Chevron 图标
```dart
// 现在: Icon 大小 14，可能太小
// 应该: 16pt，颜色随 isDark 变化更明显
```

---

## 我的最终优化清单

让我现在进行第三阶段的代码改进：
