import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/application/task_storage_scope.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/application/service_capabilities.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/top_bounce_scroll_physics.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/features/settings/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/shared/checkin_visibility.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'today_checkin_section.dart';
import 'today_course_section.dart';
import 'today_homework_section.dart';
import 'today_page_actions.dart';
import 'today_page_header.dart';
import 'today_status_strip.dart';
import 'today_tasks_section.dart';
import 'today_exam_section.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.service,
    required this.fileActions,
    this.accountName,
    this.accountId,
    this.storageRoot,
    this.now,
    this.onOpenFeature,
  });
  final MirrorService service;

  /// The platform actions bound by the composition root.
  final PlatformActions fileActions;
  final ValueChanged<String>? onOpenFeature;
  final String? accountName;
  final String? accountId;

  /// Same local task directory used by TasksPage; injectable in tests.
  final String? storageRoot;

  /// An instant, converted to Beijing wall time for presentation.
  final DateTime Function()? now;
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
  bool _captivePortal = false;
  bool _examsVisible = false;
  int? _weekNumber;
  String? _lastActiveDate;

  String get _headerDateLabel {
    final base = schoolDateWeekdayLabel(_now);
    final shortDate = base.startsWith('${_now.year}年')
        ? base.substring('${_now.year}年'.length)
        : base;
    return _weekNumber == null ? shortDate : '$shortDate · 第 $_weekNumber 周';
  }

  String _dateKey(DateTime wall) =>
      '${wall.year.toString().padLeft(4, '0')}-'
      '${wall.month.toString().padLeft(2, '0')}-'
      '${wall.day.toString().padLeft(2, '0')}';

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
  int routeRevision = 0;
  DateTime get _now => todaySchoolNow((widget.now ?? DateTime.now)());
  late RefreshSection<TodayTasksSnapshot> tasks;
  late RefreshSection<TodayResponse> courses;
  late RefreshSection<HomeworkResponse> homework;
  late RefreshSection<CheckInResponse> checkin;
  TodayResponse? get data => courses.value;
  String? get error => courses.error;
  bool get busy =>
      courses.loading || homework.loading || tasks.loading || checkin.loading;

  @override
  void initState() {
    super.initState();
    _lastActiveDate = _dateKey(_now);
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
      final currentDay = _dateKey(_now);
      final crossedMidnight =
          (_lastActiveDate != null && _lastActiveDate != currentDay) ||
          (data != null &&
              data!.date.isNotEmpty &&
              data!.date != currentDay);
      _lastActiveDate = currentDay;
      if (crossedMidnight && !busy) {
        unawaited(load(force: true));
      } else {
        _changed();
      }
    } else {
      _clock?.cancel();
    }
  }

  void _createSection() {
    _generation++;
    _coursesExpanded = false;
    _examsVisible = false;
    _weekNumber = null;
    tasks = RefreshSection<TodayTasksSnapshot>()..addListener(_changed);
    courses = RefreshSection<TodayResponse>()..addListener(_changed);
    homework = RefreshSection<HomeworkResponse>()..addListener(_changed);
    checkin = RefreshSection<CheckInResponse>()..addListener(_changed);
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
      checkin.dispose();
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
    checkin.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    final generation = _generation;
    examRefreshToken++;
    final today = DateTime.utc(_now.year, _now.month, _now.day);
    final confirmedNoClassesToday =
        data != null &&
        courses.error == null &&
        todayDate(data!.date) == today &&
        data!.courses.isEmpty;
    final eagerCheckIn =
        force && (!confirmedNoClassesToday || checkin.value != null);
    await Future.wait([
      _loadCourses(force: force),
      _loadHomework(force: force),
      _loadTasks(),
      if (eagerCheckIn) _loadCheckIn(force: true),
    ]);
    if (force &&
        !eagerCheckIn &&
        mounted &&
        generation == _generation &&
        data != null &&
        data!.courses.isNotEmpty) {
      await _loadCheckIn(force: true);
    }
    if (mounted && generation == _generation) {
      setState(() => routeRevision++);
      unawaited(_checkCaptivePortal(generation));
    }
  }

  Future<void> _checkCaptivePortal(int generation) async {
    final probe = widget.fileActions.networkStatus;
    if (probe == null || _errorSections == 0) {
      if (_captivePortal && mounted) setState(() => _captivePortal = false);
      return;
    }
    try {
      final status = await probe();
      if (!mounted || generation != _generation) return;
      final isCaptive = status == 'captivePortal';
      if (isCaptive != _captivePortal) {
        setState(() => _captivePortal = isCaptive);
      }
    } catch (_) {}
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

  Future<void> _loadCheckIn({bool force = false}) => checkin.refresh(
    () async {
      final result = await widget.service.checkin(forceRefresh: force);
      return SectionResult(
        value: result.failure == null || result.stale ? result : null,
        error: result.failure == null ? null : failureMessage(result.failure),
        failure: result.failure,
      );
    },
    fallbackError: '签到状态暂时无法读取',
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

  Future<String> _tasksRoot() async =>
      widget.storageRoot ?? await TaskStorageScope.read(context)();

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
      fileActions: widget.fileActions,
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
      fileActions: widget.fileActions,
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

  List<String> get _loadingLabels => [
    if (courses.loading) '今日课表',
    if (homework.loading) '学校作业',
    if (checkin.loading) '课程签到',
  ];

  int get _readySections => [
    courses.value != null && courses.error == null,
    homework.value != null && homework.error == null,
    checkin.value != null && checkin.error == null,
  ].where((ok) => ok).length;

  int get _errorSections => [
    courses.error != null,
    homework.error != null,
    tasks.error != null,
    checkin.error != null,
  ].where((failed) => failed).length;

  void _openDiagnostics() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => NetworkDiagnosticsPage(service: widget.service),
      ),
    );
  }

  bool _isAllQuietToday(BuildContext context) {
    final courseData = data;
    final homeworkData = homework.value;
    final tasksData = tasks.value;
    if (_errorSections > 0 ||
        _examsVisible ||
        courseData == null ||
        homeworkData == null ||
        tasksData == null) {
      return false;
    }
    final today = DateTime.utc(_now.year, _now.month, _now.day);
    if (courseData.courses.isNotEmpty || todayDate(courseData.date) != today) {
      return false;
    }
    final checkinData = checkin.value;
    if (checkinData != null) {
      final checkinDate = todayDate(checkinData.date);
      final checkinNeedsRefresh =
          checkinData.stale || checkinDate == null || checkinDate != today;
      if (checkinNeedsRefresh ||
          TodayCheckInSection.pendingCourses(
            checkinData,
            visibility: CourseVisibilityScope.of(context),
            homework: homeworkData,
            todaySchedule: courseData,
          ).isNotEmpty) {
        return false;
      }
    }
    if (homeworkData.rolesComplete != true) return false;
    final personalHomework = personalHomeworkItems(
      homeworkData.items,
      CourseVisibilityScope.of(context),
    );
    if (personalHomework.any(
      (item) =>
          item.status == HomeworkStatus.unknown ||
          (item.status == HomeworkStatus.pending &&
              !isHomeworkOverdue(item.dueAt, _now)),
    )) {
      return false;
    }
    if (tasksData.items.any((task) => !task.completed)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxContentWidth = 820.0;
    final horizontalInset = screenWidth > maxContentWidth
        ? (screenWidth - maxContentWidth) / 2
        : 0.0;
    final bottomClearance =
        GinkgoSpacing.bottomScrollClearance +
        MediaQuery.paddingOf(context).bottom;
    final physics = MediaQuery.disableAnimationsOf(context)
        ? const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics())
        : const AlwaysScrollableScrollPhysics(parent: TopBounceScrollPhysics());

    final visibility = CourseVisibilityScope.of(context);
    final hasCoursesToday = data != null && data!.courses.isNotEmpty;
    final personalCheckIns = TodayCheckInSection.personalCourses(
      checkin.value,
      visibility: visibility,
      homework: homework.value,
      todaySchedule: data,
    );
    final fusedCheckInIds = hasCoursesToday
        ? {
            for (final course in data!.courses)
              if (matchCheckInForTodayCourse(course, personalCheckIns)
                  case final matched?)
                matched.id,
          }
        : const <String>{};

    return PageRefreshShortcut(
      onRefresh: busy ? null : () => load(force: true),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
          context,
        ),
        child: CustomScrollView(
          key: const Key('today-scroll'),
          physics: physics,
          slivers: [
            TodayPageHeader(
              title: '今天',
              dateLabel: _headerDateLabel,
              busy: busy,
              onRefresh: () => load(force: true),
            ),
            CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              sliver: SliverList.list(
                children: [
                  TodayDateContext(label: _headerDateLabel),
                  TodayStatusStrip(
                    demo: widget.service.isDemo,
                    loadingLabels: _loadingLabels,
                    readySections: _readySections,
                    errorSections: _errorSections,
                    routeRevision: routeRevision,
                    captivePortal: _captivePortal,
                    onOpenWifiSettings: widget.fileActions.openWifiSettings,
                    verifiedRoute: ServiceCapabilities.resolve(widget.service)
                        .verifiedRoute,
                    onOpenDiagnostics: _openDiagnostics,
                  ),
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
                        checkinSection: checkin,
                        checkinCourses: personalCheckIns,
                        onCheckInRetry: () => _loadCheckIn(force: true),
                        onOpenCheckIn: () =>
                            widget.onOpenFeature?.call('checkin'),
                      ),
                    ),
                  TodayCheckInSection(
                    section: checkin,
                    now: _now,
                    hasCoursesToday: hasCoursesToday,
                    todaySchedule: data,
                    homework: homework.value,
                    handledByCourses: hasCoursesToday,
                    fusedCourseIds: fusedCheckInIds,
                    onRetry: () => _loadCheckIn(force: true),
                    onOpen: () => widget.onOpenFeature?.call('checkin'),
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
                    onVisibilityChanged: (visible) {
                      if (_examsVisible != visible && mounted) {
                        setState(() => _examsVisible = visible);
                      }
                    },
                    onWeekNumberChanged: (week) {
                      if (_weekNumber != week && mounted) {
                        setState(() => _weekNumber = week);
                      }
                    },
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
                  if (_isAllQuietToday(context)) TodayAllQuietView(now: _now),
                  SizedBox(height: bottomClearance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
