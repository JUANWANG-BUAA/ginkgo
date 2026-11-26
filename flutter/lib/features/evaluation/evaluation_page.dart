import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/evaluation.dart';
import 'package:ginkgo_mirror/application/failure_code.dart';
import 'package:ginkgo_mirror/application/student_service_links.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/liquid_vial_gauge.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/school_links.dart';
import 'package:ginkgo_mirror/widgets/telemetry_instrument_card.dart';

class EvaluationPage extends StatefulWidget {
  const EvaluationPage({super.key, this.gateway, this.officialLinks});

  final TeachingEvaluationGateway? gateway;
  final StudentServiceLinksGateway? officialLinks;

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  TeachingEvaluationReport? _data;
  FailureCode? _failure;
  bool _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.gateway != null) {
      _load(forceRefresh: false);
    }
  }

  @override
  void didUpdateWidget(EvaluationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gateway, widget.gateway)) {
      _generation++;
      _data = null;
      _failure = null;
      _busy = false;
      if (widget.gateway != null) {
        _load(forceRefresh: false);
      }
    }
  }

  Future<void> _load({required bool forceRefresh}) async {
    final gateway = widget.gateway;
    if (_busy || gateway == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      if (_data == null) _failure = null;
    });
    TeachingEvaluationRead result;
    try {
      result = await gateway.loadTeachingEvaluation(forceRefresh: forceRefresh);
    } catch (_) {
      result = const TeachingEvaluationRead(
        failure: FailureCode.serviceUnavailable,
      );
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _failure = result.failure;
      if (result.data != null) {
        _data = result.data;
      } else if (result.failure == null) {
        _failure = FailureCode.changedResponse;
      }
    });
  }

  Future<void> _openOfficialEvaluation() async {
    final url = widget.officialLinks?.studentServiceUrl('official-evaluation');
    if (url == null || url.isEmpty) return;
    var opened = false;
    try {
      opened = await openSchoolLink(context, url);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) await showSchoolLinkError(context);
  }

  static Widget _statusChip(EvaluationCourseStatus status) => switch (status) {
    EvaluationCourseStatus.completed => const StatusChip.done(
      '已评教',
      compact: true,
    ),
    EvaluationCourseStatus.pending => const StatusChip.pending(
      '未评教',
      compact: true,
    ),
    EvaluationCourseStatus.unknown => const StatusChip.unknown(
      '待确认',
      compact: true,
    ),
  };

  static String _courseSubtitle(EvaluationCourseItem item) {
    final parts = <String>[];
    if (item.teacherName != null && item.teacherName!.isNotEmpty) {
      parts.add(item.teacherName!);
    }
    if (item.questionnaireName != null && item.questionnaireName!.isNotEmpty) {
      parts.add(item.questionnaireName!);
    } else if (item.category != null && item.category!.isNotEmpty) {
      parts.add(item.category!);
    }
    return parts.isEmpty ? '学校未提供授课教师与问卷分类' : parts.join(' · ');
  }

  List<TelemetryMeterData> _buildCategoryMeters(TeachingEvaluationReport data) {
    if (data.courses.isEmpty) {
      return const [
        TelemetryMeterData(label: '本学期任务', trailing: '0 门课程'),
        TelemetryMeterData(label: '提交方式', trailing: '仅官网操作'),
      ];
    }
    final grouped = <String, (int done, int total)>{};
    for (final c in data.courses) {
      final key =
          (c.questionnaireName?.isNotEmpty == true
              ? c.questionnaireName!
              : c.category?.isNotEmpty == true
              ? c.category!
              : '课程评教');
      final prev = grouped[key] ?? (0, 0);
      final done = prev.$1 + (c.status == EvaluationCourseStatus.completed ? 1 : 0);
      grouped[key] = (done, prev.$2 + 1);
    }
    final entries = grouped.entries.take(3).toList(growable: false);
    return [
      for (final e in entries)
        TelemetryMeterData(
          label: e.key,
          ratio: e.value.$2 > 0 ? e.value.$1 / e.value.$2 : 0.0,
          trailing:
              '${((e.value.$1 / e.value.$2) * 100).round()}% · ${e.value.$1}/${e.value.$2}',
          startColor: const Color(0xFF059669),
          endColor: const Color(0xFF34D399),
        ),
    ];
  }

  Widget _buildInstrument(TeachingEvaluationReport? data, FailureCode? failure) {
    final supported = widget.gateway != null;
    final total = data?.courses.length ?? 0;
    final done = data?.completedCount ?? 0;
    final pending = data?.pendingCount ?? 0;
    final hasCourses = data != null && total > 0;
    final doneRatio = hasCourses ? (done / total).clamp(0.0, 1.0) : null;
    final pendingRatio = hasCourses ? (pending / total).clamp(0.0, 1.0) : null;
    final donePct = doneRatio == null ? null : (doneRatio * 100).round();

    final (statusLabel, statusTone) = !supported
        ? ('暂不支持', StatusTone.uncertain)
        : _busy && data == null
        ? ('加载中', StatusTone.pending)
        : failure != null && data == null
        ? ('读取失败', StatusTone.danger)
        : data != null && pending > 0
        ? ('待完成 $pending 门', StatusTone.pending)
        : data != null
        ? ('全部完成', StatusTone.success)
        : ('待读取', StatusTone.uncertain);

    final vial = LiquidVialWell(
      code: 'EVAL',
      readout: donePct != null
          ? '$donePct%'
          : (data != null && total == 0 ? '100%' : '--'),
      fillRatio: doneRatio ?? (data != null && total == 0 ? 1.0 : null),
      palette: pending > 0 ? LiquidPalette.cobalt : LiquidPalette.emerald,
      scaleTicks: hasCourses
          ? [
              '- ${(total * 0.75).ceil()}门',
              '- ${(total * 0.50).ceil()}门',
              '- ${(total * 0.25).ceil()}门',
            ]
          : const ['- 75%', '- 50%', '- 25%'],
      footer: hasCourses ? '$done / $total 已评' : '评教',
      semanticLabel: '本学期课程评教完成比例',
    );

    if (data == null) {
      return TelemetryInstrumentCard(
        vial: vial,
        title: '本学期课程评教',
        statusLabel: statusLabel,
        statusTone: statusTone,
        headline: _busy ? '正在同步评教进度…' : '尚未加载评教任务',
        subheadline: '',
        meters: const [],
      );
    }

    return TelemetryInstrumentCard(
      vial: vial,
      title: data.term == null ? '本学期课程评教' : '课程评教 · ${data.term}',
      statusLabel: statusLabel,
      statusTone: statusTone,
      headline: hasCourses
          ? '$donePct% 已评 · 剩余 $pending 门'
          : '当前无待评课程',
      subheadline: hasCourses
          ? '已完成 $done 门 / 共 $total 门评教问卷'
          : '当前账号在本学期暂无待评教任务',
      segments: hasCourses
          ? [
              BarSegment(
                fraction: doneRatio!,
                startColor: const Color(0xFF059669),
                endColor: const Color(0xFF34D399),
              ),
              if (pendingRatio != null && pendingRatio > 0)
                BarSegment(
                  fraction: pendingRatio,
                  startColor: const Color(0xFFD97706),
                  endColor: const Color(0xFFFBBF24),
                ),
            ]
          : const [],
      barLeadingCaption: hasCourses ? '绿色已评 · 琥珀待评' : null,
      barTrailingCaption: hasCourses ? '$done / $total 门' : null,
      sectionTitle: hasCourses ? '分类进度' : null,
      sectionBadge: hasCourses ? (pending == 0 ? '已清零' : '进行中') : null,
      sectionBadgeTone: pending == 0 ? StatusTone.success : StatusTone.pending,
      meters: _buildCategoryMeters(data),
    );
  }

  static const Size _toolbarTapSize = Size(48, 48);

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final failure = _failure;
    final officialUrl = widget.officialLinks?.studentServiceUrl(
      'official-evaluation',
    );

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('课程评教'),
        trailing: widget.gateway == null
            ? null
            : CupertinoButton(
                key: const Key('evaluation-refresh'),
                padding: EdgeInsets.zero,
                minimumSize: _toolbarTapSize,
                onPressed: _busy ? null : () => _load(forceRefresh: true),
                child: _busy
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(
                        CupertinoIcons.refresh,
                        semanticLabel: '刷新评教状态',
                      ),
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _buildInstrument(data, failure),
            AppleSection(
              header: const Text('评教任务'),
              footer: data == null
                  ? null
                  : Text(
                      data.stale
                          ? '上次读取 ${schoolClockLabel(data.fetchedAt)}；当前展示旧快照。'
                          : '更新于 ${schoolClockLabel(data.fetchedAt)}',
                    ),
              children: [
                if (data?.taskName != null || data?.term != null)
                  AppleListTile(
                    leading: const GinkgoIconTile(
                      icon: CupertinoIcons.calendar,
                      size: 34,
                      iconSize: 18,
                      color: GinkgoColors.resourceTeal,
                    ),
                    leadingSize: 34,
                    title: Text(data?.taskName ?? '当前学期评教任务'),
                    subtitle: data?.term == null
                        ? null
                        : Text('学年学期 ${data!.term}'),
                  ),
                if (officialUrl != null && officialUrl.isNotEmpty)
                  AppleListTile(
                    key: const Key('evaluation-official-link'),
                    leading: const GinkgoIconTile(
                      icon: CupertinoIcons.globe,
                      size: 34,
                      iconSize: 18,
                      color: GinkgoColors.accent,
                    ),
                    leadingSize: 34,
                    title: const Text('前往学校评教系统'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _openOfficialEvaluation,
                  ),
                if (_busy)
                  SectionFeedback(
                    key: const Key('evaluation-feedback'),
                    loading: true,
                    label: '正在读取课程评教状态',
                    hasData: data != null,
                  )
                else if (failure != null)
                  SectionFeedback(
                    key: const Key('evaluation-feedback'),
                    loading: false,
                    label: '课程评教状态',
                    hasData: data != null,
                    error: failureMessage(failure),
                    onRetry: () => _load(forceRefresh: true),
                  ),
              ],
            ),
            if (widget.gateway == null)
              const AppleSection(
                children: [
                  AppleEmptyState(
                    title: '暂不支持查询',
                    description: '当前服务未提供课程评教状态查询能力。',
                    icon: CupertinoIcons.checkmark_rectangle,
                  ),
                ],
              )
            else if (data != null && data.courses.isEmpty)
              const AppleSection(
                header: Text('课程明细'),
                children: [
                  AppleEmptyState(
                    key: Key('evaluation-empty-confirmed'),
                    title: '当前暂无待评教任务',
                    description: '学校评教系统未返回当前学期的评教课程。',
                    icon: CupertinoIcons.checkmark_seal,
                  ),
                ],
              )
            else if (data != null)
              AppleSection(
                header: const Text('课程明细'),
                children: [
                  for (final course in data.courses)
                    AppleListTile(
                      key: ValueKey('eval-course-${course.id}'),
                      leading: GinkgoIconTile(
                        icon: course.status == EvaluationCourseStatus.completed
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.doc_checkmark,
                        size: 34,
                        iconSize: 18,
                        color: course.status == EvaluationCourseStatus.completed
                            ? GinkgoColors.accent
                            : GinkgoColors.resourceBlue,
                      ),
                      leadingSize: 34,
                      title: Text(course.courseName),
                      subtitle: Text(_courseSubtitle(course)),
                      trailing: _statusChip(course.status),
                    ),
                ],
              ),
            const SizedBox(height: GinkgoSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
