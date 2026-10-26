import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

import 'apple_widgets.dart';
import 'application/local_tasks.dart';
import 'homework_detail_page.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';
import 'task_editor.dart';
import 'reminders.dart';

enum _TaskAction { edit, delete }

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
  String busyLabel = '正在读取待办…';
  int generation = 0;
  final targetKey = GlobalKey();
  bool located = false;
  bool completedExpanded = false;
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
      completedExpanded = false;
      load();
    } else if (oldWidget.initialTaskId != widget.initialTaskId) {
      located = false;
      locate();
    }
  }

  void locate() {
    if (located || widget.initialTaskId == null) return;
    if (!completedExpanded &&
        tasks.any(
          (task) => task.id == widget.initialTaskId && task.completed,
        )) {
      setState(() => completedExpanded = true);
    }
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
    // Keep the old account's controller, never resolve a new one after await.
    final reminders = ReminderScope.read(context);
    setState(() {
      busyLabel = action == 'load' ? '正在读取待办…' : '正在保存待办…';
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
      await reminders?.updateTasks(updated);
      await reminders?.reconcile();
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

  Future<void> taskMenu(LocalTaskRecord task) async {
    final epoch = generation;
    final action = await showCupertinoModalPopup<_TaskAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(task.title),
        actions: [
          CupertinoActionSheetAction(
            key: Key('task-edit-${task.id}'),
            onPressed: () => Navigator.pop(context, _TaskAction.edit),
            child: const Text('编辑'),
          ),
          CupertinoActionSheetAction(
            key: Key('task-delete-${task.id}'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, _TaskAction.delete),
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (!mounted || epoch != generation || busy || !readable) return;
    switch (action) {
      case _TaskAction.edit:
        await editor(task);
      case _TaskAction.delete:
        await remove(task);
      case null:
        break;
    }
  }

  Future<void> pageMenu() async {
    final epoch = generation;
    final refresh = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('待办操作'),
        actions: [
          CupertinoActionSheetAction(
            key: const Key('tasks-refresh'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刷新待办'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (refresh == true && mounted && epoch == generation && !busy) {
      await load();
    }
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
      if (!mounted) return;
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
              Semantics(
                label: '${task.title}，更多操作',
                button: true,
                child: CupertinoButton(
                  key: Key('task-more-${task.id}'),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: busy || !readable ? null : () => taskMenu(task),
                  child: const Text('更多', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget headerActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: '待办更多操作',
        button: true,
        child: CupertinoButton(
          key: const Key('tasks-more'),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          onPressed: busy ? null : pageMenu,
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
          onPressed: busy || !readable ? null : () => editor(),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
    ],
  );

  Widget pageHeader() {
    if (AppleDesign.desktop(context)) {
      return ApplePageHeader(
        largeTitle: const Text('待办'),
        section: '工作台',
        subtitle: '安排个人任务与截止时间',
        icon: CupertinoIcons.list_bullet,
        border: null,
        trailing: headerActions(),
      );
    }
    // Cupertino's navigation toolbar constrains trailing controls to 44dp.
    // A page-local header keeps all phone actions at least 48dp without
    // changing the shared navigation components.
    return PinnedHeaderSliver(
      child: ColoredBox(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  SizedBox(
                    height: 48,
                    child: CupertinoNavigationBarBackButton(
                      key: const Key('tasks-back'),
                      previousPageTitle: '',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('待办', style: GinkgoTypography.title2),
                  ),
                ),
                headerActions(),
              ],
            ),
          ),
        ),
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
        pageHeader(),
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
              if (busy && tasks.isEmpty) GinkgoLoadingView(label: busyLabel),
              if (busy && tasks.isNotEmpty)
                Padding(
                  key: const Key('tasks-refreshing'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Semantics(
                      label: busyLabel,
                      child: const GinkgoActivity(size: 17),
                    ),
                  ),
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
                      description: '点击右上角添加本机待办。',
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
              for (final noDue in [false, true])
                if (tasks.any((t) => !t.completed && t.due.isEmpty == noDue))
                  AppleSection(
                    header: Text(noDue ? '无截止时间' : '待完成 · 有截止'),
                    children: [
                      for (final task in tasks.where(
                        (t) => !t.completed && t.due.isEmpty == noDue,
                      ))
                        row(task),
                    ],
                  ),
              if (tasks.any((t) => t.completed))
                AppleSection(
                  key: const Key('tasks-completed-section'),
                  // Keep target geometry stable when opening a located task.
                  animateSize: false,
                  children: [
                    Semantics(
                      expanded: completedExpanded,
                      child: CupertinoButton(
                        key: const Key('tasks-completed-toggle'),
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.all(16),
                        onPressed: () => setState(
                          () => completedExpanded = !completedExpanded,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '已完成（${tasks.where((t) => t.completed).length}）',
                                style: GinkgoTypography.headline.copyWith(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ),
                            Icon(
                              completedExpanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (completedExpanded)
                      for (final task in tasks.where((t) => t.completed))
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
