import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';

import 'schedule_style.dart';

/// Pastel iOS timetable block with a saturated top accent bar and room tag.
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
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final color = courseColor(context, course.color, course.name);
    final span = course.endSection - course.startSection + 1;
    final place = course.place?.trim() ?? '';
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GinkgoRadii.button),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: dark ? 0.26 : 0.14),
                borderRadius: BorderRadius.circular(GinkgoRadii.button),
                border: Border.all(
                  color: color.withValues(alpha: dark ? 0.42 : 0.25),
                  width: GinkgoSpacing.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 3, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GinkgoSpacing.xs,
                        GinkgoSpacing.xs,
                        GinkgoSpacing.xs,
                        GinkgoSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              maxLines: span >= 3 ? 5 : (span == 2 ? 3 : 2),
                              overflow: TextOverflow.ellipsis,
                              style: GinkgoTypography.caption.copyWith(
                                height: 1.18,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                          if (place.isNotEmpty)
                            Text(
                              '@$place',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GinkgoTypography.caption2.copyWith(
                                height: 1.12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
