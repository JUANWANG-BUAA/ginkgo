import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_style.dart';

/// Quiet secondary text used across the schedule surface.
TextStyle scheduleSecondary(BuildContext context) => TextStyle(
  fontSize: 14,
  color: CupertinoColors.secondaryLabel.resolveFrom(context),
);

/// One course in the day list. Large type stacks the time above the content;
/// otherwise a color spine separates a fixed-width time column.
class ScheduleCourseRow extends StatelessWidget {
  const ScheduleCourseRow({super.key, required this.course, this.onTap});
  final ScheduleCourse course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.startTime ?? '时间待定',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (course.endTime != null)
          Text(
            course.endTime!,
            style: scheduleSecondary(context).copyWith(fontSize: 13),
          ),
        const SizedBox(height: 5),
        Text(
          '第${course.startSection}–${course.endSection}节',
          style: scheduleSecondary(context).copyWith(fontSize: 12),
        ),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(course.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (course.place?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(course.place!, style: scheduleSecondary(context)),
          ),
        if (course.teacher?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(course.teacher!, style: scheduleSecondary(context)),
          ),
      ],
    );
    return CupertinoButton(
      key: Key('schedule-course-${course.id}'),
      padding: const EdgeInsets.all(16),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style
                  .copyWith(color: CupertinoColors.label.resolveFrom(context)),
              child: large
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [time, const SizedBox(height: 12), content],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 78, child: time),
                        Container(
                          width: 4,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: courseColor(
                              context,
                              course.color,
                              course.name,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 14,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
        ],
      ),
    );
  }
}

/// One label/value line in the pushed course detail page.
class ScheduleDetailLine extends StatelessWidget {
  const ScheduleDetailLine({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: scheduleSecondary(context)),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    ),
  );
}
