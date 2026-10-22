import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart' show choose;
import 'day_scroll_physics.dart';
import 'schedule_style.dart';
import 'application/contracts.dart';

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
  @override
  void dispose() {
    horizontalScroll.dispose();
    super.dispose();
  }

  List<ScheduleCourse> get courses => widget.courses;
  String? get weekStart => widget.weekStart;
  void onCourseTap(ScheduleCourse course) => widget.onCourseTap(course);
  Map<String, ({int lane, int count})> placements = {};
  Map<int, String> times = {};
  @override
  void initState() {
    super.initState();
    prepare();
  }

  @override
  void didUpdateWidget(covariant ScheduleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.courses, widget.courses)) prepare();
  }

  void prepare() {
    placements = {};
    times = {};
    final conflicts = <int>{};
    for (final course in courses) {
      final time = course.startTime;
      if (time == null) continue;
      if (times.containsKey(course.startSection) &&
          times[course.startSection] != time) {
        conflicts.add(course.startSection);
      }
      times[course.startSection] = time;
    }
    // Different schemes may share section numbers with different clock times.
    // Keep the section axis neutral in that case; each block shows its own time.
    for (final section in conflicts) {
      times.remove(section);
    }
    // Same interval grouping as macOS TimetableLayout: conflicts use lanes.
    for (var day = 1; day <= 7; day++) {
      final ordered = courses.where((c) => c.day == day).toList()
        ..sort((a, b) {
          final n = a.startSection.compareTo(b.startSection);
          return n == 0 ? a.id.compareTo(b.id) : n;
        });
      var group = <ScheduleCourse>[];
      var end = 0;
      void commit() {
        final laneEnds = <int>[];
        final lanes = <String, int>{};
        for (final course in group) {
          var lane = laneEnds.indexWhere((end) => end < course.startSection);
          if (lane < 0) {
            lane = laneEnds.length;
            laneEnds.add(course.endSection);
          } else {
            laneEnds[lane] = course.endSection;
          }
          lanes[course.id] = lane;
        }
        for (final course in group) {
          placements[course.id] = (
            lane: lanes[course.id]!,
            count: laneEnds.length,
          );
        }
      }

      for (final course in ordered) {
        if (group.isNotEmpty && course.startSection > end) {
          commit();
          group = [];
          end = 0;
        }
        group.add(course);
        end = math.max(end, course.endSection);
      }
      commit();
    }
  }

  static const double axisWidth = 60;
  static const double headerHeight = 58;
  static const int sectionCount = 14;
  static const double cellHeight = 58;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columnWidth = math.max(
        106.0,
        (constraints.maxWidth - axisWidth) / 7,
      );
      final totalWidth = axisWidth + columnWidth * 7;
      final grid = SizedBox(
        width: totalWidth,
        height: headerHeight + sectionCount * cellHeight,
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
            if (_todayColumn() case final int day)
              Positioned(
                left: axisWidth + (day - 1) * columnWidth,
                top: 0,
                width: columnWidth,
                height: headerHeight + sectionCount * cellHeight,
                child: ColoredBox(
                  color: CupertinoTheme.of(context).primaryColor
                      .withValues(alpha: 0.06),
                ),
              ),
            for (var day = 1; day <= 7; day++)
              Positioned(
                left: axisWidth + (day - 1) * columnWidth,
                top: 0,
                width: columnWidth,
                height: headerHeight,
                child: Center(
                  child: Text(
                    '${weekdayNames[day - 1]}${weekStart == null ? '' : '\n${shortDate(DateTime.parse(weekStart!).add(Duration(days: day - 1)).toIso8601String())}'}',
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
            for (final course in courses)
              Positioned(
                left:
                    axisWidth +
                    (course.day - 1) * columnWidth +
                    (placements[course.id]?.lane ?? 0) *
                        columnWidth /
                        (placements[course.id]?.count ?? 1) +
                    3,
                top: headerHeight + (course.startSection - 1) * cellHeight + 2,
                width: columnWidth / (placements[course.id]?.count ?? 1) - 6,
                height:
                    (course.endSection - course.startSection + 1) * cellHeight -
                    4,
                child: _CourseBlock(
                  course: course,
                  onTap: () => onCourseTap(course),
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
      width: axisWidth,
      height: headerHeight + sectionCount * cellHeight,
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
          for (var section = 1; section <= sectionCount; section++)
            Positioned(
              left: 0,
              top: headerHeight + (section - 1) * cellHeight,
              width: axisWidth,
              height: cellHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${times[section] ?? '第$section节'}${times[section] == null ? '' : '\n第$section节'}',
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
          : axisWidth + columnWidth * 7 - viewportWidth;
      final first = (offset / columnWidth).floor().clamp(0, 6);
      final last =
          ((offset + viewportWidth - axisWidth) / columnWidth).ceil().clamp(
            1,
            7,
          ) -
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

  int? _todayColumn() {
    final start = DateTime.tryParse(weekStart ?? '');
    if (start == null) return null;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final date = DateTime(start.year, start.month, start.day);
    final diff = DateTime(now.year, now.month, now.day).difference(date).inDays;
    return diff >= 0 && diff < 7 ? diff + 1 : null;
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({required this.course, required this.onTap});
  final ScheduleCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = courseColor(context, course.color, course.name);
    return Semantics(
      button: true,
      label:
          '${course.name}，${weekdayNames[course.day - 1]}，${courseDetail(course)}',
      child: CupertinoButton(
        key: Key('schedule-grid-course-${course.id}'),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: SizedBox.expand(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 6, 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    course.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                if (course.startTime != null)
                  Text(
                    course.startTime!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                if (course.place != null)
                  Text(
                    course.place!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    final header = _ScheduleGridState.headerHeight;
    for (var row = 0; row <= _ScheduleGridState.sectionCount; row++) {
      final y = header + row * _ScheduleGridState.cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var column = 0; column <= 7; column++) {
      final x = _ScheduleGridState.axisWidth + column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.columnWidth != columnWidth ||
      oldDelegate.lineColor != lineColor;
}
