import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'schedule_style.dart';
import 'src/rust/api/mirror.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.service,
    this.accountName,
    this.onAccountAction,
    this.directory,
    this.onOpenFeature,
    this.onOpenSettings,
  });
  final MirrorService service;
  final Widget? directory;
  final ValueChanged<int>? onOpenFeature;
  final VoidCallback? onOpenSettings;
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
          largeTitle: Text(widget.directory == null ? '今天' : '工作台'),
          border: null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onOpenSettings != null ||
                  widget.onAccountAction != null) ...[
                AppleGlassButton(
                  label: widget.onOpenSettings != null
                      ? '设置'
                      : widget.service.isDemo
                      ? '演示模式'
                      : '账号',
                  onPressed:
                      widget.onOpenSettings ?? (busy ? null : accountAction),
                  child: Icon(
                    widget.onOpenSettings != null
                        ? CupertinoIcons.gear_alt
                        : widget.service.isDemo
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
            if (widget.onOpenSettings != null)
              AppleSection(
                children: [
                  AppleListTile(
                    key: const Key('workspace-settings'),
                    leading: const Icon(
                      CupertinoIcons.person_crop_circle_fill,
                      size: 34,
                      color: CupertinoColors.systemBlue,
                    ),
                    title: const Text(
                      '账户与设置',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      widget.service.isDemo
                          ? '离线演示 · 连接与数据管理'
                          : '学校账户 · 连接与数据管理',
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: widget.onOpenSettings,
                  ),
                ],
              ),
            if (widget.onOpenFeature != null) _shortcuts(),
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
            else if (data == null)
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
            if (widget.directory != null) widget.directory!,
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );

  Widget _shortcuts() {
    const labels = ['课程签到', '查看课表', '学校作业', '空间预约'];
    const icons = [
      CupertinoIcons.checkmark_seal_fill,
      CupertinoIcons.calendar,
      CupertinoIcons.doc_text_fill,
      CupertinoIcons.square_grid_2x2_fill,
    ];
    const colors = [
      CupertinoColors.systemOrange,
      CupertinoColors.systemBlue,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPurple,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              MediaQuery.textScalerOf(context).scale(1) > 1.5 ||
                  constraints.maxWidth < 280
              ? 1
              : 2;
          final width = ((constraints.maxWidth - (columns - 1) * 12) / columns)
              .clamp(0.0, double.infinity);
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < 4; i++)
                SizedBox(
                  width: width,
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(18),
                    color: CupertinoColors.secondarySystemGroupedBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(26),
                    onPressed: () => widget.onOpenFeature!(i + 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          icons[i],
                          size: 28,
                          color: colors[i].resolveFrom(context),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          const ['查看当天状态', '安排本周学习', '截止与提交状态', '座位 · 研讨室'][i],
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(TodayResponse data) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null
        ? data.date
        : '${date.year}年${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';
    return [
      AppleSection(
        header: Text(dateLabel),

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
            for (final (index, course) in data.courses.indexed)
              AppleListTile(
                key: Key('today-course-$index-${course.name}'),
                minimumHeight: 66,
                leading: Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: courseColor(context, null, course.name),
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
                  : '课程来自教务课表。签到是否开放，请进入签到查看。',
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
