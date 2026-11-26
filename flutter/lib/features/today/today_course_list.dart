import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

import 'today_presentation.dart';

/// Keep course times on a visible axis, like the native Today views. At large
/// type sizes the axis moves above the title so neither field is squeezed.
class TodayCourseRow extends StatelessWidget {
  const TodayCourseRow({
    super.key,
    required this.course,
    required this.status,
    this.checkin,
    this.onOpenCheckIn,
  });
  final TodayCourse course;
  final String status;
  final CheckInCourse? checkin;
  final VoidCallback? onOpenCheckIn;

  @override
  Widget build(BuildContext context) {
    final times = RegExp(r'^(\d{1,2}:\d{2})\s*[-–—~～]\s*(\d{1,2}:\d{2})$')
        .firstMatch(course.time?.trim() ?? '');
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final isRunning = status == '正在上课';
    final stripeColor = isRunning
        ? AppleDesign.statusSuccess.resolveFrom(context)
        : CupertinoColors.separator.resolveFrom(context);
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          times?.group(1) ?? course.time ?? '时间未提供',
          style:
              (times == null
                      ? GinkgoTypography.footnote
                      : GinkgoTypography.body)
                  .copyWith(
                    fontWeight: FontWeight.w600,
                    color: isRunning
                        ? stripeColor
                        : CupertinoColors.label.resolveFrom(context),
                    fontFeatures: GinkgoTypography.tabularDigits,
                  ),
        ),
        if (times != null)
          Text(
            times.group(2)!,
            style: GinkgoTypography.footnote.copyWith(
              color: secondary,
              fontFeatures: GinkgoTypography.tabularDigits,
            ),
          ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: GinkgoSpacing.sm,
          runSpacing: GinkgoSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              status,
              style: GinkgoTypography.footnote.copyWith(
                color: isRunning ? stripeColor : secondary,
                fontWeight: isRunning ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (checkin != null) _CourseRowCheckInChip(
              course: checkin!,
              onTap: onOpenCheckIn,
            ),
          ],
        ),
        const SizedBox(height: GinkgoSpacing.xs),
        Text(
          course.name,
          style: GinkgoTypography.body.copyWith(
            color: CupertinoColors.label.resolveFrom(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: GinkgoSpacing.compact),
        Text(
          todayCoursePlaceLabel(course.place),
          style: GinkgoTypography.footnote.copyWith(color: secondary),
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
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: GinkgoSurfaceTokens.accentStripeWidth,
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: BorderRadius.circular(
                      GinkgoSurfaceTokens.accentStripeRadius,
                    ),
                  ),
                ),
                const SizedBox(width: GinkgoSpacing.md),
                if (stacked)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        time,
                        const SizedBox(height: GinkgoSpacing.sm),
                        details,
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    width: GinkgoSurfaceTokens.timelineWidth,
                    child: time,
                  ),
                  const SizedBox(width: GinkgoSpacing.md),
                  Expanded(child: details),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CourseRowCheckInChip extends StatelessWidget {
  const _CourseRowCheckInChip({required this.course, this.onTap});

  final CheckInCourse course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (course.status) {
      CheckInStatus.signed => (
        '已签到',
        CupertinoIcons.checkmark_circle_fill,
        AppleDesign.statusSuccess.resolveFrom(context),
      ),
      CheckInStatus.notSigned => (
        '未签到',
        CupertinoIcons.qrcode,
        AppleDesign.statusPending.resolveFrom(context),
      ),
      CheckInStatus.unknown => (
        '待确认',
        CupertinoIcons.question_circle_fill,
        AppleDesign.statusUncertain.resolveFrom(context),
      ),
    };
    final badge = GinkgoBadge(
      label: label,
      icon: icon,
      color: color,
      compact: true,
    );
    if (onTap == null || course.status == CheckInStatus.signed) return badge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: badge,
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
    final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final failed = error != null;
    final title = failed ? '今日课程尚未确认' : '今天没有课程';
    final description = failed
        ? '课表更新失败，请刷新后再确认今天的安排。'
        : '当前课表中没有当天课程，可查看完整课表安排学习。';
    final badge = TodayCourseEmptyBadge(
      icon: failed
          ? CupertinoIcons.exclamationmark_triangle_fill
          : CupertinoIcons.calendar,
      accent: accent,
      failed: failed,
      size: isLargeText ? 36 : 44,
      iconSize: isLargeText ? 18 : 22,
      radius: isLargeText ? 10 : 12,
    );

    if (isLargeText) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                badge,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppleDesign.bodyCondensedSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
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
          badge,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppleDesign.bodyCondensedSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: accent.withValues(
          alpha: CupertinoTheme.of(context).brightness == Brightness.dark
              ? 0.18
              : 0.10,
        ),
        borderRadius: BorderRadius.circular(8),
        minimumSize: const Size(48, 48),
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

/// The icon tile that marks an empty or unconfirmed course list.
class TodayCourseEmptyBadge extends StatelessWidget {
  const TodayCourseEmptyBadge({
    super.key,
    required this.icon,
    required this.accent,
    required this.failed,
    required this.size,
    required this.iconSize,
    required this.radius,
  });

  final IconData icon;
  final Color accent;
  final bool failed;
  final double size, iconSize, radius;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: failed
              ? AppleDesign.statusDanger.resolveFrom(context)
              : accent,
        ),
      ),
    );
  }
}
