import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

import 'homework_projection.dart';

/// 作业状态筛选文案。取值与 [HomeworkPage] 的筛选器一一对应。
String homeworkFilterLabel(int value) => switch (value) {
  0 => '待提交',
  1 => '已提交',
  2 => '已截止',
  4 => '待确认',
  _ => '全部',
};

/// 作业状态徽标。统一复用 [GinkgoBadge]（图标 + 颜色 + 文案）。
class HomeworkStatusBadge extends StatelessWidget {
  const HomeworkStatusBadge({
    super.key,
    required this.status,
    required this.dueAt,
    required this.clock,
  });

  final HomeworkStatus status;
  final String? dueAt;
  final DateTime clock;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      HomeworkStatus.submitted => (
        '已提交',
        CupertinoIcons.check_mark_circled_solid,
        AppleDesign.statusSuccess,
      ),
      HomeworkStatus.pending =>
        isHomeworkOverdue(dueAt, clock)
            ? (
                '已截止',
                CupertinoIcons.exclamationmark_circle_fill,
                AppleDesign.statusDanger,
              )
            : (
                homeworkCountdownBadge(dueAt, clock),
                CupertinoIcons.clock_fill,
                homeworkDeadlineTint(dueAt, clock),
              ),
      HomeworkStatus.unknown => (
        '待确认',
        CupertinoIcons.question_circle_fill,
        AppleDesign.statusUncertain,
      ),
    };
    return GinkgoBadge(
      label: label,
      icon: icon,
      color: color.resolveFrom(context),
      compact: true,
    );
  }
}

/// 作业列表项：采用统一渐进式卡片层级（状态/倒计时徽标 + 标题 + 课程与截止时间）。
class HomeworkItemTile extends StatelessWidget {
  const HomeworkItemTile({
    super.key,
    required this.item,
    required this.clock,
    required this.onTap,
  });

  final HomeworkItem item;
  final DateTime clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSubmitted = item.status == HomeworkStatus.submitted;
    final isOverdue =
        item.status == HomeworkStatus.pending &&
        isHomeworkOverdue(item.dueAt, clock);
    final accent = isSubmitted
        ? AppleDesign.statusSuccess
        : isOverdue
        ? AppleDesign.statusDanger
        : item.status == HomeworkStatus.unknown
        ? AppleDesign.statusUncertain
        : homeworkDeadlineTint(item.dueAt, clock);
    final dueLabel = item.dueAt == null
        ? (isSubmitted ? null : '截止时间未确认')
        : '截止 ${schoolTimestampLabel(item.dueAt)}';
    final badgeLabel = switch (item.status) {
      HomeworkStatus.submitted => '已提交',
      HomeworkStatus.pending =>
        isOverdue ? '已截止' : homeworkCountdownBadge(item.dueAt, clock),
      HomeworkStatus.unknown => '待确认',
    };
    final badgeIcon = switch (item.status) {
      HomeworkStatus.submitted => CupertinoIcons.check_mark_circled_solid,
      HomeworkStatus.pending =>
        isOverdue
            ? CupertinoIcons.exclamationmark_circle_fill
            : CupertinoIcons.clock_fill,
      HomeworkStatus.unknown => CupertinoIcons.question_circle_fill,
    };
    final roleBadge = isNonStudentCourseRole(item.courseRole)
        ? GinkgoBadge(
            label: item.courseRole == 'teacher'
                ? '教师课程 · 不代表个人待交作业'
                : '助教课程 · 不代表个人待交作业',
            icon: CupertinoIcons.person_2_fill,
            color: GinkgoColors.resourcePurple,
            compact: true,
          )
        : null;
    return GinkgoProgressiveRow(
      key: Key('homework-${item.id}'),
      title: item.title,
      subtitle: item.courseName,
      badgeLabel: badgeLabel,
      badgeIcon: badgeIcon,
      extraBadges: [?roleBadge],
      meta: item.dueAt?.trim().isNotEmpty == true ? dueLabel : null,
      accent: accent,
      onTap: onTap,
    );
  }
}
