import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'src/rust/api/live.dart' as live;

class GraduatePage extends StatefulWidget {
  const GraduatePage({super.key, this.demo = false});
  final bool demo;
  @override
  State<GraduatePage> createState() => _GraduatePageState();
}

class _GraduatePageState extends State<GraduatePage> {
  List<Map<String, dynamic>>? sections;
  String? error, notice;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = widget.demo
          ? await live.loadDemoGraduate()
          : await live.loadGraduate(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) {
          final payload = jsonDecode(result.payload!) as Map<String, dynamic>;
          sections = (payload['sections'] as List).cast<Map<String, dynamic>>();
          notice = payload['notice'] as String?;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failureMessage(null);
        });
      }
    }
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
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: sections == null ? '请稍后重试。' : '正在显示上次结果。',
                    action: '重试',
                    onAction: () => load(force: true),
                    error: true,
                  ),
                ],
              ),
            if (sections == null && busy)
              const AppleSection(
                children: [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: CupertinoActivityIndicator(),
                  ),
                ],
              ),
            if (notice != null)
              AppleSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(notice!),
                  ),
                ],
              ),
            if (sections != null) ...[
              for (final section in sections!)
                AppleSection(
                  header: Text(section['title'] as String),
                  children: [
                    for (final row
                        in (section['rows'] as List)
                            .cast<Map<String, dynamic>>())
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                row['detail'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.demo ? '离线合成样例' : '学籍与课程学习只读信息；待考核学分不抵扣毕业缺口。',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ],
    ),
  );
}
