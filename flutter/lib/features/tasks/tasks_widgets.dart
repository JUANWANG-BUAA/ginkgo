import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

/// 单条本机待办卡片。
///
/// 定位到的待办会高亮并标注「已定位待办」；完成切换与更多操作都保持至少
/// 48dp 触控目标并带 TalkBack 语义标签。
class TaskRowCard extends StatelessWidget {
  const TaskRowCard({
    super.key,
    required this.task,
    required this.highlighted,
    required this.targetKey,
    required this.busy,
    required this.readable,
    required this.locating,
    required this.onToggle,
    required this.onMore,
    required this.onSource,
  });

  final LocalTaskRecord task;
  final bool highlighted;
  final Key targetKey;
  final bool busy;
  final bool readable;
  final bool locating;
  final VoidCallback onToggle;
  final VoidCallback onMore;
  final VoidCallback onSource;

  @override
  Widget build(BuildContext context) => Container(
    key: highlighted ? targetKey : ValueKey('task-container-${task.id}'),
    decoration: BoxDecoration(
      color: highlighted
          ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.07)
          : null,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: GinkgoSpacing.edgeInsetsCard,
    child: Column(
      key: Key('task-row-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (highlighted)
          Text(
            '已定位待办',
            key: Key('task-highlight-${task.id}'),
            style: GinkgoTypography.footnote.copyWith(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        Text(
          task.title,
          style: GinkgoTypography.headline.copyWith(
            color:
                (task.completed
                        ? CupertinoColors.secondaryLabel
                        : CupertinoColors.label)
                    .resolveFrom(context),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${task.completed ? '已在本机完成' : '待完成'} · ${localTaskDueLabel(task.due)}',
          style: GinkgoTypography.footnote.copyWith(
            color: AppleDesign.statusInactive.resolveFrom(context),
            height: 1.4,
          ),
        ),
        if (task.sourceAssignmentId != null)
          CupertinoButton(
            key: Key('task-source-${task.id}'),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.centerLeft,
            onPressed: locating ? null : onSource,
            child: Text(
              '来源：学校作业 · 查看来源',
              style: GinkgoTypography.footnote.copyWith(
                color:
                    (locating
                            ? CupertinoColors.secondaryLabel
                            : AppleDesign.statusInactive)
                        .resolveFrom(context),
                decoration: TextDecoration.underline,
                decorationColor: CupertinoColors.tertiaryLabel.resolveFrom(
                  context,
                ),
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Semantics(
              label: '${task.title}，${task.completed ? '标记未完成' : '标记本机完成'}',
              button: true,
              child: CupertinoButton(
                key: Key('task-toggle-${task.id}'),
                color: CupertinoTheme.of(context).primaryColor
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: busy || !readable ? null : onToggle,
                child: Text(
                  task.completed ? '撤销完成' : '本机完成',
                  style: TextStyle(
                    fontSize: AppleDesign.calloutSize,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ),
            Semantics(
              label: '${task.title}，更多操作',
              button: true,
              child: CupertinoButton(
                key: Key('task-more-${task.id}'),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: busy || !readable ? null : onMore,
                child: const Text('更多', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 待办页头操作（更多 / 新增）。
class TasksHeaderActions extends StatelessWidget {
  const TasksHeaderActions({
    super.key,
    required this.busy,
    required this.readable,
    required this.onMore,
    required this.onAdd,
  });

  final bool busy;
  final bool readable;
  final VoidCallback onMore;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: '待办更多操作',
        button: true,
        child: CupertinoButton(
          key: const Key('tasks-more'),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          onPressed: busy ? null : onMore,
          child: const Icon(CupertinoIcons.ellipsis),
        ),
      ),
      Semantics(
        label: '新增待办',
        button: true,
        child: CupertinoButton(
          key: const Key('tasks-add'),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          onPressed: busy || !readable ? null : onAdd,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
    ],
  );
}

/// 待办页头。
///
/// Cupertino 的导航栏把尾部控件限制在 44dp，因此手机端使用页内页头，让所有
/// 操作保持至少 48dp，而不改动共享导航组件。
class TasksPageHeader extends StatelessWidget {
  const TasksPageHeader({
    super.key,
    required this.actions,
    required this.canPop,
    required this.onBack,
  });

  final Widget actions;
  final bool canPop;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (AppleDesign.desktop(context)) {
      return ApplePageHeader(
        largeTitle: const Text('待办'),
        section: '工作台',
        subtitle: '安排个人任务与截止时间',
        icon: CupertinoIcons.list_bullet,
        border: null,
        trailing: actions,
      );
    }
    return PinnedHeaderSliver(
      child: ColoredBox(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (canPop)
                  SizedBox(
                    height: 48,
                    child: CupertinoNavigationBarBackButton(
                      key: const Key('tasks-back'),
                      previousPageTitle: '',
                      onPressed: onBack,
                    ),
                  ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('待办', style: GinkgoTypography.title2),
                  ),
                ),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
