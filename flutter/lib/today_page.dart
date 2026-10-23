import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'application/local_tasks.dart';
import 'homework_detail_page.dart';
import 'tasks_page.dart';
import 'today_course_focus.dart';
import 'today_tasks_section.dart';
import 'today_time.dart';
import 'today_presentation.dart';
import 'workspace_shortcuts.dart';

import 'reminders.dart';

import 'apple_widgets.dart';
import 'application/refresh_section.dart';
import 'loading_widgets.dart';
import 'today_homework_section.dart';
import 'mirror_service.dart';
import 'apple_design.dart';
import 'application/contracts.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

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

  Future<void> _loadCourses({bool force = false}) => courses.refresh(() async {
    final result = await widget.service.today(forceRefresh: force);
    return SectionResult(
      value: result.failure == null || result.fetchedAt != null ? result : null,
      error: result.failure == null ? null : failureMessage(result.failure),
    );
  }, fallbackError: '本地服务暂时不可用，请重试');

  Future<void> _loadHomework({bool force = false}) {
    final service = widget.service;
    final generation = _generation;
    return homework.refresh(() async {
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
    }, fallbackError: '本地服务暂时不可用，请重试');
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
    final dateLabel = date == null
        ? data.date
        : '${date.year}年${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';
    return [
      TodayVisualSection(
        key: const Key('today-courses'),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TodaySectionHeader(
              icon: CupertinoIcons.calendar_today,
              title: '今日课程',
              badge: data.courses.isNotEmpty ? '今天 ${data.courses.length} 节课' : null,
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
            _TodayCourseEmpty(
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
              _TodayCourseRow(
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

/// Keep course times on a visible axis, like the native Today views. At large
/// type sizes the axis moves above the title so neither field is squeezed.
class _TodayCourseRow extends StatelessWidget {
  const _TodayCourseRow({
    super.key,
    required this.course,
    required this.status,
  });
  final TodayCourse course;
  final String status;

  @override
  Widget build(BuildContext context) {
    final times = RegExp(r'^(\d{1,2}:\d{2})\s*[-–—~～]\s*(\d{1,2}:\d{2})$')
        .firstMatch(course.time?.trim() ?? '');
    final secondary = AppleDesign.statusInactive.resolveFrom(context);
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          times?.group(1) ?? course.time ?? '时间未提供',
          style: TextStyle(
            fontSize: times == null ? 13 : 17,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (times != null)
          Text(
            times.group(2)!,
            style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontFeatures: GinkgoTypography.tabularDigits,
            ),
          ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status, style: TextStyle(fontSize: 13, color: secondary)),
        const SizedBox(height: 4),
        Text(
          course.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 5),
        Text(
          course.place?.trim().isNotEmpty == true ? course.place! : '地点未提供',
          style: TextStyle(fontSize: 13, color: secondary),
        ),
      ],
    );
    return Padding(
      padding: GinkgoSpacing.edgeInsetsCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: CupertinoColors.separator.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stacked)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [time, const SizedBox(height: 8), details],
                        ),
                      )
                    else ...[
                      SizedBox(width: 84, child: time),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayCourseEmpty extends StatelessWidget {
  const _TodayCourseEmpty({
    required this.error,
    required this.onOpenSchedule,
  });

  final String? error;
  final VoidCallback? onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    if (isLargeText) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      error != null
                          ? CupertinoIcons.exclamationmark_triangle_fill
                          : CupertinoIcons.calendar,
                      size: 18,
                      color: error != null
                          ? AppleDesign.statusDanger.resolveFrom(context)
                          : accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error != null ? '今日课程尚未确认' : '今天没有课程',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              error != null
                  ? '课表更新失败，请刷新后再确认今天的安排。'
                  : '当前课表中没有当天课程，可查看完整课表安排学习。',
              style: TextStyle(
                fontSize: 13,
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
            ),
            if (onOpenSchedule != null) ...[
              const SizedBox(height: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(8),
                minimumSize: const Size(48, 32),
                onPressed: onOpenSchedule,
                child: Text(
                  '查看完整课表',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                error != null
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.calendar,
                size: 22,
                color: error != null
                    ? AppleDesign.statusDanger.resolveFrom(context)
                    : accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error != null ? '今日课程尚未确认' : '今天没有课程',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  error != null
                      ? '课表更新失败，请刷新后再确认今天的安排。'
                      : '当前课表中没有当天课程，可查看完整课表安排学习。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppleDesign.statusInactive.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          if (onOpenSchedule != null) ...[
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
              minimumSize: const Size(48, 32),
              onPressed: onOpenSchedule,
              child: Text(
                '查看完整课表',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
