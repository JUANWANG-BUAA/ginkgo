import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'schedule_style.dart';

/// How the schedule page presents the confirmed snapshot.
///
/// The week grid and the day list show the same courses; large type always
/// falls back to the day list, so the grid is only offered while it stays
/// legible.
enum ScheduleViewMode {
  /// One timetable grid for the whole week.
  weekGrid,

  /// One list per weekday.
  dayList,

  /// The teaching weeks of the term.
  semester,

  /// The exam schedule of the term.
  exam,
}

/// Short label of a view mode.
String scheduleViewModeLabel(ScheduleViewMode mode) => switch (mode) {
  ScheduleViewMode.weekGrid => '周课表',
  ScheduleViewMode.dayList => '每日清单',
  ScheduleViewMode.semester => '学期',
  ScheduleViewMode.exam => '考试',
};

/// Label of a view mode in the large-text picker, where the grid hint has to
/// be spelled out because the segmented control is replaced.
String scheduleViewModeDescription(ScheduleViewMode mode) => switch (mode) {
  ScheduleViewMode.weekGrid => '周课表 · 大字号使用每日清单',
  ScheduleViewMode.dayList => '每日清单',
  ScheduleViewMode.semester => '学期',
  ScheduleViewMode.exam => '考试',
};

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

/// A tappable row that reveals the next screen, with a trailing chevron.
class ScheduleChevronRow extends StatelessWidget {
  const ScheduleChevronRow({
    super.key,
    required this.child,
    required this.onTap,
  });
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    minimumSize: const Size(48, 48),
    onPressed: onTap,
    child: Row(
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style
                .copyWith(color: CupertinoColors.label.resolveFrom(context)),
            child: child,
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

/// A group of rows under an optional section title.
class ScheduleSection extends StatelessWidget {
  const ScheduleSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });
  final String? title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: title == null ? null : Text(title!),
    footer: footer,
    children: children,
  );
}

/// A section that reports an empty or failed result.
class ScheduleEmptySection extends StatelessWidget {
  const ScheduleEmptySection({
    super.key,
    required this.title,
    required this.description,
    this.action,
    this.onAction,
    this.error = false,
  });
  final String title;
  final String description;
  final String? action;
  final VoidCallback? onAction;
  final bool error;

  @override
  Widget build(BuildContext context) => AppleSection(
    children: [
      AppleEmptyState(
        title: title,
        description: description,
        action: action,
        onAction: onAction,
        error: error,
      ),
    ],
  );
}

/// A section that reports the first load of a snapshot.
class ScheduleLoadingSection extends StatelessWidget {
  const ScheduleLoadingSection({super.key, this.label = '正在读取课表…'});
  final String label;

  @override
  Widget build(BuildContext context) =>
      AppleSection(children: [GinkgoLoadingView(label: label)]);
}
