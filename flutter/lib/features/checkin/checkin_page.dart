import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/shared/checkin_sessions.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';
import 'package:ginkgo_mirror/shared/reminders.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_loading.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/features/schedule/course_range_page.dart';

/// Confirmed per-course submission with a subsequent status read.
class CheckInPage extends StatefulWidget {
  const CheckInPage({
    super.key,
    required this.service,
    this.history = false,
    this.clock,
  });
  final CheckInGateway service;
  final bool history;
  final DateTime Function()? clock;
  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  Timer? windowTick;
  CheckInResponse? data;
  String? error;
  String? notice;
  bool busy = false;
  CourseVisibility? range;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    range = CourseVisibilityScope.of(context);
  }

  String courseKey(CheckInCourse course) =>
      course.courseId ?? course.courseNum ?? course.id;
  String? submitting;
  final Set<String> awaitingVerification = {};
  int requestSerial = 0;
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
      requestSerial++;
      data = null;
      error = null;
      notice = null;
      busy = false;
      submitting = null;
      awaitingVerification.clear();
      load();
    }
  }

  @override
  void dispose() {
    windowTick?.cancel();
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    final serial = ++requestSerial;
    final requested = dateString(selectedDate);
    setState(() {
      busy = true;
      error = null;
      if (submitting == null) notice = null;
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
      if (result.failure == null && !result.stale) {
        for (final course in result.courses) {
          if (course.status == CheckInStatus.signed) {
            awaitingVerification.remove(course.id);
          }
        }
      }
      setState(() {
        busy = false;
        if (result.failure != null && !result.stale) {
          error = failureMessage(result.failure);
          notice = null;
          return;
        }
        data = result;
        error = null;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted || serial != requestSerial) return;
      setState(() {
        busy = false;
        if (data == null) {
          error = failureMessage(null);
        } else {
          notice = '${failureMessage(null)}，正在显示上次结果。';
        }
      });
    }
  }

  Future<void> submit(CheckInCourse course) async {
    if (submitting != null ||
        busy ||
        widget.history ||
        awaitingVerification.contains(course.id) ||
        !checkinWindowOpen(
          course,
          data?.date ?? dateString(schoolToday),
          instant,
        )) {
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认签到？'),
        content: Text(
          '${course.courseName}\n${data?.date ?? dateString(schoolToday)}\n'
          '${schoolTimeRange(course.beginsAt, course.endsAt)}\n'
          '${course.classroomName ?? ""}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认签到'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || submitting != null) return;
    setState(() {
      submitting = course.id;
      awaitingVerification.add(course.id);
    });
    var message = '提交结果待确认，请刷新状态核实，勿重复提交';
    try {
      final response = await widget.service.submitCheckin(course.id);
      message = response.message;
      if (response.state == 'notSubmitted' || response.state == 'rejected') {
        awaitingVerification.remove(course.id);
      }
    } catch (_) {
      // The Dart exception cannot prove that the server did not receive the write.
    }
    if (!mounted) return;
    setState(() => notice = message);
    await load(force: true);
    if (!mounted) return;
    setState(() {
      submitting = null;
      notice = message;
    });
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
          subtitle: '查看课程签到状态与记录',
          icon: CupertinoIcons.checkmark_seal,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新签到状态',
            onPressed: busy || submitting != null
                ? null
                : () => load(force: true),
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            if (widget.history)
              AppleSection(
                footer: const Text('按日期查询；未签到和无课程均不自动判定为缺勤。'),
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
                    leading: const Icon(CupertinoIcons.calendar),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) =>
                            CheckInPage(service: widget.service, history: true),
                      ),
                    ),
                  ),
                ],
              ),
            if (notice != null)
              AppleSection(
                children: [
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: AppleDesign.statusPending,
                      size: 20,
                    ),
                    title: Text(notice!),
                  ),
                ],
              ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '请检查网络后重试；已确认的旧状态会保留。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
                  ),
                ],
              ),
            if (data == null && error == null)
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
      if (range != null && original.courses.isNotEmpty)
        AppleSection(
          children: [
            AppleListTile(
              title: const Text('我的课程范围'),
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
      if (data.courses.isEmpty)
        AppleSection(
          header: Text(dateLabel),
          children: [
            AppleEmptyState(
              icon: CupertinoIcons.checkmark_shield,
              title: widget.history ? '当天没有课程' : '今天没有课程',
              description: widget.history
                  ? '该日期没有可查询课程，不代表出勤或缺勤。'
                  : (original.courses.isNotEmpty
                        ? '课程已按你的本机范围收起，可在“我的课程范围”恢复。'
                        : '学校返回当天无课程，可以到课表确认其他教学周。'),
            ),
          ],
        )
      else ...[
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
          footer: const Text('来源：iclass。记录不一致时需先核实。'),
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
                submitting: submitting,
                awaitingVerification: awaitingVerification.contains(course.id),
                onSubmit: busy || awaitingVerification.contains(course.id)
                    ? null
                    : () => submit(course),
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
                  ? '演示模式不会提交签到'
                  : '课前 10 分钟开放，课程结束后关闭。每节课提醒一次，须手动确认签到。',
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
