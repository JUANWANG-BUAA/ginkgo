import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'application/refresh_section.dart';
import 'loading_widgets.dart';
import 'today_homework_section.dart';
import 'mirror_service.dart';
import 'schedule_style.dart';
import 'application/contracts.dart';

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
  final ValueChanged<String>? onOpenFeature;
  final VoidCallback? onOpenSettings;
  final String? accountName;
  final Future<void> Function()? onAccountAction;
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late RefreshSection<TodayResponse> courses;
  late RefreshSection<HomeworkResponse> homework;
  TodayResponse? get data => courses.value;
  String? get error => courses.error;
  bool get busy => courses.loading || homework.loading;

  @override
  void initState() {
    super.initState();
    _createSection();
  }

  void _createSection() {
    courses = RefreshSection<TodayResponse>()..addListener(_changed);
    homework = RefreshSection<HomeworkResponse>()..addListener(_changed);
    load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.accountName != widget.accountName) {
      courses.dispose();
      homework.dispose();
      _createSection();
    }
  }

  @override
  void dispose() {
    courses.dispose();
    homework.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) =>
      Future.wait([_loadCourses(force: force), _loadHomework(force: force)]);

  Future<void> _loadCourses({bool force = false}) => courses.refresh(() async {
    final result = await widget.service.today(forceRefresh: force);
    return SectionResult(
      value: result.failure == null || result.fetchedAt != null ? result : null,
      error: result.failure == null ? null : failureMessage(result.failure),
    );
  }, fallbackError: failureMessage(null));

  Future<void> _loadHomework({bool force = false}) =>
      homework.refresh(() async {
        final result = await widget.service.homework(forceRefresh: force);
        return SectionResult(
          value: result.failure == null || result.termCode.isNotEmpty
              ? result
              : null,
          error: result.failure == null ? null : failureMessage(result.failure),
        );
      }, fallbackError: failureMessage(null));

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
  Widget build(BuildContext context) => PageRefreshShortcut(
    onRefresh: busy ? null : () => load(force: true),
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('today-scroll'),
        slivers: [
          ApplePageHeader(
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
                      ? const GinkgoActivity()
                      : const Icon(CupertinoIcons.refresh, size: 24),
                ),
              ],
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ((constraints.crossAxisExtent - 820) / 2).clamp(
                  0,
                  double.infinity,
                ),
              ),
              sliver: SliverList.list(
                children: [
                  if (widget.onOpenSettings != null)
                    AppleSection(
                      children: [
                        AppleListTile(
                          key: const Key('workspace-settings'),
                          leadingSize: 36,
                          leading: Icon(
                            CupertinoIcons.person_crop_circle_fill,
                            size: 34,
                            color: CupertinoTheme.of(context).primaryColor,
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
                  if (data == null)
                    AppleSection(
                      header: const Text('今日课程'),
                      children: [
                        SectionFeedback(
                          loading: courses.loading,
                          label: '正在读取今天课程…',
                          hasData: false,
                          error: error,
                          onRetry: () => _loadCourses(force: true),
                        ),
                      ],
                    ),
                  if (data != null)
                    SectionReveal(
                      key: const Key('today-course-content'),
                      child: Column(children: _content(data!)),
                    ),
                  TodayHomeworkSection(
                    section: homework,
                    onRetry: () => _loadHomework(force: true),
                    onOpen: widget.onOpenFeature == null
                        ? null
                        : () => widget.onOpenFeature!('homework'),
                  ),
                  if (widget.onOpenFeature != null) _shortcuts(),
                  if (widget.directory != null) widget.directory!,
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _shortcuts() {
    const labels = ['课程签到', '查看课表', '学校作业', '空间预约'];
    const shortcutIds = ['checkin', 'schedule', 'homework', 'reservations'];
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
    return AppleSection(
      header: const Text('常用服务'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                MediaQuery.textScalerOf(context).scale(1) > 1.5 ||
                    constraints.maxWidth < 280
                ? 1
                : 2;
            final width = constraints.maxWidth / columns;
            return Wrap(
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    width: width,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      borderRadius: BorderRadius.zero,
                      onPressed: () => widget.onOpenFeature!(shortcutIds[i]),
                      child: Row(
                        children: [
                          Icon(
                            icons[i],
                            size: 24,
                            color: colors[i].resolveFrom(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
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
      ],
    );
  }

  List<Widget> _content(TodayResponse data) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null
        ? data.date
        : '${date.year}年${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';
    return [
      AppleSection(
        key: const Key('today-courses'),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel),
            const SizedBox(height: 4),
            Text(
              data.courses.isEmpty ? '今日课程' : '今天 ${data.courses.length} 节课',
            ),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.fetchedAt != null)
              Text('课表同步：${_updatedAt(data.fetchedAt!)}'),
            Text(
              widget.service.isDemo
                  ? '离线演示 · 课程与日期为合成样例'
                  : '课程来自教务课表，签到状态请进入课程签到核对。',
            ),
          ],
        ),
        children: [
          if (courses.loading || error != null)
            SectionFeedback(
              loading: courses.loading,
              label: '正在更新今天课程…',
              hasData: true,
              error: error,
              onRetry: () => _loadCourses(force: true),
            ),
          if (data.courses.isEmpty)
            AppleEmptyState(
              title: error != null ? '今日课程尚未确认' : '今天没有课程',
              description: error != null
                  ? '课表更新失败，请刷新后再确认今天的安排。'
                  : '当前课表中没有当天课程，可查看完整课表安排学习。',
              action: widget.onOpenFeature == null ? null : '查看完整课表',
              onAction: () => widget.onOpenFeature?.call('schedule'),
            ),
          for (final (index, course) in data.courses.indexed)
            _TodayCourseRow(
              key: Key('today-course-$index-${course.name}'),
              course: course,
            ),
          if (data.courses.isNotEmpty && widget.onOpenFeature != null)
            AppleListTile(
              title: Text(
                '查看完整课表',
                style: TextStyle(
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
              additionalInfo: Text('共 ${data.courses.length} 门课'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => widget.onOpenFeature!('schedule'),
            ),
        ],
      ),
    ];
  }

  String _updatedAt(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final beijing = date.toUtc().add(const Duration(hours: 8));
    final hour = beijing.hour.toString().padLeft(2, '0');
    final minute = beijing.minute.toString().padLeft(2, '0');
    return '${beijing.month}月${beijing.day}日 $hour:$minute';
  }
}

/// Keep course times on a visible axis, like the native Today views. At large
/// type sizes the axis moves above the title so neither field is squeezed.
class _TodayCourseRow extends StatelessWidget {
  const _TodayCourseRow({super.key, required this.course});
  final TodayCourse course;

  @override
  Widget build(BuildContext context) {
    final times = RegExp(r'^(\d{1,2}:\d{2})\s*[-–—~～]\s*(\d{1,2}:\d{2})$')
        .firstMatch(course.time?.trim() ?? '');
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          times?.group(1) ?? course.time ?? '时间未提供',
          style: TextStyle(
            fontSize: times == null ? 14 : 20,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (times != null)
          Text(
            times.group(2)!,
            style: TextStyle(fontSize: 14, color: secondary),
          ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          course.place?.trim().isNotEmpty == true ? course.place! : '地点未提供',
          style: TextStyle(fontSize: 14, color: secondary),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: courseColor(context, null, course.name),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stacked)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [time, const SizedBox(height: 8), details],
                        ),
                      )
                    else ...[
                      SizedBox(width: 84, child: time),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
