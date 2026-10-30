import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/task_storage_scope.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/tasks/task_editor.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_widgets.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

enum _TaskAction { edit, delete }

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    this.storageRoot,
    required this.service,
    required this.fileActions,
    this.academicService,
    this.initialTaskId,
  });
  final String? storageRoot;
  final LocalTaskGateway service;

  /// The platform actions bound by the composition root.
  final PlatformActions fileActions;
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
  int generation = 0, sourceGeneration = 0;
  final targetKey = GlobalKey();
  bool located = false;
  bool completedExpanded = false;
  LocalTaskGateway get service => widget.service;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant TasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.academicService != widget.academicService) {
      sourceGeneration++;
      locating = false;
    }
    if (oldWidget.service != widget.service ||
        oldWidget.storageRoot != widget.storageRoot) {
      generation++;
      sourceGeneration++;
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
      final root = rootOverride ?? await TaskStorageScope.read(context)();
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
    final epoch = sourceGeneration;
    // The local task port never carries school data; the academic read must
    // arrive through its own typed port.
    final academic = widget.academicService;
    if (academic == null) {
      await sourceUnavailable();
      return;
    }
    setState(() => locating = true);
    try {
      final result = await academic.homework();
      if (!mounted || epoch != sourceGeneration) return;
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
            fileActions: widget.fileActions,
            service: academic,
            taskService: service,
            storageRoot: widget.storageRoot,
            openTaskOnLinked: false,
          ),
        ),
      );
    } catch (_) {
      if (mounted && epoch == sourceGeneration) await sourceUnavailable();
    } finally {
      if (mounted && epoch == sourceGeneration) {
        setState(() => locating = false);
      }
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

  Widget row(LocalTaskRecord task) => TaskRowCard(
    task: task,
    highlighted: task.id == widget.initialTaskId,
    targetKey: targetKey,
    busy: busy,
    readable: readable,
    locating: locating,
    onToggle: () => edit('toggle', task: task),
    onMore: () => taskMenu(task),
    onSource: () => source(task),
  );

  Widget headerActions() => TasksHeaderActions(
    busy: busy,
    readable: readable,
    onMore: pageMenu,
    onAdd: editor,
  );

  Widget pageHeader() => TasksPageHeader(
    actions: headerActions(),
    canPop: Navigator.of(context).canPop(),
    onBack: () => Navigator.of(context).maybePop(),
  );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
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
    ),
  );
}
