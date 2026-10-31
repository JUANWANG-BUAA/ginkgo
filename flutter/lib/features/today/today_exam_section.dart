import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
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
  });

  final MirrorService service;
  final DateTime now;
  final int refreshToken;
  final ValueChanged<String>? onOpen;

  @override
  State<TodayExamSection> createState() => _TodayExamSectionState();
}

class _TodayExamSectionState extends State<TodayExamSection> {
  late RefreshSection<ScheduleResponse> exams;

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
    if (mounted) setState(() {});
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
        actionLabel: '课表',
        onAction: widget.onOpen == null
            ? null
            : () => widget.onOpen!('schedule'),
      ),
      footer: data.fetchedAt == null
          ? const Text('学校考试安排')
          : Text('考试同步：${schoolTimestampLabel(data.fetchedAt)}'),
      children: [
        for (final exam in upcoming.take(3))
          TodayActionRow(
            key: Key('today-exam-${exam.id}'),
            title: exam.courseName,
            subtitle:
                '${exams.error == null ? '' : '旧数据 · '}${exam.examDate ?? '日期待确认'} ${exam.startTime ?? '时间待确认'} · ${exam.examPlace ?? '地点待确认'}',
            onTap: widget.onOpen == null
                ? null
                : () => widget.onOpen!('schedule'),
          ),
        if (upcoming.length > 3)
          TodayActionRow(
            summary: true,
            title: '另有 ${upcoming.length - 3} 场考试',
            onTap: widget.onOpen == null
                ? null
                : () => widget.onOpen!('schedule'),
          ),
        if (exams.error != null)
          SectionFeedback(
            loading: exams.loading,
            label: '正在更新考试安排…',
            hasData: true,
            error: exams.error,
            onRetry: () => _load(force: true),
          ),
      ],
    );
  }
}
