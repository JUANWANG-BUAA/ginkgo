import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ginkgo_mirror/application/campus_activities.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class CampusActivitiesPage extends StatefulWidget {
  const CampusActivitiesPage({super.key, required this.service});
  final Object service;

  @override
  State<CampusActivitiesPage> createState() => _CampusActivitiesPageState();
}

class _CampusActivitiesPageState extends State<CampusActivitiesPage> {
  CampusActivitiesGateway? get gateway =>
      widget.service is CampusActivitiesGateway
      ? widget.service as CampusActivitiesGateway
      : null;
  int page = 1;
  CampusActivities? data;
  String? error;
  bool busy = false;
  bool pendingRefresh = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CampusActivitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      generation++;
      data = null;
      error = null;
      busy = false;
      pendingRefresh = false;
      load();
    }
  }

  Future<void> load({bool force = false}) async {
    final gateway = this.gateway;
    if (gateway == null || busy) {
      if (force) pendingRefresh = true;
      return;
    }
    final requestGeneration = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await gateway.campusActivities(
        page: page,
        forceRefresh: force,
      );
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.data != null) data = result.data;
      });
    } catch (_) {
      if (mounted && requestGeneration == generation) {
        setState(() {
          busy = false;
          error = failureMessage(null);
        });
      }
    }
    if (mounted && requestGeneration == generation && pendingRefresh) {
      pendingRefresh = false;
      await load(force: true);
    }
  }

  void selectPage(int value) {
    if (value == page) return;
    setState(() {
      page = value;
      error = null;
    });
    load(force: true);
  }

  Future<void> open(CampusActivity activity) async {
    if (activity.url.isEmpty) return;
    final uri = Uri.tryParse(activity.url);
    var opened = false;
    try {
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('无法打开原文'),
          content: const Text('请稍后重试。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = this.gateway;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('campus-activities-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('学术文化'),
            section: '资讯与就业',
            subtitle: '学校官网公开的讲座与演出',
            icon: CupertinoIcons.music_note,
            border: null,
            trailing: AppleGlassButton(
              label: '刷新学术文化',
              onPressed: busy ? null : () => load(force: true),
              child: busy
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          SliverList.list(
            children: [
              if (gateway == null)
                const AppleSection(
                  children: [
                    AppleEmptyState(
                      title: '当前服务不支持学术文化',
                      description: '请连接真实服务后重试。',
                      error: true,
                    ),
                  ],
                )
              else ...[
                AppleSection(
                  header: const Text('页码'),
                  children: [
                    CupertinoListTile(
                      title: Text('第 $page 页'),
                      subtitle: const Text('列表页顺序按学校官网分页'),
                      trailing: CupertinoButton(
                        onPressed: busy
                            ? null
                            : () => selectPage(page == 1 ? 2 : 1),
                        child: Text(page == 1 ? '第 2 页' : '第 1 页'),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  AppleSection(
                    children: [
                      AppleEmptyState(
                        title: error!,
                        description: data == null ? '请重试或前往官网。' : '正在显示上次结果。',
                        action: '重试',
                        onAction: () => load(force: true),
                        error: true,
                      ),
                    ],
                  ),
                if (data == null && busy)
                  const AppleSection(
                    children: [GinkgoLoadingView(label: '正在读取学术文化…')],
                  ),
                if (data != null)
                  AppleSection(
                    header: Text('${data!.activities.length} 条公开安排'),
                    footer: Text(
                      '来源：学校官网 · 同步 ${schoolTimestampLabel(data!.fetchedAt)}\n发布日期与活动时间可能不同；详情以原文为准。',
                    ),
                    children: [
                      for (final activity in data!.activities)
                        AppleListTile(
                          key: Key('campus-activity-${activity.id}'),
                          title: Text(activity.title),
                          subtitle: Text(
                            '${activity.category.isEmpty ? '类型未提供' : activity.category} · '
                            '${activity.activityTime.isEmpty ? '时间未提供' : activity.activityTime}\n'
                            '${activity.place.isEmpty ? '地点未提供' : activity.place}\n'
                            '发布 ${activity.publishedAt.isEmpty ? '未提供' : activity.publishedAt}',
                          ),
                          trailing: const Icon(CupertinoIcons.chevron_right),
                          onTap: () => open(activity),
                        ),
                    ],
                  ),
                Padding(padding: GinkgoSpacing.edgeInsetsPage),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
