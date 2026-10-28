import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/campus_activities.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/public_information_page.dart';

class CampusActivitiesPage extends StatelessWidget {
  const CampusActivitiesPage({super.key, required this.service});
  final CampusActivitiesGateway? service;

  @override
  Widget build(
    BuildContext context,
  ) => PublicInformationPage<CampusActivities, int>(
    service: service,
    initialQuery: 1,
    read: (page, force) async {
      final result = await service!
          .campusActivities(page: page, forceRefresh: force);
      return SectionResult(
        value: result.data,
        error: result.failure == null ? null : failureMessage(result.failure),
      );
    },
    scrollKey: const Key('campus-activities-scroll'),
    title: '学术文化',
    subtitle: '学校官网公开的讲座与演出',
    icon: CupertinoIcons.music_note,
    refreshLabel: '刷新学术文化',
    loadingLabel: '正在读取学术文化…',
    unsupportedTitle: '当前服务不支持学术文化',
    queryBuilder: (context, page, busy, select) => AppleSection(
      header: const Text('页码'),
      children: [
        CupertinoListTile(
          title: Text('第 $page 页'),
          subtitle: const Text('列表页顺序按学校官网分页'),
          trailing: CupertinoButton(
            onPressed: busy ? null : () => select(page == 1 ? 2 : 1),
            child: Text(page == 1 ? '第 2 页' : '第 1 页'),
          ),
        ),
      ],
    ),
    contentBuilder: (context, data) => AppleSection(
      header: Text('${data.activities.length} 条公开安排'),
      footer: Text(
        '来源：学校官网 · 同步 ${schoolTimestampLabel(data.fetchedAt)}\n发布日期与活动时间可能不同；详情以原文为准。',
      ),
      children: [
        for (final activity in data.activities)
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
            onTap: () => _openActivity(context, activity),
          ),
      ],
    ),
  );
}

Future<void> _openActivity(
  BuildContext context,
  CampusActivity activity,
) async {
  if (activity.url.isEmpty) return;
  if (!await openSchoolLink(activity.url) && context.mounted) {
    await showSchoolLinkError(context);
  }
}
