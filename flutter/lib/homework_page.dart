import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'homework_detail_page.dart';
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
  String? notice;
  bool busy = false;
  int filter = 0;
  int pending = 0, submitted = 0, overdue = 0, unknown = 0;
  String search = '';
  List<HomeworkItem> visible = [];

  void prepare() {
    final items = data?.items ?? <HomeworkItem>[];
    pending = items
        .where((item) => item.status == HomeworkStatus.pending)
        .length;
    submitted = items
        .where((item) => item.status == HomeworkStatus.submitted)
        .length;
    overdue = items
        .where(
          (item) =>
              item.status == HomeworkStatus.pending && _isOverdue(item.dueAt),
        )
        .length;
    unknown = items
        .where((item) => item.status == HomeworkStatus.unknown)
        .length;
    final query = search.trim().toLowerCase();
    visible = items
        .where(
          (item) =>
              filter == 0 ||
              (filter == 1 && item.status == HomeworkStatus.pending) ||
              (filter == 2 && item.status == HomeworkStatus.submitted) ||
              (filter == 3 &&
                  item.status == HomeworkStatus.pending &&
                  _isOverdue(item.dueAt)) ||
              (filter == 4 && item.status == HomeworkStatus.unknown),
        )
        .where(
          (item) =>
              query.isEmpty ||
              [
                item.title,
                item.courseName,
                item.teacherName ?? "",
              ].any((s) => s.toLowerCase().contains(query)),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.service.homework(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) {
          if (data == null && result.termCode.isEmpty) {
            error = failureMessage(result.failure);
            return;
          }
          notice = '${failureMessage(result.failure)}，正在显示上次结果。';
          if (result.termCode.isEmpty) return;
        }
        data = result;
        prepare();
      });
    } catch (_) {
      if (!mounted) return;
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
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            if (notice != null)
              AppleSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      notice!,
                      style: TextStyle(
                        color: CupertinoColors.systemOrange.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '请检查网络后重试。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
                  ),
                ],
              )
            else if (data == null)
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
    return [
      AppleSection(
        header: Text(
          [
            data.termName,
            data.termCode,
          ].where((value) => value.isNotEmpty).join(' · '),
        ),

        children: [
          AppleListTile(
            title: const Text('待完成 / 已提交'),
            additionalInfo: Text(
              '$pending / $submitted',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: filter <= 2 ? filter : null,
              onValueChanged: (value) => setState(() {
                filter = value ?? 0;
                prepare();
              }),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('全部'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('待完成', key: Key('homework-filter-pending')),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('已提交', key: Key('homework-filter-submitted')),
                ),
              },
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: CupertinoSearchTextField(
          key: const Key('homework-search'),
          placeholder: '搜索作业、课程或教师',
          onChanged: (value) => setState(() {
            search = value;
            prepare();
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickFilter(3, '已截止 $overdue', CupertinoColors.systemOrange),
            _quickFilter(4, '待确认 $unknown', CupertinoColors.secondaryLabel),
          ],
        ),
      ),
      if (visible.isEmpty)
        AppleSection(
          children: [
            AppleEmptyState(
              title: search.trim().isEmpty ? '没有符合条件的作业' : '没有匹配的作业',
              description: '切换筛选或修改关键词。',
            ),
          ],
        )
      else
        AppleContentTransition(
          identity: (filter, search, data),
          child: AppleSection(
            header: Text('${visible.length} 项作业'),
            children: [
              for (final item in visible)
                AppleListTile(
                  key: Key('homework-${item.id}'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => HomeworkDetailPage(
                        item: item,
                        service: widget.service,
                      ),
                    ),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  minimumHeight: 112,
                  leading: Container(
                    width: 4,
                    height: 64,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemIndigo.resolveFrom(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(item.courseName),
                      if (item.teacherName != null) Text(item.teacherName!),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _statusBadge(context, item),
                          Text(
                            item.dueAt == null
                                ? '截止时间未确认'
                                : '截止 ${_format(item.dueAt!)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      AppleSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.service.isDemo ? '演示数据' : '来源：SPOC',
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

  Widget _quickFilter(int value, String label, CupertinoDynamicColor tint) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: tint
            .resolveFrom(context)
            .withValues(alpha: filter == value ? 0.2 : 0.08),
        minimumSize: const Size(44, 44),
        onPressed: () => setState(() {
          filter = filter == value ? 0 : value;
          prepare();
        }),
        child: Text(
          label,
          style: TextStyle(fontSize: 14, color: tint.resolveFrom(context)),
        ),
      );

  Widget _statusBadge(BuildContext context, HomeworkItem item) {
    final (label, color) = switch (item.status) {
      HomeworkStatus.submitted => (
        '已提交',
        CupertinoColors.systemGreen.resolveFrom(context),
      ),
      HomeworkStatus.pending =>
        _isOverdue(item.dueAt)
            ? ('已截止', CupertinoColors.systemRed.resolveFrom(context))
            : ('待完成', CupertinoColors.systemOrange.resolveFrom(context)),
      HomeworkStatus.unknown => (
        '待确认',
        CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
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
    if (due == null) return false;
    final date = DateTime.tryParse(due);
    if (date == null) return false;
    // Offset-free school timestamps are Beijing civil time, not device time.
    final explicitZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(due);
    final instant = explicitZone
        ? date.toUtc()
        : DateTime.utc(
            date.year,
            date.month,
            date.day,
            date.hour,
            date.minute,
            date.second,
          ).subtract(const Duration(hours: 8));
    return instant.isBefore(DateTime.now().toUtc());
  }
}

String _format(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
