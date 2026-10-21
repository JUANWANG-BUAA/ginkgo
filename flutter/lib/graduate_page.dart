import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'src/rust/api/live.dart' as live;

typedef GraduateLoader = Future<live.ReadOnlyResponse> Function({
  required bool report,
  required bool forceRefresh,
});

class GraduatePage extends StatefulWidget {
  const GraduatePage({super.key, this.demo = false, this.loader});
  final bool demo;
  final GraduateLoader? loader;
  @override
  State<GraduatePage> createState() => _GraduatePageState();
}

class _AcademicPart {
  List<Map<String, dynamic>>? sections;
  String? error, notice;
  Future<void>? task;
  bool loading = false;
}

class _GraduatePageState extends State<GraduatePage> {
  final status = _AcademicPart(), report = _AcademicPart();
  bool get busy => status.loading || report.loading;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) => Future.wait([
    _loadPart(status, force: force),
    _loadPart(report, force: force),
  ]);

  Future<void> _loadPart(_AcademicPart part, {bool force = false}) =>
      part.task ??= _fetchPart(
        part,
        force: force,
      ).whenComplete(() => part.task = null);

  Future<void> _fetchPart(_AcademicPart part, {required bool force}) async {
    setState(() {
      part.loading = true;
      part.error = null;
    });
    try {
      final isReport = identical(part, report);
      final result = widget.loader != null
          ? await widget.loader!(report: isReport, forceRefresh: force)
          : widget.demo
          ? (isReport
                ? await live.loadDemoGraduate()
                : await live.loadDemoGraduateStatus())
          : await live.loadGraduatePart(report: isReport, forceRefresh: force);
      // Decode once on data change, never sort or parse inside build.
      final payload = result.payload == null
          ? null
          : jsonDecode(result.payload!) as Map<String, dynamic>;
      final sections = (payload?['sections'] as List?)
          ?.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        part.error = result.failure == null
            ? null
            : failureMessage(result.failure);
        if (sections != null) {
          part.sections = sections;
          part.notice = payload?['notice'] as String?;
        }
      });
    } catch (_) {
      if (mounted) setState(() => part.error = failureMessage(null));
    } finally {
      if (mounted) setState(() => part.loading = false);
    }
  }

  Widget _partStatus(_AcademicPart part, String title) => AppleSection(
    header: Text(title),
    children: [
      AppleListTile(
        leading: part.loading
            ? const CupertinoActivityIndicator()
            : const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemOrange,
              ),
        title: Text(
          part.loading
              ? (part.sections == null ? '正在加载…' : '正在更新…')
              : part.error!,
        ),
        subtitle: part.sections == null ? null : const Text('保留上次结果'),
        trailing: part.loading
            ? null
            : CupertinoButton(
                onPressed: () => _loadPart(part, force: true),
                child: const Text('重试'),
              ),
      ),
    ],
  );

  List<Widget> _part(_AcademicPart part, String title) => [
    if (part.loading || part.error != null) _partStatus(part, title),
    if (part.notice != null)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          part.notice!,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 14,
          ),
        ),
      ),
    for (final section in part.sections ?? <Map<String, dynamic>>[])
      _section(section),
  ];

  Widget _section(Map<String, dynamic> section) {
    final progress = section['progress'] as Map<String, dynamic>?;
    return AppleSection(
      header: Text(section['title'] as String),
      children: [
        if (progress != null) GraduateCreditProgress(progress: progress),
        for (final row in section['rows'] as List)
          AppleListTile(
            leading: row['completed'] == null
                ? null
                : Icon(
                    row['completed'] == true
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: row['completed'] == true
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                    size: 23,
                  ),
            title: Text(row['title'] as String),
            subtitle: Text(row['detail'] as String),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('graduate-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('研究生教务'),
          previousPageTitle: '工作台',
          border: null,
          trailing: AppleGlassButton(
            label: '刷新研究生教务',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            ..._part(report, '培养方案执行报告'),
            ..._part(status, '学籍信息'),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '待考核学分不计入已获学分。',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ],
    ),
  );
}

/// Uses typed numeric credits from Rust. Pending credits are displayed separately
/// and never contribute to the earned bar or reduce the remaining requirement.
class GraduateCreditProgress extends StatelessWidget {
  const GraduateCreditProgress({super.key, required this.progress});
  final Map<String, dynamic> progress;
  String _format(num? value) => value == null
      ? '未确认'
      : value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  @override
  Widget build(BuildContext context) {
    final required = progress['required'] as num?;
    final earned = progress['earned'] as num?;
    final pending = progress['pending'] as num?;
    final ratio = required != null && required > 0 && earned != null
        ? (earned / required).clamp(0.0, 1.0)
        : null;
    final remaining = required == null || earned == null
        ? null
        : (required - earned).clamp(0, double.infinity);
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                _format(earned),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: green,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ ${_format(required)} 学分',
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ratio != null)
            Semantics(
              label: '已获学分进度',
              value: '${(ratio * 100).round()}%',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: ColoredBox(
                            color: green,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              required == 0 ? '本项无最低学分要求' : '学分信息不完整',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                '待考核 ${_format(pending)}',
                style: TextStyle(
                  color: CupertinoColors.systemOrange.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '尚需 ${_format(remaining)}',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
