import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/mirror.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.service,
    this.accountName,
    this.onAccountAction,
  });
  final MirrorService service;
  final String? accountName;
  final Future<void> Function()? onAccountAction;
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  TodayResponse? data;
  String? error;
  String? notice;
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
      final result = await widget.service.today(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null && result.courses.isEmpty) {
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
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  Future<void> accountAction() async {
    final demo = widget.service.isDemo;
    final action = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(widget.accountName ?? (demo ? '离线演示' : '账号')),
        content: Text(demo ? '当前为离线合成样例，不连接学校账号。' : '当前已登录真实学校账号。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'exit'),
            child: Text(demo ? '返回登录' : '退出登录'),
          ),
        ],
      ),
    );
    if (action == 'exit' && mounted) {
      await widget.onAccountAction!();
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('today-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('今天'),
          border: null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onAccountAction != null) ...[
                AppleGlassButton(
                  label: widget.service.isDemo ? '演示模式' : '账号',
                  onPressed: busy ? null : accountAction,
                  child: Icon(
                    widget.service.isDemo
                        ? CupertinoIcons.eye
                        : CupertinoIcons.person_crop_circle,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              AppleGlassButton(
                label: '刷新今天',
                onPressed: busy ? null : () => load(force: true),
                child: busy
                    ? const CupertinoActivityIndicator()
                    : const Icon(CupertinoIcons.refresh, size: 24),
              ),
            ],
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
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
                    description: '请检查网络后重试。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
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
                        Text('正在读取今天课程…'),
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

  List<Widget> _content(TodayResponse data) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null
        ? data.date
        : '${date.year}年${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';
    return [
      AppleSection(
        header: Text(dateLabel),
        footer: const Text('今天页只组合课表模块已读取的当天课程，不复制筛选或周次规则。'),
        children: [
          AppleListTile(
            title: Text(
              data.courses.isEmpty ? '今天没有课程' : '今天 ${data.courses.length} 节课',
            ),
          ),
        ],
      ),
      if (data.courses.isEmpty)
        AppleSection(
          children: const [
            AppleEmptyState(
              title: '今天没有课程',
              description: '可以休息一下，或到课表查看其他教学周。',
            ),
          ],
        )
      else
        AppleSection(
          header: const Text('课程安排'),
          children: [
            for (final course in data.courses)
              AppleListTile(
                key: Key('today-course-${course.name}'),
                minimumHeight: 66,
                leading: Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: CupertinoTheme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                title: Text(course.name),
                subtitle: Text(
                  [
                    if (course.time != null) course.time!,
                    if (course.place != null) course.place!,
                    if (course.shortName != null &&
                        course.shortName != course.name)
                      course.shortName!,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
          ],
        ),
      AppleSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.service.isDemo
                  ? '离线合成样例，不连接学校账号；日期与课程用于演示迁移后的今天页。'
                  : '真实账号只读数据；今天页只组合课表模块读取的当天课程。',
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
}
