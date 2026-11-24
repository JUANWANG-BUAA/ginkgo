import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/academic_widgets.dart';
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

/// iOS Calendar-style course row in the daily schedule list.
class ScheduleCourseRow extends StatelessWidget {
  const ScheduleCourseRow({super.key, required this.course, this.onTap});
  final ScheduleCourse course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final accent = courseColor(context, course.color, course.name);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final sectionPill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GinkgoSpacing.small,
        vertical: GinkgoSpacing.opticalIconInset,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GinkgoRadii.badge),
      ),
      child: Text(
        '${course.startSection}–${course.endSection}节',
        maxLines: 1,
        style: GinkgoTypography.caption2.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: GinkgoTypography.tabularDigits,
          color: accent,
        ),
      ),
    );

    final timeColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.startTime ?? '时间待定',
          style: GinkgoTypography.headline.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: GinkgoTypography.tabularDigits,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        if (course.endTime != null) ...[
          const SizedBox(height: GinkgoSpacing.opticalIconInset),
          Text(
            course.endTime!,
            style: GinkgoTypography.caption.copyWith(
              fontFeatures: GinkgoTypography.tabularDigits,
              color: secondary,
            ),
          ),
        ],
        const SizedBox(height: GinkgoSpacing.xs),
        sectionPill,
      ],
    );

    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.name,
          style: GinkgoTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        if (course.place?.isNotEmpty == true) ...[
          const SizedBox(height: GinkgoSpacing.xs),
          Row(
            children: [
              Icon(CupertinoIcons.placemark_fill, size: 13, color: accent),
              const SizedBox(width: GinkgoSpacing.xs),
              Expanded(
                child: Text(
                  course.place!,
                  maxLines: large ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinkgoTypography.subheadline.copyWith(
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (course.teacher?.isNotEmpty == true) ...[
          const SizedBox(height: GinkgoSpacing.xs),
          Row(
            children: [
              Icon(CupertinoIcons.person_2, size: 13, color: secondary),
              const SizedBox(width: GinkgoSpacing.xs),
              Expanded(
                child: Text(
                  course.teacher!,
                  maxLines: large ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinkgoTypography.footnote.copyWith(color: secondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return CupertinoButton(
      key: Key('schedule-course-${course.id}'),
      padding: GinkgoSpacing.edgeInsetsFocusRow,
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style.copyWith(
                color: CupertinoColors.label.resolveFrom(context),
              ),
              child: large
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        timeColumn,
                        const SizedBox(height: GinkgoSpacing.sm),
                        contentColumn,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 72, child: timeColumn),
                        const SizedBox(width: GinkgoSpacing.sm),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: accent, width: 3.5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: GinkgoSpacing.md,
                              ),
                              child: contentColumn,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: GinkgoSpacing.sm),
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
  Widget build(BuildContext context) =>
      AcademicFactRow(label: label, value: value);
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
    padding: GinkgoSpacing.edgeInsetsListTile,
    minimumSize: const Size(48, 48),
    onPressed: onTap,
    child: Row(
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
              color: CupertinoColors.label.resolveFrom(context),
            ),
            child: child,
          ),
        ),
        const SizedBox(width: GinkgoSpacing.sm),
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

/// A section that reports the first load of a snapshot.
class ScheduleLoadingSection extends StatelessWidget {
  const ScheduleLoadingSection({super.key, this.label = '正在读取课表…'});
  final String label;

  @override
  Widget build(BuildContext context) =>
      AppleSection(children: [GinkgoLoadingView(label: label)]);
}
