import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/shared/checkin_sessions.dart';
import 'package:ginkgo_mirror/shared/checkin_visibility.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_loading.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_qr_sheet.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_modal_sheet.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/features/schedule/course_range_page.dart';

/// Per-course classroom QR generation with智慧北航 scan guidance and status readback.
class CheckInPage extends StatefulWidget {
  const CheckInPage({
    super.key,
    required this.service,
    this.platformActions = const PlatformActions(),
    this.history = false,
    this.clock,
  });
  final CheckInGateway service;
  final PlatformActions platformActions;
  final bool history;
  final DateTime Function()? clock;
  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  Timer? windowTick;
  CheckInResponse? data;
  String? readIssue;
  bool busy = false;
  bool qrOpen = false;
  CourseVisibility? range;

  bool get verified => data != null && !busy && readIssue == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    range = CourseVisibilityScope.of(context);
  }

  String courseKey(CheckInCourse course) => checkinCourseKey(course);
  int requestSerial = 0;
  int contextGeneration = 0;
  late DateTime selectedDate;
  DateTime get instant => widget.clock?.call() ?? DateTime.now();
  DateTime get schoolToday {
    final now = todaySchoolNow(instant);
    return DateTime(now.year, now.month, now.day);
  }

  String dateString(DateTime day) => schoolDateString(day);
  Future<void> changeDate(DateTime day) async {
    if (day.isAfter(schoolToday)) return;
    setState(() => selectedDate = day);
    await load();
  }

  Future<void> pickDate() async {
    var picked = selectedDate;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确定'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selectedDate,
                  maximumDate: schoolToday,
                  onDateTimeChanged: (date) => picked = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await changeDate(picked);
  }

  @override
  void initState() {
    super.initState();
    selectedDate = schoolToday.subtract(const Duration(days: 1));
    windowTick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    load();
  }

  @override
  void didUpdateWidget(CheckInPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.history != widget.history) {
      contextGeneration++;
      requestSerial++;
      data = null;
      readIssue = null;
      busy = false;
      qrOpen = false;
      load();
    }
  }

  @override
  void dispose() {
    windowTick?.cancel();
    super.dispose();
  }

  Future<void> retryRead() async {
    if (busy) return;
    await load(force: true);
  }

  String readFailureMessage(FailureCode code, String? detail) {
    if (code != FailureCode.moduleAuthRequired ||
        detail == 'webvpn_route_login_required') {
      return failureMessage(code, detail: detail);
    }
    DiagnosticLog.shared.record(code, showHint: false);
    return 'iClass 认证尚未完成，请重试签到查询。这不代表账号已退出。';
  }

  Future<void> load({bool force = false}) async {
    final serial = ++requestSerial;
    final requested = dateString(selectedDate);
    setState(() {
      busy = true;
      if (data == null) readIssue = null;
    });
    try {
      final result = widget.history
          ? await widget.service.checkinOnDate(requested, forceRefresh: force)
          : await widget.service.checkin(forceRefresh: force);
      if (!mounted || serial != requestSerial) return;
      if (!widget.history) {
        final reminders = ReminderScope.of(context);
        reminders?.updateCheckin(result);
        if (reminders != null) unawaited(reminders.reconcile());
      }
      setState(() {
        busy = false;
        // A failure envelope without a snapshot is not an empty school day.
        // Keep the original rows, date and verification time in that case.
        if (result.failure == null || result.stale) data = result;
        final failure = result.failure;
        readIssue = failure != null
            ? readFailureMessage(failure, result.failureDetail)
            : result.stale
            ? '签到状态尚未更新'
            : null;
      });
    } catch (_) {
      if (!mounted || serial != requestSerial) return;
      setState(() {
        busy = false;
        readIssue = failureMessage(null);
      });
    }
  }

  Future<void> openQr(CheckInCourse course) async {
    if (qrOpen ||
        !verified ||
        !data!.courses.contains(course) ||
        course.status != CheckInStatus.notSigned ||
        course.conflicting ||
        !(course.signInAllowed ?? course.mergedRecordCount == 1) ||
        widget.history ||
        !checkinWindowOpen(
          course,
          data?.date ?? dateString(schoolToday),
          instant,
        )) {
      return;
    }
    final generation = contextGeneration;
    final currentDate = data!.date;
    final parsedDate = DateTime.tryParse(currentDate);
    final dateLabel = parsedDate == null
        ? currentDate
        : schoolDateWeekdayLabel(parsedDate);
    qrOpen = true;
    try {
      await showGinkgoModalSheet<void>(
        context: context,
        builder: (_) => CheckinQrSheet(
          course: course,
          dateLabel: dateLabel,
          service: widget.service,
          platformActions: widget.platformActions,
          isContextValid: () =>
              mounted &&
              generation == contextGeneration &&
              !widget.history &&
              checkinWindowOpen(
                course,
                data?.date ?? currentDate,
                instant,
              ),
          onVerifySigned: () async {
            await load(force: true);
            if (!mounted || generation != contextGeneration) return false;
            final current = data;
            if (current == null || readIssue != null || current.stale) {
              return false;
            }
            return current.courses.any(
              (item) =>
                  item.id == course.id && item.status == CheckInStatus.signed,
            );
          },
        ),
      );
    } finally {
      if (generation == contextGeneration) qrOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('checkin-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: Text(widget.history ? '签到历史' : '课程签到'),
          section: '工作台',
          subtitle: '查看课程签到状态与实时签到码',
          icon: CupertinoIcons.checkmark_seal,
          border: null,
          trailing: AppleToolbarButton(
            label: '刷新签到状态',
            busy: busy,
            onPressed: busy ? null : retryRead,
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: retryRead),
        SliverList.list(
          children: [
            if (widget.history)
              AppleSection(
                children: [
                  Column(
                    children: [
                      AppleListTile(
                        key: const Key('checkin-date-picker'),
                        title: Text(dateString(selectedDate)),
                        trailing: const Icon(CupertinoIcons.calendar),
                        onTap: pickDate,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          CupertinoButton(
                            key: const Key('checkin-previous-day'),
                            onPressed: () => changeDate(
                              selectedDate.subtract(const Duration(days: 1)),
                            ),
                            child: const Text('前一天'),
                          ),
                          CupertinoButton(
                            key: const Key('checkin-next-day'),
                            onPressed: selectedDate.isBefore(schoolToday)
                                ? () => changeDate(
                                    selectedDate.add(const Duration(days: 1)),
                                  )
                                : null,
                            child: const Text('后一天'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              )
            else
              AppleSection(
                children: [
                  AppleListTile(
                    key: const Key('checkin-history'),
                    title: const Text('历史日期查询'),
                    leading: const GinkgoIconTile(
                      icon: CupertinoIcons.calendar,
                      size: GinkgoIconTokens.md,
                      iconSize: GinkgoIconTokens.glyphMd,
                      color: GinkgoColors.accent,
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => CheckInPage(
                          service: widget.service,
                          platformActions: widget.platformActions,
                          history: true,
                        ),
                      ),
                    ),
                  ),
                  if (range != null &&
                      data != null &&
                      data!.courses.isNotEmpty)
                    AppleListTile(
                      title: const Text('我的课程范围'),
                      leading: const GinkgoIconTile(
                        icon: CupertinoIcons.slider_horizontal_3,
                        size: GinkgoIconTokens.md,
                        iconSize: GinkgoIconTokens.glyphMd,
                        color: GinkgoColors.resourceBlue,
                      ),
                      subtitle: Text(
                        _hiddenCount(data!) == 0
                            ? '管理学生课程与助教 / 教师课程'
                            : '已收起 ${_hiddenCount(data!)} 节非个人课程',
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => CourseRangePage(
                            preferences: range!,
                            system: 'iclass',
                            courses: {
                              for (final item in data!.courses)
                                courseKey(item): item.courseName,
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (readIssue != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: readIssue!,
                    description: data == null
                        ? '尚未读到签到状态，不能判断是否有课。'
                        : data!.courses.isEmpty
                        ? '上次结果没有课程，本次尚未核实。'
                        : '正在显示上次结果，不能据此生成签到码。',
                    error: true,
                    action: '重试',
                    onAction: busy ? null : retryRead,
                  ),
                ],
              ),
            if (data == null && readIssue == null)
              CheckInLoading(
                isDemo: widget.service.isDemo,
                service: widget.service,
              ),
            if (data != null) ...[
              if (widget.history && data!.date != dateString(selectedDate))
                AppleSection(
                  children: [
                    AppleListTile(
                      title: Text('正在保留 ${data!.date} 的结果'),
                      subtitle: const Text('所选日期尚未读取成功，请重试；下方不是所选日期的数据。'),
                    ),
                  ],
                ),
              ..._content(data!),
            ],
            if (busy && data != null)
              Padding(
                key: const Key('checkin-refreshing'),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Semantics(
                    label: '正在刷新签到状态',
                    child: const GinkgoActivity(size: 17),
                  ),
                ),
              ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );

  int _hiddenCount(CheckInResponse source) => source.courses
      .where((course) => range?.hidden('iclass', courseKey(course)) ?? false)
      .length;

  List<Widget> _content(CheckInResponse data) {
    final original = data;
    final courses = original.courses
        .where(
          (course) => !(range?.hidden('iclass', courseKey(course)) ?? false),
        )
        .toList();
    data = CheckInResponse(
      date: original.date,
      courses: courses,
      fetchedAt: original.fetchedAt,
      fromCache: original.fromCache,
      stale: original.stale,
      failure: original.failure,
      failureDetail: original.failureDetail,
    );
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null ? data.date : schoolDateWeekdayLabel(date);
    final sessions = uniqueCheckinSessions(data.courses);
    final signed = sessions
        .where((course) => course.status == CheckInStatus.signed)
        .length;
    final unknown = sessions
        .where((course) => course.status == CheckInStatus.unknown)
        .length;
    final notSigned = sessions.length - signed - unknown;
    return [
      if (widget.history && range != null && original.courses.isNotEmpty)
        AppleSection(
          children: [
            AppleListTile(
              title: const Text('我的课程范围'),
              leading: const GinkgoIconTile(
                icon: CupertinoIcons.slider_horizontal_3,
                size: GinkgoIconTokens.md,
                iconSize: GinkgoIconTokens.glyphMd,
                color: GinkgoColors.resourceBlue,
              ),
              subtitle: Text(
                courses.length == original.courses.length
                    ? '管理学生课程与助教 / 教师课程'
                    : '已收起 ${original.courses.length - courses.length} 节非个人课程',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => CourseRangePage(
                    preferences: range!,
                    system: 'iclass',
                    courses: {
                      for (final item in original.courses)
                        courseKey(item): item.courseName,
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      if (courses.isEmpty &&
          readIssue == null &&
          (!widget.history || data.date == dateString(selectedDate)))
        AppleSection(
          header: Text(dateLabel),
          children: [
            AppleEmptyState(
              icon: CupertinoIcons.checkmark_shield,
              title: original.courses.isNotEmpty
                  ? '当前课程范围内没有课程'
                  : widget.history
                  ? '当天没有课程'
                  : '今天没有课程',
              description: original.courses.isNotEmpty
                  ? '课程已按你的本机范围收起，可在“我的课程范围”恢复。'
                  : widget.history
                  ? '该日期没有可查询课程，不代表出勤或缺勤。'
                  : '学校返回当天无课程，可以到课表确认其他教学周。',
            ),
          ],
        )
      else if (courses.isNotEmpty) ...[
        CheckinStatusSummary(
          dateLabel: dateLabel,
          scopeLabel: '${widget.history ? '当天' : '今天'} ${sessions.length} 节课',
          signed: signed,
          notSigned: notSigned,
          unknown: unknown,
          fetchedAt: data.fetchedAt,
        ),
        AppleSection(
          header: Text(widget.history ? '该日期课程' : '当天课程'),
          children: [
            for (final course in data.courses)
              CheckinCourseRow(
                course: course,
                windowOpen: checkinWindowOpen(course, data.date, instant),
                canSubmit:
                    !widget.history &&
                    course.status == CheckInStatus.notSigned &&
                    !course.conflicting &&
                    (course.signInAllowed ?? course.mergedRecordCount == 1),
                onSubmit: !verified ? null : () => openQr(course),
              ),
          ],
        ),
      ],
      AppleSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.service.isDemo
                  ? '演示模式仅展示合成签到码'
                  : '课前 10 分钟开放实时签到码，保存至相册后在智慧北航扫一扫完成签到。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
