import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/today/today_course_focus.dart';
import 'package:ginkgo_mirror/features/today/today_course_list.dart';
import 'package:ginkgo_mirror/features/today/today_tasks_section.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/features/today/today_presentation.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';

import 'package:ginkgo_mirror/shared/reminders.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/features/today/today_homework_section.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.service,
    this.accountName,
    this.accountId,
    this.storageRoot,
    this.now,
    this.onAccountAction,
    this.directory,
    this.onOpenFeature,
    this.onOpenSettings,
    this.shortcutChoices = const [],
  });
  final MirrorService service;
  final List<WorkspaceShortcut> shortcutChoices;
  final Widget? directory;
  final ValueChanged<String>? onOpenFeature;
  final VoidCallback? onOpenSettings;
  final String? accountName;
  final String? accountId;

  /// Same local task directory used by TasksPage; injectable in tests.
  final String? storageRoot;

  /// An instant, converted to Beijing wall time for presentation.
  final DateTime Function()? now;
  final Future<void> Function()? onAccountAction;
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  Timer? _clock;
  bool? _active;
  bool _internalRouteInactive = false;
  bool _coursesExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    final returning = _active == false && active;
    _active = active;
    if (!active && _opening) _internalRouteInactive = true;
    final internalReturn = returning && _internalRouteInactive;
    if (returning) _internalRouteInactive = false;
    if (returning && !internalReturn && !_opening) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation && _active == true) {
          unawaited(_loadTasks());
        }
      });
    }
  }

  int _generation = 0;
  DateTime get _now => todaySchoolNow((widget.now ?? DateTime.now)());
  late RefreshSection<TodayTasksSnapshot> tasks;
  late RefreshSection<TodayResponse> courses;
  late RefreshSection<HomeworkResponse> homework;
  TodayResponse? get data => courses.value;
  String? get error => courses.error;
  bool get busy => courses.loading || homework.loading || tasks.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
    _createSection();
  }

  void _startClock() {
    _clock?.cancel();
    // Local labels only: no timer-driven requests or background polling.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startClock();
      _changed();
    } else {
      _clock?.cancel();
    }
  }

  void _createSection() {
    _generation++;
    _coursesExpanded = false;
    tasks = RefreshSection<TodayTasksSnapshot>()..addListener(_changed);
    courses = RefreshSection<TodayResponse>()..addListener(_changed);
    homework = RefreshSection<HomeworkResponse>()..addListener(_changed);
    load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.accountName != widget.accountName ||
        oldWidget.accountId != widget.accountId ||
        oldWidget.storageRoot != widget.storageRoot) {
      tasks.dispose();
      courses.dispose();
      homework.dispose();
      _createSection();
    }
  }

  @override
  void dispose() {
    _generation++;
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    tasks.dispose();
    courses.dispose();
    homework.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) => Future.wait([
    _loadCourses(force: force),
    _loadHomework(force: force),
    _loadTasks(),
  ]);

  Future<void> _loadCourses({bool force = false}) => courses.refresh(
    () async {
      final result = await widget.service.today(forceRefresh: force);
      return SectionResult(
        value: result.failure == null || result.fetchedAt != null
            ? result
            : null,
        error: result.failure == null ? null : failureMessage(result.failure),
      );
    },
    fallbackError: '本地服务暂时不可用，请重试',
    force: force,
  );

  Future<void> _loadHomework({bool force = false}) {
    final service = widget.service;
    final generation = _generation;
    return homework.refresh(
      () async {
        final result = await service.homework(forceRefresh: force);
        if (mounted && generation == _generation) {
          final reminders = ReminderScope.of(context);
          reminders?.updateHomework(result);
          if (reminders != null) unawaited(reminders.reconcile());
        }
        return SectionResult(
          value: result.failure == null || result.termCode.isNotEmpty
              ? result
              : null,
          error: result.failure == null ? null : failureMessage(result.failure),
        );
      },
      fallbackError: '本地服务暂时不可用，请重试',
      force: force,
    );
  }

  Future<String> _tasksRoot() => localTasksStorageRoot(widget.storageRoot);

  Future<void> _loadTasks() {
    final service = widget.service;
    return tasks.refresh(() async {
      final root = await _tasksRoot();
      final items = await editLocalTasks(service, root: root, action: 'load');
      return SectionResult(value: TodayTasksSnapshot(items, _now));
    }, fallbackError: '无法读取个人待办，请重试。');
  }

  bool _opening = false;
  Future<void> _openTasks(String? id) async {
    if (_opening) return;
    _opening = true;
    final generation = _generation;
    try {
      final root = await _tasksRoot();
      if (!mounted || generation != _generation) return;
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => TasksPage(
            storageRoot: root,
            service: widget.service,
            academicService: widget.service,
            demo: widget.service.isDemo,
            initialTaskId: id,
          ),
        ),
      );
      if (mounted && generation == _generation) await _loadTasks();
    } catch (_) {
      if (mounted && generation == _generation) {
        tasks.error = '无法打开个人待办，请重试。';
        _changed();
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _openHomework(HomeworkItem item) async {
    if (_opening) return;
    _opening = true;
    final generation = _generation;
    try {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => HomeworkDetailPage(
            item: item,
            service: widget.service,
            taskService: widget.service,
            storageRoot: widget.storageRoot,
          ),
        ),
      );
      if (mounted && generation == _generation) await _loadTasks();
    } catch (_) {
      if (mounted && generation == _generation) {
        tasks.error = '无法打开个人待办，请重试。';
        _changed();
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> accountAction() async {
    final demo = widget.service.isDemo;
    final action = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(widget.accountName ?? (demo ? '离线演示' : '账号')),
        content: Text(demo ? '当前为离线合成样例，不连接学校账号。' : '当前已登录真实学校账号。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'exit'),
            child: Text(demo ? '返回登录' : '退出登录'),
          ),
        ],
      ),
    );
    if (action == 'exit' && mounted) {
      await widget.onAccountAction!();
    }
  }

  @override
  Widget build(BuildContext context) => PageRefreshShortcut(
    onRefresh: busy ? null : () => load(force: true),
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('today-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: Text(widget.directory == null ? '今天' : '工作台'),
            border: null,
            section: '工作台',
            subtitle: '从今日课程开始安排一天',
            icon: CupertinoIcons.sun_max,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onOpenSettings != null ||
                    widget.onAccountAction != null) ...[
                  AppleGlassButton(
                    key: const Key('workspace-settings'),
                    label: widget.onOpenSettings != null
                        ? '设置'
                        : widget.service.isDemo
                        ? '演示模式'
                        : '账号',
                    onPressed:
                        widget.onOpenSettings ?? (busy ? null : accountAction),
                    child: Icon(
                      widget.onOpenSettings != null
                          ? CupertinoIcons.gear_alt
                          : widget.service.isDemo
                          ? CupertinoIcons.eye
                          : CupertinoIcons.person_crop_circle,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                AppleGlassButton(
                  label: '刷新今天',
                  onPressed: busy ? null : () => load(force: true),
                  child: busy
                      ? const GinkgoActivity()
                      : const Icon(CupertinoIcons.refresh, size: 24),
                ),
              ],
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ((constraints.crossAxisExtent - 820) / 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              sliver: SliverList.list(
                children: [
                  if (data == null)
                    TodayVisualSection(
                      header: const Text('今日课程'),
                      children: [
                        SectionFeedback(
                          loading: courses.loading,
                          label: '正在读取今天课程…',
                          hasData: false,
                          error: error,
                          onRetry: () => _loadCourses(force: true),
                        ),
                      ],
                    ),
                  if (data != null)
                    SectionReveal(
                      key: const Key('today-course-content'),
                      child: Column(children: _content(data!)),
                    ),
                  TodayHomeworkSection(
                    section: homework,
                    now: _now,
                    onOpenItem: _openHomework,
                    onRetry: () => _loadHomework(force: true),
                    onOpen: widget.onOpenFeature == null
                        ? null
                        : () => widget.onOpenFeature!('homework'),
                  ),
                  TodayTasksSection(
                    section: tasks,
                    now: _now,
                    onRetry: _loadTasks,
                    onOpen: _openTasks,
                  ),
                  if (widget.onOpenFeature != null) _shortcuts(),
                  if (widget.directory != null) widget.directory!,
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shortcuts() => WorkspaceShortcuts(
    accountId: widget.accountId,
    demo: widget.service.isDemo,
    choices: widget.shortcutChoices,
    storageRoot: widget.storageRoot,
    onOpen: widget.onOpenFeature!,
  );

  List<Widget> _content(TodayResponse data) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null ? data.date : schoolDateWeekdayLabel(date);
    return [
      TodayVisualSection(
        key: const Key('today-courses'),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TodaySectionHeader(
              icon: CupertinoIcons.calendar_today,
              title: '今日课程',
              badge: data.courses.isNotEmpty
                  ? '今天 ${data.courses.length} 节课'
                  : null,
              actionLabel: widget.onOpenFeature == null ? null : '完整课表',
              onAction: () => widget.onOpenFeature?.call('schedule'),
            ),
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
            ),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.fetchedAt != null)
              Text('课表同步：${_updatedAt(data.fetchedAt!)}'),
            Text(
              widget.service.isDemo
                  ? '离线演示 · 课程与日期为合成样例'
                  : '课程来自教务课表，签到状态请进入课程签到核对。',
            ),
          ],
        ),
        children: [
          if (courses.loading || error != null)
            SectionFeedback(
              loading: courses.loading,
              label: '正在更新今天课程…',
              hasData: true,
              error: error,
              onRetry: () => _loadCourses(force: true),
            ),
          if (data.courses.isEmpty)
            TodayCourseEmpty(
              error: error,
              onOpenSchedule: widget.onOpenFeature == null
                  ? null
                  : () => widget.onOpenFeature?.call('schedule'),
            ),
          if (data.courses.isNotEmpty)
            TodayCourseFocus(
              data: data,
              now: _now,
              stale: error != null,
              onOpen: widget.onOpenFeature == null
                  ? null
                  : () => widget.onOpenFeature!('schedule'),
            ),
          if (data.courses.isNotEmpty)
            Semantics(
              expanded: _coursesExpanded,
              child: CupertinoButton(
                key: const Key('today-toggle-courses'),
                minimumSize: const Size(48, 48),
                onPressed: () =>
                    setState(() => _coursesExpanded = !_coursesExpanded),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _coursesExpanded
                            ? '收起今日课程'
                            : '展开今日课程（${data.courses.length}）',
                      ),
                    ),
                    Icon(
                      _coursesExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          if (_coursesExpanded)
            for (final (index, course) in data.courses.indexed)
              TodayCourseRow(
                key: Key('today-course-$index-${course.name}'),
                course: course,
                status:
                    TodayCourseWindow.parse(
                      data.date,
                      course.time,
                    )?.status(_now) ??
                    '时间待确认',
              ),
          if (data.courses.isNotEmpty && widget.onOpenFeature != null)
            AppleListTile(
              title: Text(
                '查看完整课表',
                style: TextStyle(
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
              additionalInfo: Text(
                '共 ${data.courses.length} 门课',
                style: TextStyle(
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: () => widget.onOpenFeature!('schedule'),
            ),
        ],
      ),
    ];
  }

  String _updatedAt(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final beijing = date.toUtc().add(const Duration(hours: 8));
    final hour = beijing.hour.toString().padLeft(2, '0');
    final minute = beijing.minute.toString().padLeft(2, '0');
    return '${beijing.month}月${beijing.day}日 $hour:$minute';
  }
}
