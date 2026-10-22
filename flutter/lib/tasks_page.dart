import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

import 'apple_widgets.dart';
import 'application/local_tasks.dart';
import 'homework_detail_page.dart';
import 'mirror_service.dart';
import 'task_editor.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    this.demo = false,
    this.storageRoot,
    this.service,
    this.academicService,
    this.initialTaskId,
  });
  final bool demo;
  final String? storageRoot;
  final CampusGateway? service;
  final AcademicGateway? academicService;
  final String? initialTaskId;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<LocalTaskRecord> tasks = [];
  String? error;
  bool busy = false, readable = false, locating = false;
  int generation = 0;
  final targetKey = GlobalKey();
  bool located = false;
  CampusGateway get service =>
      widget.service ?? mirrorServiceFor(demo: widget.demo);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant TasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.storageRoot != widget.storageRoot ||
        oldWidget.demo != widget.demo) {
      generation++;
      tasks = [];
      busy = false;
      readable = false;
      located = false;
      load();
    } else if (oldWidget.initialTaskId != widget.initialTaskId) {
      located = false;
      locate();
    }
  }

  void locate() {
    if (located || widget.initialTaskId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || located) return;
      final target = targetKey.currentContext;
      if (target != null) {
        located = true;
        Scrollable.ensureVisible(target, alignment: 0.2);
      }
    });
  }

  Future<void> load() async {
    await edit('load');
  }

  Future<bool> edit(
    String action, {
    LocalTaskRecord? task,
    TaskDraft? draft,
  }) async {
    if (busy || (action != 'load' && !readable)) return false;
    final epoch = generation;
    final gateway = service;
    final rootOverride = widget.storageRoot;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final root = await localTasksStorageRoot(rootOverride);
      if (!mounted || epoch != generation) return false;
      final updated = await editLocalTasks(
        gateway,
        root: root,
        action: action,
        id: task?.id,
        title: draft?.title,
        due: draft?.due,
        completed: action == 'toggle' ? !task!.completed : null,
      );
      if (!mounted || epoch != generation) return false;
      setState(() {
        tasks = updated;
        busy = false;
        readable = true;
      });
      locate();
      return true;
    } catch (_) {
      if (mounted && epoch == generation) {
        setState(() {
          busy = false;
          readable = false;
          error = '待办读取或保存未确认，请刷新核对后再编辑。';
        });
      }
      return false;
    }
  }

  Future<void> editor([LocalTaskRecord? task]) async {
    final epoch = generation;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => TaskEditor(
          title: task?.title ?? '',
          due: task?.due ?? '',
          sourceAssignmentId: task?.sourceAssignmentId,
          isNew: task == null,
          onSave: (draft) async {
            if (!mounted || epoch != generation) return false;
            return edit(
              task == null ? 'add' : 'update',
              task: task,
              draft: draft,
            );
          },
        ),
      ),
    );
  }

  Future<void> remove(LocalTaskRecord task) async {
    final epoch = generation;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除待办？'),
        content: Text(task.title),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && epoch == generation) {
      await edit('delete', task: task);
    }
  }

  Future<void> source(LocalTaskRecord task) async {
    if (locating) return;
    final epoch = generation;
    final academic =
        widget.academicService ??
        (service is AcademicGateway ? service as AcademicGateway : null);
    if (academic == null) {
      await sourceUnavailable();
      return;
    }
    setState(() => locating = true);
    try {
      final result = await academic.homework();
      if (!mounted || epoch != generation) return;
      if (result.failure != null) {
        await sourceUnavailable();
        return;
      }
      final matches = result.items
          .where((item) => item.id == task.sourceAssignmentId)
          .toList();
      if (matches.length != 1) {
        await sourceUnavailable();
        return;
      }
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => HomeworkDetailPage(
            item: matches.single,
            service: academic,
            taskService: service,
            storageRoot: widget.storageRoot,
            openTaskOnLinked: false,
          ),
        ),
      );
    } catch (_) {
      if (mounted && epoch == generation) await sourceUnavailable();
    } finally {
      if (mounted && epoch == generation) setState(() => locating = false);
    }
  }

  Future<void> sourceUnavailable() => showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('暂时无法定位来源作业'),
      content: const Text('当前作业列表中没有可验证的来源，请到作业页刷新并查找。本机待办会保留。'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Widget row(LocalTaskRecord task) {
    final highlighted = task.id == widget.initialTaskId;
    return Container(
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
              onPressed: locating ? null : () => source(task),
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
                  onPressed: busy || !readable
                      ? null
                      : () => edit('toggle', task: task),
                  child: Text(
                    task.completed ? '撤销完成' : '本机完成',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ),
              CupertinoButton(
                key: Key('task-edit-${task.id}'),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: busy || !readable ? null : () => editor(task),
                child: Text(
                  '编辑',
                  style: TextStyle(
                    fontSize: 15,
                    color:
                        (busy || !readable
                                ? CupertinoColors.secondaryLabel
                                : AppleDesign.statusInactive)
                            .resolveFrom(context),
                  ),
                ),
              ),
              CupertinoButton(
                key: Key('task-delete-${task.id}'),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: busy || !readable ? null : () => remove(task),
                child: Text(
                  '删除',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppleDesign.statusDanger.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('tasks-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('待办'),
          border: null,
          trailing: AppleGlassButton(
            label: '新增待办',
            onPressed: busy || !readable ? null : () => editor(),
            child: const Icon(CupertinoIcons.add),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 4),
                child: Text(
                  '个人待办仅保存在本机。完成不代表已向学校提交作业。',
                  style: GinkgoTypography.footnote.copyWith(
                    color: AppleDesign.statusInactive.resolveFrom(context),
                    height: 1.4,
                  ),
                ),
              ),
              CupertinoButton(
                minimumSize: const Size(48, 48),
                onPressed: busy ? null : load,
                child: Text(
                  '刷新待办',
                  style: TextStyle(
                    fontSize: 15,
                    color:
                        (busy
                                ? CupertinoColors.secondaryLabel
                                : AppleDesign.statusInactive)
                            .resolveFrom(context),
                  ),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CupertinoActivityIndicator(),
                ),
              if (error != null)
                AppleSection(
                  children: [
                    AppleEmptyState(
                      title: error!,
                      description: '保留上次可读结果，不自动重试写入。',
                      error: true,
                      action: '重试',
                      onAction: load,
                    ),
                  ],
                ),
              if (!busy && readable && tasks.isEmpty)
                const AppleSection(
                  children: [
                    AppleEmptyState(
                      title: '暂无待办',
                      description: '点击右上角添加，或从作业详情添加个人待办。',
                    ),
                  ],
                ),
              if (readable &&
                  widget.initialTaskId != null &&
                  !tasks.any((t) => t.id == widget.initialTaskId))
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('该待办已不在当前账号的本机列表中。'),
                ),
              for (final completed in [false, true])
                for (final noDue in [false, true])
                  if (tasks.any(
                    (t) => t.completed == completed && t.due.isEmpty == noDue,
                  ))
                    AppleSection(
                      header: Text(
                        completed
                            ? '已完成'
                            : noDue
                            ? '无截止时间'
                            : '待完成 · 有截止',
                      ),
                      children: [
                        for (final task in tasks.where(
                          (t) =>
                              t.completed == completed &&
                              t.due.isEmpty == noDue,
                        ))
                          row(task),
                      ],
                    ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ],
    ),
  );
}
