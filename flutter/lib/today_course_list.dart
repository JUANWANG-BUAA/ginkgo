import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'application/contracts.dart';

/// Keep course times on a visible axis, like the native Today views. At large
/// type sizes the axis moves above the title so neither field is squeezed.
class TodayCourseRow extends StatelessWidget {
  const TodayCourseRow({super.key, required this.course, required this.status});
  final TodayCourse course;
  final String status;

  @override
  Widget build(BuildContext context) {
    final times = RegExp(r'^(\d{1,2}:\d{2})\s*[-–—~～]\s*(\d{1,2}:\d{2})$')
        .firstMatch(course.time?.trim() ?? '');
    final secondary = AppleDesign.statusInactive.resolveFrom(context);
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          times?.group(1) ?? course.time ?? '时间未提供',
          style: TextStyle(
            fontSize: times == null ? 13 : 17,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (times != null)
          Text(
            times.group(2)!,
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontFeatures: GinkgoTypography.tabularDigits,
            ),
          ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status, style: TextStyle(fontSize: 13, color: secondary)),
        const SizedBox(height: 4),
        Text(
          course.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 5),
        Text(
          course.place?.trim().isNotEmpty == true ? course.place! : '地点未提供',
          style: TextStyle(fontSize: 13, color: secondary),
        ),
      ],
    );
    return Padding(
      padding: GinkgoSpacing.edgeInsetsCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: CupertinoColors.separator.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stacked)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [time, const SizedBox(height: 8), details],
                        ),
                      )
                    else ...[
                      SizedBox(width: 84, child: time),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Empty / unconfirmed course state. Large type stacks the identity above the
/// explanation; both keep the schedule entry point when provided.
class TodayCourseEmpty extends StatelessWidget {
  const TodayCourseEmpty({
    super.key,
    required this.error,
    required this.onOpenSchedule,
  });

  final String? error;
  final VoidCallback? onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    if (isLargeText) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      error != null
                          ? CupertinoIcons.exclamationmark_triangle_fill
                          : CupertinoIcons.calendar,
                      size: 18,
                      color: error != null
                          ? AppleDesign.statusDanger.resolveFrom(context)
                          : accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error != null ? '今日课程尚未确认' : '今天没有课程',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              error != null
                  ? '课表更新失败，请刷新后再确认今天的安排。'
                  : '当前课表中没有当天课程，可查看完整课表安排学习。',
              style: TextStyle(
                fontSize: 13,
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
            ),
            if (onOpenSchedule != null) ...[
              const SizedBox(height: 10),
              _openScheduleButton(context, accent),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                error != null
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.calendar,
                size: 22,
                color: error != null
                    ? AppleDesign.statusDanger.resolveFrom(context)
                    : accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error != null ? '今日课程尚未确认' : '今天没有课程',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  error != null
                      ? '课表更新失败，请刷新后再确认今天的安排。'
                      : '当前课表中没有当天课程，可查看完整课表安排学习。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppleDesign.statusInactive.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          if (onOpenSchedule != null) ...[
            const SizedBox(width: 8),
            _openScheduleButton(context, accent),
          ],
        ],
      ),
    );
  }

  Widget _openScheduleButton(BuildContext context, Color accent) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: accent.withValues(
          alpha: CupertinoTheme.of(context).brightness == Brightness.dark
              ? 0.18
              : 0.10,
        ),
        borderRadius: BorderRadius.circular(8),
        minimumSize: const Size(48, 32),
        onPressed: onOpenSchedule,
        child: Text(
          '查看完整课表',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
      );
}
