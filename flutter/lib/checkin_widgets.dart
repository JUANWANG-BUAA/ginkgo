import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'school_timestamp.dart';
import 'application/contracts.dart';

/// One course with its sign-in status, merged-record notes and the single
/// confirmed submission button. The button never offers an unconfirmed retry.
class CheckinCourseRow extends StatelessWidget {
  const CheckinCourseRow({
    super.key,
    required this.course,
    required this.windowOpen,
    required this.canSubmit,
    required this.submitting,
    required this.awaitingVerification,
    required this.onSubmit,
  });
  final CheckInCourse course;
  final bool windowOpen;

  /// Whether this course is eligible for sign-in at all (not history, status
  /// and record rules). The button stays visible while a write is in flight.
  final bool canSubmit;
  final String? submitting;
  final bool awaitingVerification;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final (icon, semanticColor, label) = switch (course.status) {
      CheckInStatus.signed => (
        CupertinoIcons.checkmark_circle_fill,
        AppleDesign.statusSuccess,
        '已签到',
      ),
      CheckInStatus.notSigned => (
        CupertinoIcons.circle,
        AppleDesign.statusInactive,
        '未签到',
      ),
      CheckInStatus.unknown => (
        CupertinoIcons.question_circle_fill,
        AppleDesign.statusUncertain,
        '待确认',
      ),
    };
    final color = semanticColor.resolveFrom(context);
    final details = [
      schoolTimeRange(course.beginsAt, course.endsAt),
      if (course.classroomName != null) course.classroomName!,
      if (course.teacherName != null) course.teacherName!,
    ];
    final isSubmitting = submitting == course.id;
    return Padding(
      key: Key('checkin-course-${course.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, size: 25, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  course.courseName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            details.join(' · '),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (course.mergedRecordCount > 1)
                Text(
                  '合并 ${course.mergedRecordCount} 条',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              if (course.conflicting || course.signInAllowed == false)
                const Text(
                  '记录不一致',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppleDesign.statusPending,
                  ),
                ),
              if (canSubmit)
                CupertinoButton.tinted(
                  key: Key('checkin-submit-${course.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  onPressed: submitting != null ? null : onSubmit,
                  child: isSubmitting
                      ? const GinkgoActivity(size: 17)
                      : Text(
                          awaitingVerification
                              ? '待核实'
                              : windowOpen
                              ? '签到'
                              : '课前 10 分钟开放',
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Day totals: count tile, proportional status meter and readable legend.
/// The meter repeats the legend in semantics so TalkBack reads exact counts.
class CheckinStatusSummary extends StatelessWidget {
  const CheckinStatusSummary({
    super.key,
    required this.dateLabel,
    required this.scopeLabel,
    required this.signed,
    required this.notSigned,
    required this.unknown,
    required this.fetchedAt,
  });

  final String dateLabel;
  final String scopeLabel;
  final int signed, notSigned, unknown;
  final String? fetchedAt;

  @override
  Widget build(BuildContext context) {
    return AppleSection(
      header: Text(dateLabel),
      children: [
        AppleListTile(
          title: Text(scopeLabel),
          subtitle: Text(
            [
              '已签到 $signed',
              '未签到 $notSigned',
              if (unknown > 0) '待确认 $unknown',
            ].join(' · '),
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          additionalInfo: Text(
            '核对 ${schoolClockLabel(fetchedAt)}',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '当天签到状态分布',
                value: '已签到 $signed，未签到 $notSigned，待确认 $unknown',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: SizedBox(
                      key: const Key('checkin-status-meter'),
                      height: 8,
                      child: Row(
                        children: [
                          if (signed > 0)
                            Expanded(
                              flex: signed,
                              child: ColoredBox(
                                color: AppleDesign.statusSuccess.resolveFrom(
                                  context,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          if (notSigned > 0)
                            Expanded(
                              flex: notSigned,
                              child: ColoredBox(
                                color: AppleDesign.statusPending.resolveFrom(
                                  context,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          if (unknown > 0)
                            Expanded(
                              flex: unknown,
                              child: ColoredBox(
                                color: AppleDesign.statusUncertain.resolveFrom(
                                  context,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _countLegend(
                    context,
                    '已签',
                    signed,
                    AppleDesign.statusSuccess,
                  ),
                  _countLegend(
                    context,
                    '待签',
                    notSigned,
                    AppleDesign.statusPending,
                  ),
                  if (unknown > 0)
                    _countLegend(
                      context,
                      '待核实',
                      unknown,
                      AppleDesign.statusUncertain,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _countLegend(
    BuildContext context,
    String title,
    int count,
    CupertinoDynamicColor color,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color.resolveFrom(context),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '$title $count',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    ],
  );
}
