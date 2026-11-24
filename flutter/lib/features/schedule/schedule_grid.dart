import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/day_scroll_physics.dart';

import 'schedule_grid_course_block.dart';
import 'schedule_grid_layout.dart';
import 'schedule_style.dart';

/// Full-week 7-column iOS timetable card.
///
/// Fits all seven days cleanly onto a single screen on standard phones
/// (`>= 340dp` card width) with circular Apple Calendar date headers and
/// morning / afternoon / evening grouping dividers; falls back to smooth
/// horizontal scrolling only on ultra-narrow `< 340dp` viewports.
class ScheduleGrid extends StatefulWidget {
  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.onCourseTap,
    this.weekStart,
  });
  final List<ScheduleCourse> courses;
  final String? weekStart;
  final ValueChanged<ScheduleCourse> onCourseTap;

  @override
  State<ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<ScheduleGrid> {
  final horizontalScroll = ScrollController();
  late ScheduleGridLayout layout;

  @override
  void initState() {
    super.initState();
    layout = ScheduleGridLayout.of(widget.courses);
  }

  @override
  void dispose() {
    horizontalScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScheduleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.courses, widget.courses)) {
      layout = ScheduleGridLayout.of(widget.courses);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
      final cardBg = CupertinoColors.secondarySystemGroupedBackground
          .resolveFrom(context);
      final headerBg = CupertinoColors.tertiarySystemGroupedBackground
          .resolveFrom(context);
      final separator = CupertinoColors.separator.resolveFrom(context);
      final primary = CupertinoTheme.of(context).primaryColor;
      final todayDay = scheduleTodayColumn(widget.weekStart);
      final start = DateTime.tryParse(widget.weekStart ?? '');
      final monthLabel = start == null ? '节次' : '${start.month}月';

      final rawColumn = (constraints.maxWidth - scheduleGridAxisWidth) / 7;
      final columnWidth = math.max(44.0, rawColumn);
      final totalWidth = scheduleGridAxisWidth + columnWidth * 7;
      final sectionCount = layout.sectionCount;
      final gridHeight =
          scheduleGridHeaderHeight + sectionCount * scheduleGridCellHeight;

      final grid = SizedBox(
        width: totalWidth,
        height: gridHeight,
        child: ColoredBox(
          color: cardBg,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: scheduleGridHeaderHeight,
                child: ColoredBox(color: headerBg),
              ),
              if (todayDay != null)
                Positioned(
                  left: scheduleGridAxisWidth + (todayDay - 1) * columnWidth,
                  top: 0,
                  width: columnWidth,
                  height: gridHeight,
                  child: ColoredBox(
                    color: primary.withValues(alpha: dark ? 0.10 : 0.05),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    columnWidth: columnWidth,
                    sectionCount: sectionCount,
                    lineColor: separator,
                    accentColor: primary,
                  ),
                ),
              ),
              for (var day = 1; day <= 7; day++)
                Positioned(
                  left: scheduleGridAxisWidth + (day - 1) * columnWidth,
                  top: 0,
                  width: columnWidth,
                  height: scheduleGridHeaderHeight,
                  child: _DayHeaderCell(
                    day: day,
                    date: start?.add(Duration(days: day - 1)),
                    isToday: todayDay == day,
                    primary: primary,
                    dark: dark,
                  ),
                ),
              for (final course in widget.courses)
                Positioned(
                  left:
                      scheduleGridAxisWidth +
                      (course.day - 1) * columnWidth +
                      (layout.placements[course.id]?.lane ?? 0) *
                          columnWidth /
                          (layout.placements[course.id]?.count ?? 1) +
                      1.5,
                  top:
                      scheduleGridHeaderHeight +
                      (course.startSection - 1) * scheduleGridCellHeight +
                      1.5,
                  width:
                      columnWidth / (layout.placements[course.id]?.count ?? 1) -
                      3,
                  height:
                      (course.endSection - course.startSection + 1) *
                          scheduleGridCellHeight -
                      3,
                  child: ScheduleGridCourseBlock(
                    course: course,
                    onTap: () => widget.onCourseTap(course),
                  ),
                ),
            ],
          ),
        ),
      );

      final axis = _timeAxis(cardBg, headerBg, monthLabel, sectionCount);

      return DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(
            color: separator.withValues(alpha: 0.38),
            width: GinkgoSpacing.hairline,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          child: totalWidth <= constraints.maxWidth + 0.5
              ? Stack(children: [grid, axis])
              : Stack(
                  children: [
                    SingleChildScrollView(
                      key: const Key('schedule-grid-horizontal'),
                      controller: horizontalScroll,
                      physics: DayScrollPhysics(dayWidth: columnWidth),
                      scrollDirection: Axis.horizontal,
                      child: grid,
                    ),
                    Positioned(left: 0, top: 0, bottom: 0, child: axis),
                  ],
                ),
        ),
      );
    },
  );

  Widget _timeAxis(
    Color cardBg,
    Color headerBg,
    String monthLabel,
    int sectionCount,
  ) => AbsorbPointer(
    child: Container(
      key: const Key('schedule-fixed-time-axis'),
      width: scheduleGridAxisWidth,
      height: scheduleGridHeaderHeight + sectionCount * scheduleGridCellHeight,
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          right: BorderSide(
            color: CupertinoColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.45),
            width: GinkgoSpacing.hairline,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: scheduleGridHeaderHeight,
            child: ColoredBox(
              color: headerBg,
              child: Center(
                child: Text(
                  monthLabel,
                  style: GinkgoTypography.caption2.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: GinkgoTypography.tabularDigits,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
          for (var section = 1; section <= sectionCount; section++)
            Positioned(
              left: 0,
              top:
                  scheduleGridHeaderHeight +
                  (section - 1) * scheduleGridCellHeight,
              width: scheduleGridAxisWidth,
              height: scheduleGridCellHeight,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$section',
                      style: GinkgoTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        fontFeatures: GinkgoTypography.tabularDigits,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    if (layout.times[section] != null)
                      Text(
                        layout.times[section]!,
                        style: GinkgoTypography.caption2.copyWith(
                          height: 1.1,
                          fontFeatures: GinkgoTypography.tabularDigits,
                          color: CupertinoColors.tertiaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({
    required this.day,
    required this.date,
    required this.isToday,
    required this.primary,
    required this.dark,
  });

  final int day;
  final DateTime? date;
  final bool isToday;
  final Color primary;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final dayLabel = shortWeekdayLetters[day - 1];
    final dateNumber = date == null ? '' : '${date!.day}';
    return Semantics(
      label: '${weekdayNames[day - 1]}${date == null ? '' : ' ${date!.month}/${date!.day}'}${isToday ? ' 今天' : ''}',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayLabel,
            style: GinkgoTypography.caption2.copyWith(
              height: 1.1,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
              color: isToday ? primary : secondary,
            ),
          ),
          if (dateNumber.isNotEmpty) ...[
            const SizedBox(height: GinkgoSpacing.opticalIconInset),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: primary.withValues(alpha: dark ? 0.28 : 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primary.withValues(alpha: 0.55),
                      ),
                    )
                  : null,
              child: Text(
                dateNumber,
                style: GinkgoTypography.caption.copyWith(
                  height: 1.0,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                  fontFeatures: GinkgoTypography.tabularDigits,
                  color: isToday
                      ? primary
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.columnWidth,
    required this.sectionCount,
    required this.lineColor,
    required this.accentColor,
  });
  final double columnWidth;
  final int sectionCount;
  final Color lineColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final hairline = Paint()
      ..color = lineColor.withValues(alpha: 0.25)
      ..strokeWidth = GinkgoSpacing.hairline;
    final groupLine = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;

    final header = scheduleGridHeaderHeight;
    for (var row = 0; row <= sectionCount; row++) {
      final y = header + row * scheduleGridCellHeight;
      // Emphasize morning/afternoon (after section 5) and afternoon/evening
      // (after section 9) boundaries just like iOS campus timetables.
      final paint = (row == 0 || row == 5 || row == 9) ? groupLine : hairline;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var column = 0; column <= 7; column++) {
      final x = scheduleGridAxisWidth + column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hairline);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.columnWidth != columnWidth ||
      oldDelegate.sectionCount != sectionCount ||
      oldDelegate.lineColor != lineColor;
}
