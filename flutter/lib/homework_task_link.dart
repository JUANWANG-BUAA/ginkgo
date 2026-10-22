import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

import 'application/contracts.dart';
import 'application/local_tasks.dart';
import 'application/mirror_service.dart';
import 'task_editor.dart';
import 'tasks_page.dart';

/// Pure local action; never submits, uploads, or changes school state.
class HomeworkTaskLink extends StatefulWidget {
  const HomeworkTaskLink({
    super.key,
    required this.item,
    required this.academicService,
    required this.taskService,
    this.storageRoot,
    this.dueAt,
    this.openTaskOnLinked = true,
  });
  final HomeworkItem item;
  final AcademicGateway academicService;
  final CampusGateway? taskService;
  final String? storageRoot, dueAt;
  final bool openTaskOnLinked;
  @override
  State<HomeworkTaskLink> createState() => _HomeworkTaskLinkState();
}

class _HomeworkTaskLinkState extends State<HomeworkTaskLink> {
  bool busy = false;
  int generation = 0;
  LocalTaskRecord? linked;
  String? message;
  @override
  void didUpdateWidget(covariant HomeworkTaskLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.academicService != widget.academicService ||
        oldWidget.taskService != widget.taskService ||
        oldWidget.storageRoot != widget.storageRoot) {
      generation++;
      busy = false;
      linked = null;
      message = null;
    }
  }

  Future<void> add() async {
    if (busy) return;
    final service = widget.taskService;
    if (service == null || widget.item.id.trim().isEmpty) return;
    final epoch = generation;
    final assignment = widget.item.id;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final root = await localTasksStorageRoot(widget.storageRoot);
      if (!mounted || epoch != generation) return;
      final existing = await editLocalTasks(
        service,
        root: root,
        action: 'load',
      );
      if (!mounted || epoch != generation) return;
      final matches = existing.where((t) => t.sourceAssignmentId == assignment);
      if (matches.isNotEmpty) {
        setState(() {
          linked = matches.first;
          message = '已添加过此作业，保留原待办的编辑与完成状态。';
        });
        return;
      }
      await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => TaskEditor(
            title: widget.item.title,
            due: localTaskDueFromHomework(widget.dueAt ?? widget.item.dueAt),
            sourceAssignmentId: assignment,
            onSave: (draft) async {
              if (!mounted || epoch != generation) return false;
              final updated = await editLocalTasks(
                service,
                root: root,
                action: 'add_homework',
                id: assignment,
                title: draft.title,
                due: draft.due,
              );
              if (!mounted || epoch != generation) return false;
              final added = updated
                  .where((t) => t.sourceAssignmentId == assignment)
                  .toList();
              if (added.length != 1) return false;
              setState(() {
                linked = added.single;
                message = '已关联本机待办；若已存在则保留原条目，不覆盖编辑或完成状态。';
              });
              return true;
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted && epoch == generation) {
        setState(() => message = '本机待办读取未确认，请到待办页刷新核对后再操作。');
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> view() async {
    if (linked == null || busy) return;
    if (!widget.openTaskOnLinked) {
      Navigator.of(context).pop();
      return;
    }
    final epoch = generation;
    final id = linked!.id;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => TasksPage(
          service: widget.taskService,
          academicService: widget.academicService,
          storageRoot: widget.storageRoot,
          initialTaskId: id,
        ),
      ),
    );
    if (mounted && epoch == generation) {
      setState(() {
        linked = null;
        message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '转为个人待办',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '仅在本机记录，标记完成不等于学校提交。标题和截止时间可在确认前编辑。',
          style: GinkgoTypography.footnote.copyWith(
            color: AppleDesign.statusInactive.resolveFrom(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.taskService == null)
          const Text('当前服务不支持本机待办，请到待办页手动添加。')
        else if (widget.item.id.trim().isEmpty)
          const Text('此作业缺少稳定标识，请到待办页手动添加。')
        else
          CupertinoButton(
            key: const Key('homework-add-task'),
            color: CupertinoTheme.of(context).primaryColor
                .withValues(alpha: 0.12),
            minimumSize: const Size(48, 48),
            onPressed: busy ? null : add,
            child: busy
                ? const CupertinoActivityIndicator()
                : Text(
                    '添加到待办',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              message!,
              style: GinkgoTypography.footnote.copyWith(
                color: AppleDesign.statusInactive.resolveFrom(context),
                height: 1.4,
              ),
            ),
          ),
        if (linked != null)
          CupertinoButton(
            key: const Key('homework-view-task'),
            minimumSize: const Size(48, 48),
            onPressed: busy ? null : view,
            child: Text(widget.openTaskOnLinked ? '查看已有待办' : '返回已有待办'),
          ),
      ],
    ),
  );
}
