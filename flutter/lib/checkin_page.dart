import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/mirror.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// Confirmed per-course submission with a subsequent status read.
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, required this.service, this.history = false});
  final MirrorService service;
  final bool history;
  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  CheckInResponse? data;
  String? error;
  String? notice;
  bool busy = false;
  String? submitting;
  final Set<String> awaitingVerification = {};
  int requestSerial = 0;
  late DateTime selectedDate;
  DateTime get schoolToday {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime(now.year, now.month, now.day);
  }

  String dateString(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
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
    load();
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
        awaitingVerification.contains(course.id)) {
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认签到？'),
        content: Text(
          '${course.courseName}\n${course.beginsAt}–${course.endsAt}\n${course.classroomName ?? ""}',
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
        CupertinoSliverNavigationBar(
          largeTitle: Text(widget.history ? '签到历史' : '课程签到'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新签到状态',
            onPressed: busy || submitting != null
                ? null
                : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
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
                      color: CupertinoColors.systemOrange,
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
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取 iclass 课程…'),
                      ],
                    ),
                  ),
                ],
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );

  List<Widget> _content(CheckInResponse data) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null
        ? data.date
        : '${date.year}年${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';
    final signed = data.courses
        .where((course) => course.status == CheckInStatus.signed)
        .length;
    final unknown = data.courses
        .where((course) => course.status == CheckInStatus.unknown)
        .length;
    final notSigned = data.courses.length - signed - unknown;
    return [
      AppleSection(
        header: Text(dateLabel),
        children: [
          AppleListTile(
            title: Text(
              data.courses.isEmpty
                  ? (widget.history ? '当天没有课程' : '今天没有课程')
                  : '${widget.history ? '当天' : '今天'} ${data.courses.length} 节课',
            ),
            subtitle: Text(
              data.courses.isEmpty
                  ? '学校返回当天无课程，不代表出勤或缺勤。'
                  : [
                      '已签到 $signed',
                      '未签到 $notSigned',
                      if (unknown > 0) '待确认 $unknown',
                    ].join(' · '),
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            additionalInfo: Text(
              _fetchedLabel(data.fetchedAt),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
      if (data.courses.isEmpty)
        AppleSection(
          children: [
            AppleEmptyState(
              title: widget.history ? '当天没有课程' : '今天没有课程',
              description: widget.history
                  ? '该日期没有可查询课程，不代表出勤或缺勤。'
                  : '可以到课表确认其他教学周，或稍后下拉刷新。',
            ),
          ],
        )
      else
        AppleSection(
          header: Text(widget.history ? '该日期课程' : '当天课程'),
          footer: const Text('来源：iclass。记录不一致时需先核实。'),
          children: [for (final course in data.courses) _courseRow(course)],
        ),
      AppleSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.service.isDemo ? '演示模式不会提交签到' : '签到后将自动刷新学校状态。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _courseRow(CheckInCourse course) {
    final (icon, color, label) = switch (course.status) {
      CheckInStatus.signed => (
        CupertinoIcons.checkmark_circle_fill,
        CupertinoColors.systemGreen,
        '已签到',
      ),
      CheckInStatus.notSigned => (
        CupertinoIcons.circle,
        CupertinoColors.tertiaryLabel,
        '未签到',
      ),
      CheckInStatus.unknown => (
        CupertinoIcons.question_circle_fill,
        CupertinoColors.systemOrange,
        '待确认',
      ),
    };
    final details = [
      '${course.beginsAt}–${course.endsAt}',
      if (course.classroomName != null) course.classroomName!,
      if (course.teacherName != null) course.teacherName!,
    ];
    final canSubmit =
        !widget.history &&
        course.status == CheckInStatus.notSigned &&
        !course.conflicting;
    return Padding(
      key: Key('checkin-course-${course.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, size: 25, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  course.courseName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            details.join(' · '),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (course.conflicting)
                const Text(
                  '记录不一致',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemOrange,
                  ),
                ),
              if (canSubmit)
                CupertinoButton.tinted(
                  key: Key('checkin-submit-${course.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  onPressed:
                      submitting != null ||
                          busy ||
                          awaitingVerification.contains(course.id)
                      ? null
                      : () => submit(course),
                  child: submitting == course.id
                      ? const CupertinoActivityIndicator()
                      : Text(
                          awaitingVerification.contains(course.id)
                              ? '待核实'
                              : '签到',
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The bridge sends Asia/Shanghai RFC 3339 timestamps; keep the school clock
  /// rather than the device time zone.
  String _fetchedLabel(String? fetchedAt) {
    if (fetchedAt == null) return '';
    final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(fetchedAt);
    if (match == null) return '';
    return '核对 ${match.group(1)}:${match.group(2)}';
  }
}
