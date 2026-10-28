import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/features/schedule/course_visibility.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';

import 'today_course_section.dart';
import 'today_homework_section.dart';
import 'today_page_actions.dart';
import 'today_page_header.dart';
import 'today_tasks_section.dart';
import 'today_exam_section.dart';

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

  /// Opens the pages the dashboard links to; only one route at a time.
  final navigator = TodayNavigator();

  bool? _active;
  bool _internalRouteInactive = false;
  bool _coursesExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    final returning = _active == false && active;
    _active = active;
    if (!active && navigator.opening) _internalRouteInactive = true;
    final internalReturn = returning && _internalRouteInactive;
    if (returning) _internalRouteInactive = false;
    if (returning && !internalReturn && !navigator.opening) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation && _active == true) {
          unawaited(_loadTasks());
        }
      });
    }
  }

  int _generation = 0;
  int examRefreshToken = 0;
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

  Future<void> load({bool force = false}) {
    examRefreshToken++;
    return Future.wait([
      _loadCourses(force: force),
      _loadHomework(force: force),
      _loadTasks(),
    ]);
  }

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
          value: result.failure == null || result.fetchedAt != null
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

  Future<void> _openTasks(String? id) {
    final generation = _generation;
    return navigator.openTasks(
      context,
      service: widget.service,
      storageRoot: widget.storageRoot,
      taskId: id,
      isCurrent: () => mounted && generation == _generation,
      reload: _loadTasks,
      onFailure: (message) {
        tasks.error = message;
        _changed();
      },
    );
  }

  Future<void> _openHomework(HomeworkItem item) {
    final generation = _generation;
    return navigator.openHomework(
      context,
      service: widget.service,
      storageRoot: widget.storageRoot,
      item: item,
      isCurrent: () => mounted && generation == _generation,
      reload: _loadTasks,
      onFailure: (message) {
        tasks.error = message;
        _changed();
      },
    );
  }

  Future<void> accountAction() async {
    final leave = await showTodayAccountDialog(
      context,
      accountName: widget.accountName,
      demo: widget.service.isDemo,
    );
    if (leave && mounted) {
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
          TodayPageHeader(
            title: widget.directory == null ? '今天' : '工作台',
            busy: busy,
            demo: widget.service.isDemo,
            onRefresh: () => load(force: true),
            onOpenSettings: widget.onOpenSettings,
            onAccountAction: widget.onAccountAction == null
                ? null
                : accountAction,
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
                    TodayCoursePlaceholder(
                      loading: courses.loading,
                      error: error,
                      onRetry: () => _loadCourses(force: true),
                    )
                  else
                    SectionReveal(
                      key: const Key('today-course-content'),
                      child: TodayCourseSection(
                        data: data!,
                        now: _now,
                        loading: courses.loading,
                        error: error,
                        expanded: _coursesExpanded,
                        onToggleExpanded: () => setState(
                          () => _coursesExpanded = !_coursesExpanded,
                        ),
                        onRetry: () => _loadCourses(force: true),
                        onOpenSchedule: widget.onOpenFeature == null
                            ? null
                            : () => widget.onOpenFeature!('schedule'),
                        demo: widget.service.isDemo,
                      ),
                    ),
                  TodayExamSection(
                    key: ValueKey((
                      widget.accountId,
                      widget.accountName,
                      widget.storageRoot,
                    )),
                    service: widget.service,
                    now: _now,
                    refreshToken: examRefreshToken,
                    onOpen: widget.onOpenFeature,
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
                    visibleHomeworkIds: todayVisibleHomework(
                      homework.value,
                      CourseVisibilityScope.of(context),
                      _now,
                    ).map((item) => item.id).toSet(),
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
}
