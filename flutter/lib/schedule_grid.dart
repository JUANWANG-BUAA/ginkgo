import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'schedule_style.dart';
import 'src/rust/api/mirror.dart';

/// Seven-day timetable grid. Course blocks span their section range and open
/// a course detail page on tap.
class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.onCourseTap,
    this.weekStart,
  });
  final List<ScheduleCourse> courses;
  final String? weekStart;
  final ValueChanged<ScheduleCourse> onCourseTap;

  static const double axisWidth = 30;
  static const double headerHeight = 48;
  static const int sectionCount = 14;
  static const double cellHeight = 52;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columnWidth = math.max(
        64.0,
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
                      '$section',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final course in courses)
              Positioned(
                left: axisWidth + (course.day - 1) * columnWidth + 2,
                top: headerHeight + (course.startSection - 1) * cellHeight + 2,
                width: columnWidth - 4,
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
          : SingleChildScrollView(
              key: const Key('schedule-grid-horizontal'),
              scrollDirection: Axis.horizontal,
              child: grid,
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
    final color = courseColor(context, course.color);
    return Semantics(
      button: true,
      label:
          '${course.name}，${weekdayNames[course.day - 1]}，${courseDetail(course)}',
      child: GestureDetector(
        key: Key('schedule-grid-course-${course.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 4, 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
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
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              if (course.place != null)
                Text(
                  course.place!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
            ],
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
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final header = ScheduleGrid.headerHeight;
    for (var row = 0; row <= ScheduleGrid.sectionCount; row++) {
      final y = header + row * ScheduleGrid.cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var column = 0; column <= 7; column++) {
      final x = ScheduleGrid.axisWidth + column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.columnWidth != columnWidth ||
      oldDelegate.lineColor != lineColor;
}
