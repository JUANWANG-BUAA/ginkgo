import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/mirror.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  HomeworkResponse? data;
  String? error;
  bool busy = false;
  int filter = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.homework();
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        data = result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('homework-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('作业'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新作业',
            onPressed: busy ? null : load,
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '请检查网络后重试。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
              )
            else if (busy || data == null)
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取作业…'),
                      ],
                    ),
                  ),
                ],
              )
            else
              ..._content(data!),
          ],
        ),
      ],
    ),
  );

  List<Widget> _content(HomeworkResponse data) {
    final pending = data.items
        .where((item) => item.status == HomeworkStatus.pending)
        .length;
    final submitted = data.items
        .where((item) => item.status == HomeworkStatus.submitted)
        .length;
    final visible = data.items.where((item) {
      if (filter == 1) return item.status == HomeworkStatus.pending;
      if (filter == 2) return item.status == HomeworkStatus.submitted;
      return true;
    }).toList();
    return [
      AppleSection(
        header: Text(
          [
            data.termName,
            data.termCode,
          ].where((value) => value.isNotEmpty).join(' · '),
        ),
        footer: const Text('只读作业列表；不包含提交、附件上传或评分写操作。'),
        children: [
          AppleListTile(
            title: const Text('待完成 / 已提交'),
            additionalInfo: Text('$pending / $submitted'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: filter,
              onValueChanged: (value) => setState(() => filter = value ?? 0),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('全部'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '待完成',
                    key: Key('homework-filter-pending'),
                  ),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '已提交',
                    key: Key('homework-filter-submitted'),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
      if (visible.isEmpty)
        AppleSection(
          children: const [
            AppleEmptyState(title: '没有符合条件的作业', description: '切换筛选或稍后刷新。'),
          ],
        )
      else
        AppleSection(
          header: Text('${visible.length} 项作业'),
          children: [
            for (final item in visible)
              AppleListTile(
                key: Key('homework-${item.id}'),
                minimumHeight: 68,
                title: Text(item.title),
                subtitle: Text(_subtitle(item)),
                additionalInfo: _statusBadge(context, item),
              ),
          ],
        ),
      AppleSection(
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '离线合成样例，不连接学校账号；状态与时间用于演示 SPOC 迁移后的列表。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  String _subtitle(HomeworkItem item) {
    final parts = [item.courseName];
    if (item.publishedAt != null) parts.add('发布 ${_format(item.publishedAt!)}');
    if (item.dueAt != null) parts.add('截止 ${_format(item.dueAt!)}');
    if (item.score != null) parts.add('${item.score} 分');
    return parts.join(' · ');
  }

  Widget _statusBadge(BuildContext context, HomeworkItem item) {
    final (label, color) = switch (item.status) {
      HomeworkStatus.submitted => ('已提交', const Color(0xFF189840)),
      HomeworkStatus.pending =>
        _isOverdue(item.dueAt)
            ? ('已截止', const Color(0xFFC62828))
            : ('待完成', const Color(0xFFB26A00)),
      HomeworkStatus.unknown => ('待确认', const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  bool _isOverdue(String? due) {
    final date = due == null ? null : DateTime.tryParse(due);
    return date != null && date.isBefore(DateTime.now());
  }
}

String _format(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
