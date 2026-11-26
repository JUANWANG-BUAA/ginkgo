import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'today_action_row.dart';
import 'today_presentation.dart';

class TodayExamSection extends StatefulWidget {
  const TodayExamSection({
    super.key,
    required this.service,
    required this.now,
    this.refreshToken = 0,
    this.onOpen,
    this.onVisibilityChanged,
    this.onWeekNumberChanged,
  });

  final MirrorService service;
  final DateTime now;
  final int refreshToken;
  final ValueChanged<String>? onOpen;
  final ValueChanged<bool>? onVisibilityChanged;
  final ValueChanged<int?>? onWeekNumberChanged;

  @override
  State<TodayExamSection> createState() => _TodayExamSectionState();
}

class _TodayExamSectionState extends State<TodayExamSection> {
  late RefreshSection<ScheduleResponse> exams;
  bool _lastVisible = false;
  int? _lastWeekNumber;

  @override
  void initState() {
    super.initState();
    _create();
    _load();
  }

  void _create() {
    exams = RefreshSection<ScheduleResponse>()..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    _notifyVisibility();
    _notifyWeekNumber();
    setState(() {});
  }

  void _notifyWeekNumber() {
    final week = exams.value?.weekNumber;
    final normalized = (week != null && week > 0) ? week : null;
    if (normalized == _lastWeekNumber) return;
    _lastWeekNumber = normalized;
    final callback = widget.onWeekNumberChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(_lastWeekNumber);
    });
  }

  bool _isVisible() {
    final data = exams.value;
    if (data == null) return exams.loading || exams.error != null;
    if (exams.error != null) return true;
    final today = DateTime.utc(
      widget.now.year,
      widget.now.month,
      widget.now.day,
    );
    return data.exams.any((exam) {
      final day = exam.examDate == null ? null : todayDate(exam.examDate!);
      return day == null || !day.isBefore(today);
    });
  }

  void _notifyVisibility() {
    final visible = _isVisible();
    if (visible == _lastVisible) return;
    _lastVisible = visible;
    final callback = widget.onVisibilityChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(_lastVisible);
    });
  }

  @override
  void didUpdateWidget(TodayExamSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      exams.dispose();
      _create();
      _load();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      _load(force: true);
    }
  }

  Future<void> _load({bool force = false}) => exams.refresh(
    () async {
      final result = await widget.service.schedule(forceRefresh: force);
      return SectionResult(
        value: result.failure == null || result.fetchedAt != null
            ? result
            : null,
        error: result.failure == null ? null : failureMessage(result.failure),
      );
    },
    fallbackError: '考试安排暂不可用',
    force: force,
  );

  @override
  void dispose() {
    exams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = exams.value;
    if (data == null) {
      if (!exams.loading && exams.error == null) {
        return const SizedBox.shrink();
      }
      return TodayVisualSection(
        key: const Key('today-exams'),
        header: TodaySectionHeader(
          title: '近期考试',
          icon: CupertinoIcons.calendar,
          actionLabel: exams.error == null ? null : '课表',
          onAction: widget.onOpen == null
              ? null
              : () => widget.onOpen!('schedule'),
        ),
        children: [
          SectionFeedback(
            loading: exams.loading,
            label: '正在核对考试安排…',
            hasData: false,
            error: exams.error,
            onRetry: () => _load(force: true),
          ),
        ],
      );
    }
    final today = DateTime.utc(
      widget.now.year,
      widget.now.month,
      widget.now.day,
    );
    final upcoming =
        data.exams.where((exam) {
          final day = exam.examDate == null ? null : todayDate(exam.examDate!);
          return day == null || !day.isBefore(today);
        }).toList()..sort((left, right) {
          final dateOrder = (left.examDate ?? '').compareTo(
            right.examDate ?? '',
          );
          if (dateOrder != 0) return dateOrder;
          final timeOrder = (left.startTime ?? '').compareTo(
            right.startTime ?? '',
          );
          return timeOrder != 0 ? timeOrder : left.id.compareTo(right.id);
        });
    if (upcoming.isEmpty && exams.error == null) {
      return const SizedBox.shrink();
    }
    return TodayVisualSection(
      key: const Key('today-exams'),
      header: TodaySectionHeader(
        title: '近期考试',
        icon: CupertinoIcons.calendar,
        badge: '${upcoming.length} 场',
        actionLabel: '课表',
        onAction: widget.onOpen == null
            ? null
            : () => widget.onOpen!('schedule'),
      ),
      children: [
        for (final (index, exam) in upcoming.take(3).indexed) ...[
          if (index > 0) const TodayVisualDivider(),
          GinkgoProgressiveRow(
            key: Key('today-exam-${exam.id}'),
            emphasized: index == 0,
            title: exam.courseName,
            subtitle:
                '${exams.error == null ? '' : '旧数据 · '}${exam.examPlace ?? '地点待确认'}',
            badgeLabel: _examCountdownLabel(exam.examDate, today),
            badgeIcon: CupertinoIcons.calendar,
            meta: '${exam.examDate ?? '日期待确认'} ${exam.startTime ?? '时间待确认'}',
            accent: _examTint(exam.examDate, today),
            onTap: widget.onOpen == null
                ? null
                : () => widget.onOpen!('schedule'),
          ),
        ],
        if (upcoming.length > 3) ...[
          const TodayVisualDivider(),
          TodayActionRow(
            summary: true,
            title: '另有 ${upcoming.length - 3} 场考试',
            onTap: widget.onOpen == null
                ? null
                : () => widget.onOpen!('schedule'),
          ),
        ],
        if (exams.error != null)
          SectionFeedback(
            loading: exams.loading,
            label: '正在更新考试安排…',
            hasData: true,
            quietWhenRefreshing: true,
            error: exams.error,
            onRetry: () => _load(force: true),
          ),
      ],
    );
  }

  String _examCountdownLabel(String? rawDate, DateTime today) {
    final day = rawDate == null ? null : todayDate(rawDate);
    if (day == null) return '日期待确认';
    final diff = day.difference(today).inDays;
    if (diff <= 0) return '今天';
    if (diff == 1) return '明天';
    return '$diff 天后';
  }

  Color _examTint(String? rawDate, DateTime today) {
    final day = rawDate == null ? null : todayDate(rawDate);
    if (day == null) return AppleDesign.statusUncertain;
    final diff = day.difference(today).inDays;
    if (diff <= 2) return GinkgoColors.statusDanger;
    if (diff <= 7) return AppleDesign.statusPending;
    return GinkgoColors.resourceBlue;
  }
}
