import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'bykc_models.dart';
import 'bykc_widgets.dart';

/// 学习进度统计视图。
///
/// 学校提供的分类统计按类别分组展示，每组首次出现时给出章节标题。
/// 统计是本学期已选课程之外的累计口径，页脚已说明差异。
class BykcStatisticsView extends StatelessWidget {
  const BykcStatisticsView({super.key, required this.data});

  final BykcStatistics data;

  @override
  Widget build(BuildContext context) {
    final rows = _groupedRows(data.entries);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: AppleSection(
            header: const Text('学习进度'),
            footer: const Text('学校提供的累计统计，可能与本学期已选数量不同。'),
            children: [
              AppleListTile(
                leading: const Icon(
                  CupertinoIcons.checkmark_seal,
                  color: CupertinoColors.systemGreen,
                ),
                title: const Text('有效课程'),
                additionalInfo: Text(
                  data.validCourseCount == null
                      ? '上游未提供'
                      : '${data.validCourseCount} 门',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (data.entries.isEmpty)
          const SliverToBoxAdapter(
            child: AppleEmptyState(
              title: '暂未返回完成统计',
              description: '学校尚未提供分类要求与完成数量。',
            ),
          ),
        SliverList.builder(
          itemCount: rows.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            final row = rows[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (row.first)
                  BykcSectionHeading(
                    title: row.category,
                    detail: '已完成 / 应完成',
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(row.first ? 20 : 0),
                      bottom: Radius.circular(row.last ? 20 : 0),
                    ),
                    child: ColoredBox(
                      color: CupertinoColors.secondarySystemGroupedBackground
                          .resolveFrom(context),
                      child: Column(
                        children: [
                          BykcStatisticsCard(entry: row.entry),
                          if (!row.last)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Container(
                                height: 0.5,
                                color: CupertinoColors.separator
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ),
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
}

/// 把统计条目按类别分组，并标注每组首尾，用于圆角与分隔线。
List<({String category, BykcStatisticsEntry entry, bool first, bool last})>
_groupedRows(List<BykcStatisticsEntry> entries) {
  final groups = <String, List<BykcStatisticsEntry>>{};
  for (final entry in entries) {
    (groups[entry.category] ??= []).add(entry);
  }
  return [
    for (final group in groups.entries)
      for (var index = 0; index < group.value.length; index++)
        (
          category: group.key,
          entry: group.value[index],
          first: index == 0,
          last: index == group.value.length - 1,
        ),
  ];
}
