import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';

/// Owns week-chip measurement, scrolling and post-layout synchronization.
class ScheduleWeekStrip extends StatefulWidget {
  const ScheduleWeekStrip({
    super.key,
    required this.weeks,
    required this.selectedWeek,
    required this.onSelected,
  });
  final List<ScheduleWeek> weeks;
  final int selectedWeek;
  final ValueChanged<int> onSelected;
  @override
  State<ScheduleWeekStrip> createState() => _ScheduleWeekStripState();
}

class _ScheduleWeekStripState extends State<ScheduleWeekStrip> {
  final weekScroll = ScrollController();
  (double, double, int, int)? weekStripLayout;
  int weekStripGeneration = 0;

  @override
  void didUpdateWidget(ScheduleWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeks.length != widget.weeks.length ||
        List.generate(widget.weeks.length, (index) => index).any(
          (index) =>
              oldWidget.weeks[index].number != widget.weeks[index].number,
        )) {
      weekStripLayout = null;
    }
  }

  @override
  void dispose() {
    weekScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = GinkgoSpacing.small;
    const padding = GinkgoSpacing.base;
    final labelStyle = GinkgoTypography.subheadline.copyWith(
      fontFeatures: GinkgoTypography.tabularDigits,
    );
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var labelWidth = 0.0, labelHeight = 0.0;
    for (final week in widget.weeks) {
      for (final weight in [FontWeight.w500, FontWeight.w700]) {
        painter.text = TextSpan(
          text: '第 ${week.number} 周',
          style: labelStyle.copyWith(fontWeight: weight),
        );
        painter.layout();
        if (painter.width > labelWidth) labelWidth = painter.width;
        if (painter.height > labelHeight) labelHeight = painter.height;
      }
    }
    painter.dispose();
    final chipWidth = (labelWidth.ceilToDouble() + 24).clamp(
      72.0,
      double.infinity,
    );
    final extent = chipWidth + gap;
    return SizedBox(
      height: (labelHeight + 30).clamp(60.0, double.infinity),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final index = widget.weeks.indexWhere(
            (week) => week.number == widget.selectedWeek,
          );
          final layout = (
            constraints.maxWidth,
            extent,
            index,
            widget.weeks.length,
          );
          if (weekStripLayout != layout) {
            final oldLayout = weekStripLayout;
            weekStripLayout = layout;
            final generation = ++weekStripGeneration;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  generation != weekStripGeneration ||
                  index < 0 ||
                  !weekScroll.hasClients) {
                return;
              }
              final position = weekScroll.position;
              if (!position.hasContentDimensions) return;
              final center = padding + index * extent + chipWidth / 2;
              final target = (center - position.viewportDimension / 2).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              );
              if (oldLayout == null ||
                  MediaQuery.disableAnimationsOf(context)) {
                weekScroll.jumpTo(target);
              } else {
                weekScroll.animateTo(
                  target,
                  duration: AppleDesign.duration(context, 220),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
          return CupertinoScrollbar(
            controller: weekScroll,
            thumbVisibility: false,
            thickness: 3,
            thicknessWhileDragging: 6,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: ListView.builder(
              key: const Key('schedule-weeks'),
              controller: weekScroll,
              itemExtent: extent,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                padding,
                GinkgoSpacing.xs,
                padding,
                GinkgoSpacing.sm,
              ),
              itemCount: widget.weeks.length,
              itemBuilder: (context, index) {
                final week = widget.weeks[index];
                final active = week.number == widget.selectedWeek;
                final color = CupertinoTheme.of(context).primaryColor;
                return Padding(
                  padding: const EdgeInsets.only(right: gap),
                  child: CupertinoButton(
                    key: Key('schedule-week-${week.number}'),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(72, 48),
                    onPressed: () => widget.onSelected(week.number),
                    child: Semantics(
                      selected: active,
                      label: week.current
                          ? '第 ${week.number} 周，本周'
                          : '第 ${week.number} 周',
                      excludeSemantics: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: active
                              ? color.withValues(alpha: 0.16)
                              : CupertinoColors.tertiarySystemFill.resolveFrom(
                                  context,
                                ),
                          borderRadius: BorderRadius.circular(
                            GinkgoRadii.panel,
                          ),
                          border: active
                              ? Border.all(
                                  color: color.withValues(alpha: 0.42),
                                )
                              : null,
                        ),
                        child: SizedBox.expand(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: GinkgoSpacing.sm,
                            ),
                            child: Center(
                              child: Text(
                                '第 ${week.number} 周',
                                maxLines: 1,
                                softWrap: false,
                                style: labelStyle.copyWith(
                                  fontWeight: active || week.current
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: active || week.current
                                      ? color
                                      : CupertinoColors.label.resolveFrom(
                                          context,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
