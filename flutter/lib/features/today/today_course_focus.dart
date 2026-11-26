import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/checkin_visibility.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/press_feedback.dart';

import 'today_action_row.dart';
import 'today_presentation.dart';

/// Presentation-only interpretation of the existing Today clock range.
/// Invalid/absent clocks are unknown, never silently midnight.
class TodayCourseWindow {
  const TodayCourseWindow(this.starts, this.ends);
  final DateTime starts, ends;

  static TodayCourseWindow? parse(String date, String? time) {
    final day = todayDate(date);
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*[-–—~～]\s*(\d{1,2}):(\d{2})$')
        .firstMatch(time?.trim() ?? '');
    if (day == null || match == null) return null;
    final parts = [for (var i = 1; i <= 4; i++) int.parse(match[i]!)];
    if (parts[0] > 23 || parts[2] > 23 || parts[1] > 59 || parts[3] > 59) {
      return null;
    }
    final start = day.add(Duration(hours: parts[0], minutes: parts[1]));
    var end = day.add(Duration(hours: parts[2], minutes: parts[3]));
    if (end == start) return null;
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    return TodayCourseWindow(start, end);
  }

  String status(DateTime now) => now.isBefore(starts)
      ? '尚未开始'
      : now.isBefore(ends)
      ? '正在上课'
      : '已结束';
}

class TodayCourseFocus extends StatelessWidget {
  const TodayCourseFocus({
    super.key,
    required this.data,
    required this.now,
    this.onOpen,
    this.stale = false,
    this.checkinCourses = const [],
    this.onOpenCheckIn,
  });
  final TodayResponse data;
  final DateTime now;
  final VoidCallback? onOpen;
  final bool stale;
  final List<CheckInCourse> checkinCourses;
  final VoidCallback? onOpenCheckIn;

  static String _clock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final dated = todayDate(data.date);
    if (dated == null || DateTime.utc(now.year, now.month, now.day) != dated) {
      return TodayActionRow(
        title: '请确认今天的课表',
        subtitle: '当前数据日期：${data.date}，刷新后再确认安排。',
        status: '课表日期待更新',
        onTap: onOpen,
      );
    }
    final known = <(TodayCourse, TodayCourseWindow)>[];
    for (final course in data.courses) {
      final window = TodayCourseWindow.parse(data.date, course.time);
      if (window != null) known.add((course, window));
    }
    known.sort((a, b) => a.$2.starts.compareTo(b.$2.starts));
    final ongoing = known.where(
      (e) => !now.isBefore(e.$2.starts) && now.isBefore(e.$2.ends),
    );
    final future = known.where((e) => now.isBefore(e.$2.starts));
    final focus = ongoing.isNotEmpty
        ? ongoing.first
        : future.isNotEmpty
        ? future.first
        : null;
    if (focus == null) {
      final unknown = known.length != data.courses.length;
      return TodayActionRow(
        title: unknown ? '部分课程时间待确认' : '今天的课程已结束',
        subtitle: unknown ? '请查看下方课程或完整课表，不据此判断空闲。' : '可以安排自己的学习与休息。',
        status: stale ? '上次课表 · 请刷新确认' : '接下来',
        onTap: onOpen,
      );
    }
    final (course, window) = focus;
    final running = !now.isBefore(window.starts);
    final minutes =
        ((running ? window.ends : window.starts).difference(now).inSeconds / 60)
            .ceil();
    final matchedCheckIn = matchCheckInForTodayCourse(course, checkinCourses);
    final accent = running
        ? AppleDesign.statusSuccess.resolveFrom(context)
        : CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final statusText =
        '${stale ? '上次课表 · ' : ''}${running ? '正在上课 · 约 $minutes 分钟后结束' : '下一节课 · $minutes 分钟后开始'}';

    final timeBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _clock(window.starts),
          style: GinkgoTypography.headline.copyWith(
            fontWeight: FontWeight.w700,
            color: running ? accent : labelColor,
            fontFeatures: GinkgoTypography.tabularDigits,
          ),
        ),
        const SizedBox(height: GinkgoSpacing.xs),
        Text(
          _clock(window.ends),
          style: GinkgoTypography.caption.copyWith(
            color: secondary,
            fontFeatures: GinkgoTypography.tabularDigits,
          ),
        ),
      ],
    );

    final detailsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: GinkgoSpacing.sm,
          runSpacing: GinkgoSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              statusText,
              style: GinkgoTypography.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            if (matchedCheckIn != null)
              _InlineCheckInPill(
                course: matchedCheckIn,
                onTap: onOpenCheckIn,
              ),
          ],
        ),
        const SizedBox(height: GinkgoSpacing.sm),
        Text(
          course.name,
          maxLines: MediaQuery.textScalerOf(context).scale(17) > 24 ? null : 2,
          overflow: TextOverflow.ellipsis,
          style: GinkgoTypography.headline.copyWith(
            fontSize: GinkgoTypography.focusTitleSize,
            fontWeight: FontWeight.w600,
            color: labelColor,
            height: 1.25,
          ),
        ),
        const SizedBox(height: GinkgoSpacing.small),
        Row(
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: GinkgoIconTokens.glyphXs,
              color: secondary,
            ),
            const SizedBox(width: GinkgoSpacing.xs),
            Expanded(
              child: Text(
                todayCoursePlaceLabel(course.place),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GinkgoTypography.footnote.copyWith(color: secondary),
              ),
            ),
          ],
        ),
      ],
    );

    final cardBody = LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        return Padding(
          padding: GinkgoSpacing.edgeInsetsFocusRow,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!stacked) ...[
                  SizedBox(
                    width: GinkgoSurfaceTokens.timelineWidth,
                    child: timeBlock,
                  ),
                  const SizedBox(width: GinkgoSpacing.sm),
                ],
                Container(
                  width: GinkgoSurfaceTokens.accentStripeWidth,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(
                      GinkgoSurfaceTokens.accentStripeRadius,
                    ),
                  ),
                ),
                const SizedBox(width: GinkgoSpacing.md),
                Expanded(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_clock(window.starts)}–${_clock(window.ends)}',
                              style: GinkgoTypography.footnote.copyWith(
                                fontWeight: FontWeight.w600,
                                color: running ? accent : secondary,
                                fontFeatures: GinkgoTypography.tabularDigits,
                              ),
                            ),
                            const SizedBox(height: GinkgoSpacing.small),
                            detailsBlock,
                          ],
                        )
                      : detailsBlock,
                ),
                if (onOpen != null) ...[
                  const SizedBox(width: GinkgoSpacing.sm),
                  const Center(
                    child: ExcludeSemantics(child: CupertinoListTileChevron()),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    return MergeSemantics(
      key: const Key('today-course-focus'),
      child: Semantics(
        button: onOpen != null,
        enabled: onOpen == null ? null : true,
        hint: onOpen == null ? null : '打开详情',
        child: onOpen == null
            ? cardBody
            : PressFeedback(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: GinkgoButtonTokens.minTarget,
                  onPressed: onOpen,
                  child: cardBody,
                ),
              ),
      ),
    );
  }
}

class _InlineCheckInPill extends StatelessWidget {
  const _InlineCheckInPill({required this.course, this.onTap});

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
        '未签到 · 去签到',
        CupertinoIcons.qrcode,
        AppleDesign.statusPending.resolveFrom(context),
      ),
      CheckInStatus.unknown => (
        '签到待确认',
        CupertinoIcons.question_circle_fill,
        AppleDesign.statusUncertain.resolveFrom(context),
      ),
    };
    final badge = GinkgoBadge(
      key: Key('today-checkin-${course.id}'),
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
