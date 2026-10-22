import 'package:flutter/cupertino.dart';

import 'app_preferences.dart';

/// Device-level palette selection. Preview content is synthetic, never a course
/// query or a school action. No animation is needed to communicate selection.
class AccentThemePicker extends StatelessWidget {
  const AccentThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferencesScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '当前强调色：${preferences.accent.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          AccentCoursePreview(accent: preferences.accent),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22;
              final width = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final accent in AppAccent.values)
                    SizedBox(
                      width: width,
                      child: _AccentChoice(
                        accent: accent,
                        selected: preferences.accent == accent,
                        onPressed: () => preferences.update(accent: accent),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.accent,
    required this.selected,
    required this.onPressed,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(accent.color, context);
    return Semantics(
      key: ValueKey('accent-${accent.name}'),
      label: accent.label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color
                : CupertinoColors.separator.resolveFrom(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: CupertinoButton(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          pressedOpacity: MediaQuery.disableAnimationsOf(context) ? 1 : 0.6,
          onPressed: onPressed,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  accent.label,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 22,
                color: selected
                    ? color
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccentCoursePreview extends StatefulWidget {
  const AccentCoursePreview({super.key, required this.accent});
  final AppAccent accent;

  @override
  State<AccentCoursePreview> createState() => _AccentCoursePreviewState();
}

class _AccentCoursePreviewState extends State<AccentCoursePreview> {
  bool _tried = false;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(widget.accent.color, context);
    return Container(
      key: const ValueKey('accent-course-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('课程卡片 · 示例', style: TextStyle(color: color, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('高等数学', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('08:00–09:35 · 教学楼 A101'),
          const SizedBox(height: 12),
          CupertinoButton(
            key: const ValueKey('accent-preview-button'),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            borderRadius: BorderRadius.circular(10),
            pressedOpacity: MediaQuery.disableAnimationsOf(context) ? 1 : 0.6,
            onPressed: () => setState(() => _tried = !_tried),
            child: Text('试试按钮效果', style: TextStyle(color: color)),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              _tried ? '刚刚好，今天也从容出发。' : '仅预览样式，不会添加课程或提醒。',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
