import 'package:flutter/cupertino.dart';

import 'application/contracts.dart';

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
    if (oldWidget.weeks != widget.weeks) weekStripLayout = null;
  }

  @override
  void dispose() {
    weekScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    const padding = 16.0;
    const labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var labelWidth = 0.0, labelHeight = 0.0;
    for (final week in widget.weeks) {
      painter.text = TextSpan(
        text: '第 ${week.number} 周',
        style: DefaultTextStyle.of(context).style.merge(labelStyle),
      );
      painter.layout();
      if (painter.width > labelWidth) labelWidth = painter.width;
      if (painter.height > labelHeight) labelHeight = painter.height;
    }
    painter.dispose();
    final chipWidth = (labelWidth + 24).clamp(76.0, double.infinity);
    final extent = chipWidth + gap;
    return SizedBox(
      height: labelHeight + 24,
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
              weekScroll.jumpTo(
                (center - position.viewportDimension / 2).clamp(
                  position.minScrollExtent,
                  position.maxScrollExtent,
                ),
              );
            });
          }
          return ListView.builder(
            key: const Key('schedule-weeks'),
            controller: weekScroll,
            itemExtent: extent,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(padding, 4, padding, 8),
            itemCount: widget.weeks.length,
            itemBuilder: (context, index) {
              final week = widget.weeks[index];
              final active = week.number == widget.selectedWeek;
              final color = CupertinoTheme.of(context).primaryColor;
              return Padding(
                padding: const EdgeInsets.only(right: gap),
                child: CupertinoButton(
                  key: Key('schedule-week-${week.number}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(76, 0),
                  color: active
                      ? color.withValues(alpha: 0.14)
                      : CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  onPressed: () => widget.onSelected(week.number),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '第 ${week.number} 周',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: active
                              ? color
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
