import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/live.dart' show HomeworkDetailResponse;
import 'src/rust/api/mirror.dart';

class HomeworkDetailPage extends StatefulWidget {
  const HomeworkDetailPage({
    super.key,
    required this.item,
    required this.service,
  });
  final HomeworkItem item;
  final MirrorService service;
  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  HomeworkDetailResponse? data;
  String? error;
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
      final result = await widget.service.homeworkDetail(
        widget.item.id.replaceFirst('spoc:', ''),
        forceRefresh: force,
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null && !result.stale) {
          error = failureMessage(result.failure);
        } else {
          data = result;
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
    navigationBar: CupertinoNavigationBar(
      middle: const Text('作业详情'),
      previousPageTitle: '作业',
      trailing: AppleGlassButton(
        label: '刷新作业详情',
        onPressed: busy ? null : () => load(force: true),
        child: busy
            ? const CupertinoActivityIndicator()
            : const Icon(CupertinoIcons.refresh),
      ),
    ),
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              widget.item.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          AppleSection(children: [_field('课程', widget.item.courseName)]),
          if (error != null)
            AppleSection(
              children: [
                AppleEmptyState(
                  title: error!,
                  description: data == null ? '请检查网络后重试。' : '正在保留上次详情。',
                  error: true,
                  action: '重试',
                  onAction: () => load(force: true),
                ),
              ],
            ),
          if (data == null && busy)
            const AppleSection(
              children: [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: CupertinoActivityIndicator(),
                ),
              ],
            ),
          if (data case final detail?) ...[
            if (detail.stale)
              AppleSection(
                children: [_field('上次结果', failureMessage(detail.failure))],
              ),
            AppleSection(
              children: [
                _field('提交状态', detail.status),
                _field('发布时间', detail.publishedAt ?? '未确认'),
                _field('截止时间', detail.dueAt ?? '未确认'),
                _field('提交时间', detail.submittedAt ?? '未确认'),
                _field('分值', detail.score ?? '未确认'),
              ],
            ),
            AppleSection(
              header: const Text('作业说明'),
              children: [
                _field('正文', detail.content ?? '上游未返回正文，请在 SPOC 原站点查看。'),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    ),
  );
}
