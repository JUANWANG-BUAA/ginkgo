import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';

import 'schedule_style.dart';

/// One course block inside the timetable grid.
///
/// The block spans its section range and opens the course detail page on tap.
class ScheduleGridCourseBlock extends StatelessWidget {
  const ScheduleGridCourseBlock({
    super.key,
    required this.course,
    required this.onTap,
  });
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
