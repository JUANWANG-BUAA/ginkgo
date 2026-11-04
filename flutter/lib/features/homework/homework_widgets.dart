import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'homework_projection.dart';

/// 作业状态筛选文案。取值与 [HomeworkPage] 的筛选器一一对应。
String homeworkFilterLabel(int value) => switch (value) {
  1 => '待完成',
  2 => '已提交',
  3 => '已截止',
  4 => '待确认',
  _ => '全部',
};

/// 状态快捷筛选按钮；再次点击同一项即回到「全部」。
class HomeworkQuickFilter extends StatelessWidget {
  const HomeworkQuickFilter({
    super.key,
    required this.value,
    required this.label,
    required this.tint,
    required this.selected,
    required this.onPressed,
  });

  final int value;
  final String label;
  final CupertinoDynamicColor tint;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    color: tint.resolveFrom(context).withValues(alpha: selected ? 0.2 : 0.08),
    minimumSize: const Size(48, 48),
    onPressed: onPressed,
    child: Text(
      label,
      style: TextStyle(fontSize: 14, color: tint.resolveFrom(context)),
    ),
  );
}

/// 作业状态徽标。已提交用成功色，已截止用危险色，待确认保留不确定色。
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
    final (label, color) = switch (status) {
      HomeworkStatus.submitted => (
        '已提交',
        AppleDesign.statusSuccess.resolveFrom(context),
      ),
      HomeworkStatus.pending =>
        isHomeworkOverdue(dueAt, clock)
            ? ('已截止', AppleDesign.statusDanger.resolveFrom(context))
            : ('待完成', AppleDesign.statusPending.resolveFrom(context)),
      HomeworkStatus.unknown => (
        '待确认',
        AppleDesign.statusUncertain.resolveFrom(context),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 单条作业的截止时间与倒计时描述。
///
/// 已提交的作业只保留日期作为历史记录：不再显示倒计时措辞，也不使用告警色。
class HomeworkDeadlineText extends StatelessWidget {
  const HomeworkDeadlineText({
    super.key,
    required this.item,
    required this.clock,
  });

  final HomeworkItem item;
  final DateTime clock;

  @override
  Widget build(BuildContext context) {
    final late =
        item.status == HomeworkStatus.pending &&
        isHomeworkOverdue(item.dueAt, clock);
    final relative = item.status == HomeworkStatus.submitted
        ? null
        : homeworkRelativeDeadline(item.dueAt, clock);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.dueAt == null
              ? (item.status == HomeworkStatus.submitted
                    ? '截止时间未提供'
                    : '截止时间未确认')
              : '截止 ${schoolTimestampLabel(item.dueAt)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: late
                ? AppleDesign.statusDanger.resolveFrom(context)
                : CupertinoColors.label.resolveFrom(context),
          ),
        ),
        if (relative != null)
          Text(
            relative,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: late
                  ? AppleDesign.statusDanger.resolveFrom(context)
                  : AppleDesign.statusPending.resolveFrom(context),
            ),
          ),
      ],
    );
  }
}

/// 作业列表项：标题、截止信息与课程；教师信息位于详情页。
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
  Widget build(BuildContext context) => AppleListTile(
    key: Key('homework-${item.id}'),
    onTap: onTap,
    trailing: const CupertinoListTileChevron(),
    title: Text(
      item.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.courseRole == 'assistant') const Text('助教课程 · 不代表个人待交作业'),
          Wrap(
            spacing: 10,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              HomeworkDeadlineText(item: item, clock: clock),
              HomeworkStatusBadge(
                status: item.status,
                dueAt: item.dueAt,
                clock: clock,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.courseName,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    ),
  );
}
