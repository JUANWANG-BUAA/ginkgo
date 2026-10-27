import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart' show choose;
import 'package:ginkgo_mirror/widgets/day_scroll_physics.dart';

import 'schedule_grid_course_block.dart';
import 'schedule_grid_layout.dart';
import 'schedule_style.dart';

/// Seven-day timetable grid. Course blocks span their section range and open
/// a course detail page on tap.
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
      final columnWidth = math.max(
        106.0,
        (constraints.maxWidth - scheduleGridAxisWidth) / 7,
      );
      final totalWidth = scheduleGridAxisWidth + columnWidth * 7;
      final grid = SizedBox(
        width: totalWidth,
        height:
            scheduleGridHeaderHeight +
            scheduleGridSectionCount * scheduleGridCellHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  columnWidth,
                  CupertinoColors.separator.resolveFrom(context),
                ),
              ),
            ),
            if (scheduleTodayColumn(widget.weekStart) case final int day)
              Positioned(
                left: scheduleGridAxisWidth + (day - 1) * columnWidth,
                top: 0,
                width: columnWidth,
                height:
                    scheduleGridHeaderHeight +
                    scheduleGridSectionCount * scheduleGridCellHeight,
                child: ColoredBox(
                  color: CupertinoTheme.of(context).primaryColor
                      .withValues(alpha: 0.06),
                ),
              ),
            for (var day = 1; day <= 7; day++)
              Positioned(
                left: scheduleGridAxisWidth + (day - 1) * columnWidth,
                top: 0,
                width: columnWidth,
                height: scheduleGridHeaderHeight,
                child: Center(
                  child: Text(
                    '${weekdayNames[day - 1]}${widget.weekStart == null ? '' : '\n${shortDate(DateTime.parse(widget.weekStart!).add(Duration(days: day - 1)).toIso8601String())}'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
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
                    3,
                top:
                    scheduleGridHeaderHeight +
                    (course.startSection - 1) * scheduleGridCellHeight +
                    2,
                width:
                    columnWidth / (layout.placements[course.id]?.count ?? 1) -
                    6,
                height:
                    (course.endSection - course.startSection + 1) *
                        scheduleGridCellHeight -
                    4,
                child: ScheduleGridCourseBlock(
                  course: course,
                  onTap: () => widget.onCourseTap(course),
                ),
              ),
          ],
        ),
      );
      return totalWidth <= constraints.maxWidth
          ? Stack(children: [grid, _timeAxis()])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _horizontalControls(columnWidth, constraints.maxWidth),
                CupertinoScrollbar(
                  key: const Key('schedule-grid-top-scrollbar'),
                  controller: horizontalScroll,
                  thumbVisibility: true,
                  thickness: 5,
                  thicknessWhileDragging: 10,
                  scrollbarOrientation: ScrollbarOrientation.top,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        key: const Key('schedule-grid-horizontal'),
                        controller: horizontalScroll,
                        physics: DayScrollPhysics(dayWidth: columnWidth),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(top: 12),
                        child: grid,
                      ),
                      Positioned(
                        left: 0,
                        top: 12,
                        bottom: 0,
                        child: _timeAxis(),
                      ),
                    ],
                  ),
                ),
              ],
            );
    },
  );

  Widget _timeAxis() => AbsorbPointer(
    child: Container(
      key: const Key('schedule-fixed-time-axis'),
      width: scheduleGridAxisWidth,
      height:
          scheduleGridHeaderHeight +
          scheduleGridSectionCount * scheduleGridCellHeight,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(
          right: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 20,
            left: 15,
            child: Text('节次', style: TextStyle(fontSize: 12)),
          ),
          for (var section = 1; section <= scheduleGridSectionCount; section++)
            Positioned(
              left: 0,
              top:
                  scheduleGridHeaderHeight +
                  (section - 1) * scheduleGridCellHeight,
              width: scheduleGridAxisWidth,
              height: scheduleGridCellHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${layout.times[section] ?? '第$section节'}${layout.times[section] == null ? '' : '\n第$section节'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _horizontalControls(
    double columnWidth,
    double viewportWidth,
  ) => AnimatedBuilder(
    animation: horizontalScroll,
    builder: (context, _) {
      final offset = horizontalScroll.hasClients
          ? horizontalScroll.offset
          : 0.0;
      final maxExtent = horizontalScroll.hasClients
          ? horizontalScroll.position.maxScrollExtent
          : scheduleGridAxisWidth + columnWidth * 7 - viewportWidth;
      final first = (offset / columnWidth).floor().clamp(0, 6);
      final last =
          ((offset + viewportWidth - scheduleGridAxisWidth) / columnWidth).ceil()
                  .clamp(1, 7) -
              1;
      void move(double delta) {
        if (!horizontalScroll.hasClients) return;
        final target = (horizontalScroll.offset + delta).clamp(0.0, maxExtent);
        if (MediaQuery.disableAnimationsOf(context)) {
          horizontalScroll.jumpTo(target);
        } else {
          horizontalScroll.animateTo(
            target,
            duration: AppleDesign.duration(context, 180),
            curve: Curves.easeOut,
          );
        }
      }

      Widget arrow({required bool next}) => CupertinoButton(
        key: Key(
          next ? 'schedule-grid-next-days' : 'schedule-grid-previous-days',
        ),
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: next
            ? (offset < maxExtent - 1 ? () => move(columnWidth * 2) : null)
            : (offset > 1 ? () => move(-columnWidth * 2) : null),
        child: Semantics(
          label: next ? '查看后面的日期' : '查看前面的日期',
          child: Icon(
            next ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
            size: 17,
          ),
        ),
      );
      return Row(
        children: [
          arrow(next: false),
          Expanded(
            child: Builder(
              builder: (anchor) => CupertinoButton(
                key: const Key('schedule-day-jump'),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: () async {
                  final day = await choose<int>(
                    anchor,
                    '跳转到星期',
                    [1, 2, 3, 4, 5, 6, 7],
                    (day) => weekdayNames[day - 1],
                    selected: first + 1,
                  );
                  if (!mounted || day == null || !horizontalScroll.hasClients) {
                    return;
                  }
                  move((day - 1) * columnWidth - horizontalScroll.offset);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.arrow_left_right, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${weekdayNames[first]}–${weekdayNames[last]}',
                        key: const Key('schedule-grid-visible-days'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.chevron_down, size: 11),
                  ],
                ),
              ),
            ),
          ),
          arrow(next: true),
        ],
      );
    },
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.columnWidth, this.lineColor);
  final Color lineColor;
  final double columnWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.5;
    final header = scheduleGridHeaderHeight;
    for (var row = 0; row <= scheduleGridSectionCount; row++) {
      final y = header + row * scheduleGridCellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var column = 0; column <= 7; column++) {
      final x = scheduleGridAxisWidth + column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.columnWidth != columnWidth ||
      oldDelegate.lineColor != lineColor;
}
