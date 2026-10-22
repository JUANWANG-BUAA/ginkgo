import 'package:flutter/cupertino.dart';

import 'application/local_tasks.dart';
import 'application/refresh_section.dart';
import 'loading_widgets.dart';
import 'today_action_row.dart';
import 'today_time.dart';
import 'today_presentation.dart';

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
    final pending =
        data?.items.where((task) => !task.completed).toList() ??
        <LocalTaskRecord>[];
    final dated = pending.where((task) => todayDue(task.due) != null).toList()
      ..sort((a, b) => todayCompareDue(a.due, b.due));
    final undated = pending
        .where((task) => todayDue(task.due) == null)
        .toList();
    return TodayVisualSection(
      key: const Key('today-tasks'),
      header: const Text('个人待办'),
      footer: Text(
        data == null
            ? '仅保存于本机 · 不代表学校作业提交状态'
            : '本机读取：${data.loadedAt.month}月${data.loadedAt.day}日 ${data.loadedAt.hour.toString().padLeft(2, '0')}:${data.loadedAt.minute.toString().padLeft(2, '0')}\n本地完成不代表学校作业已提交',
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
                ? section.error != null
                      ? '待办状态尚未确认'
                      : '当前没有未完成待办'
                : '${pending.length} 项个人待办',
            subtitle: section.error != null
                ? '显示上次读取结果，请重试确认。'
                : '打开待办，继续安排自己的事项',
            onTap: () => onOpen(null),
          ),
          for (final task in dated.take(3)) _row(task),
          if (undated.isNotEmpty) ...[
            const TodayActionRow(title: '未设截止 / 时间待确认', caption: true),
            for (final task in undated.take(2)) _row(task),
          ],
          if (data.items.any((task) => task.completed))
            TodayActionRow(
              summary: true,
              title:
                  '已完成 ${data.items.where((task) => task.completed).length} 项',
              subtitle: '已收起，可在个人待办中查看',
            ),
        ],
        if (data == null && !section.loading)
          TodayActionRow(title: '打开个人待办', onTap: () => onOpen(null)),
      ],
    );
  }

  Widget _row(LocalTaskRecord task) => TodayActionRow(
    key: Key('today-task-${task.id}'),
    title: task.title,
    status: todayDueLabel(task.due, now, localTask: true),
    subtitle: task.sourceAssignmentId == null
        ? '个人事项 · 未完成'
        : '来源：学校作业 · 本地未完成',
    onTap: () => onOpen(task.id),
  );
}
