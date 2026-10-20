import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'schedule_style.dart';
import 'src/rust/api/mirror.dart';

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
          ? grid
          : CupertinoScrollbar(
              controller: horizontalScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: const Key('schedule-grid-horizontal'),
                controller: horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: grid,
              ),
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
