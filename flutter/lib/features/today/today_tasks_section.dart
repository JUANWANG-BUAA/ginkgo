import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/features/today/today_action_row.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/features/today/today_presentation.dart';

class TodayTasksSnapshot {
  const TodayTasksSnapshot(this.items, this.loadedAt);
  final List<LocalTaskRecord> items;
  final DateTime loadedAt;
}

class TodayTasksSection extends StatelessWidget {
  const TodayTasksSection({
    super.key,
    required this.section,
    required this.now,
    required this.onRetry,
    required this.onOpen,
  });
  final RefreshSection<TodayTasksSnapshot> section;
  final DateTime now;
  final VoidCallback onRetry;
  final ValueChanged<String?> onOpen;

  @override
  Widget build(BuildContext context) {
    final data = section.value;
    final all = data?.items ?? <LocalTaskRecord>[];
    // Homework-derived to-dos are shown once, in the school-homework section.
    // They stay in the to-do list itself so nothing is deleted or edited here.
    final linked = all.where((task) => task.sourceAssignmentId != null).toList();
    final own = all.where((task) => task.sourceAssignmentId == null).toList();
    final pending = own.where((task) => !task.completed).toList();
    final completed = own.where((task) => task.completed).toList();
    final dated = pending.where((task) => todayDue(task.due) != null).toList()
      ..sort((a, b) => todayCompareDue(a.due, b.due));
    final undated = pending
        .where((task) => todayDue(task.due) == null)
        .toList();

    return TodayVisualSection(
      key: const Key('today-tasks'),
      header: TodaySectionHeader(
        icon: CupertinoIcons.checkmark_square_fill,
        title: '个人待办',
        badge: pending.isNotEmpty ? '${pending.length} 项未完成' : null,
        actionLabel: '全部',
        onAction: () => onOpen(null),
      ),
      footer: Text(
        data == null
            ? '仅保存于本机 · 不代表学校作业提交状态'
            : '本机读取：${data.loadedAt.month}月${data.loadedAt.day}日 ${data.loadedAt.hour.toString().padLeft(2, '0')}:${data.loadedAt.minute.toString().padLeft(2, '0')}\n本地完成不代表学校作业已提交${completed.isNotEmpty ? ' · 已完成 ${completed.length} 项（已收起）' : ''}',
      ),
      children: [
        if (section.loading || section.error != null)
          SectionFeedback(
            loading: section.loading,
            label: data == null ? '正在读取个人待办…' : '正在更新个人待办…',
            hasData: data != null,
            error: section.error,
            onRetry: onRetry,
          ),
        if (data != null) ...[
          TodayActionRow(
            key: const Key('today-open-tasks'),
            summary: true,
            title: pending.isEmpty
                ? (section.error != null
                    ? '待办状态尚未确认'
                    : '当前没有未完成待办')
                : '${pending.length} 项个人待办',
            subtitle: section.error != null
                ? '显示上次读取结果，请重试确认。'
                : '打开待办，继续安排自己的事项',
            onTap: () => onOpen(null),
          ),
          if (dated.isNotEmpty) ...[
            _row(context, dated.first, isPriority: true),
            for (final task in dated.skip(1).take(2)) _row(context, task),
          ],
          if (undated.isNotEmpty) ...[
            const TodayActionRow(title: '未设截止 / 时间待确认', caption: true),
            for (final (index, task) in undated.take(2).indexed)
              _row(context, task, isPriority: dated.isEmpty && index == 0),
          ],
          if (linked.isNotEmpty)
            TodayActionRow(
              key: const Key('today-tasks-linked-note'),
              summary: true,
              title: '另有 ${linked.length} 项来自学校作业',
              subtitle: '已在学校作业区显示，不在此重复；可在待办页查看',
              onTap: () => onOpen(null),
            ),
          if (completed.isNotEmpty)
            TodayActionRow(
              summary: true,
              title: '已完成 ${completed.length} 项',
              subtitle: '已收起，可在个人待办中查看',
            ),
        ],
        if (data == null && !section.loading)
          TodayActionRow(title: '打开个人待办', onTap: () => onOpen(null)),
      ],
    );
  }

  Widget _row(BuildContext context, LocalTaskRecord task, {bool isPriority = false}) {
    final status = _taskStatus(task);
    final tint = homeworkDeadlineTint(task.due, now).resolveFrom(context);
    return TodayActionRow(
      key: Key('today-task-${task.id}'),
      emphasized: isPriority,
      title: task.title,
      status: status,
      statusColor: task.due.trim().isEmpty ? null : tint,
      subtitle: '个人事项 · 未完成',
      onTap: () => onOpen(task.id),
    );
  }

  String _taskStatus(LocalTaskRecord task) {
    if (task.due.trim().isEmpty) return '无截止时间';
    return homeworkCompactDeadline(task.due, now);
  }
}
