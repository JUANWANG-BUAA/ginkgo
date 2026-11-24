import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_widgets.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

const EdgeInsets _quickFilterPadding = EdgeInsets.fromLTRB(
  GinkgoSpacing.pageInset,
  GinkgoSpacing.md,
  GinkgoSpacing.pageInset,
  0,
);
const EdgeInsets _countHeaderPadding = EdgeInsets.fromLTRB(
  GinkgoSpacing.desktopPageInset,
  GinkgoSpacing.xl,
  GinkgoSpacing.desktopPageInset,
  GinkgoSpacing.sm,
);
const EdgeInsets _footerPadding = EdgeInsets.fromLTRB(
  GinkgoSpacing.desktopPageInset,
  GinkgoSpacing.base,
  GinkgoSpacing.desktopPageInset,
  0,
);

/// Builds the quick-filter bar, count header, grouped homework list (or empty
/// state), and source footer slivers for [HomeworkPage].
List<Widget> buildHomeworkListSlivers({
  required BuildContext context,
  required HomeworkResponse data,
  required List<HomeworkItem> visible,
  required int overdue,
  required int overduePending,
  required int unknown,
  required int filter,
  required int deadlineFilter,
  required bool includeTeaching,
  required bool allPersonalSubmitted,
  required String search,
  required DateTime clock,
  required AcademicGateway service,
  required PlatformActions fileActions,
  required ValueChanged<int> onToggleFilter,
  required ValueChanged<int> onToggleDeadline,
  required VoidCallback onClearFilters,
}) {
  final hasFilter = filter != 0 || deadlineFilter != 0 || search.isNotEmpty;
  final dividerColor = CupertinoColors.separator
      .resolveFrom(context)
      .withValues(alpha: 0.2);

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: _quickFilterPadding,
        child: Wrap(
          spacing: GinkgoSpacing.sm,
          runSpacing: GinkgoSpacing.sm,
          children: [
            HomeworkQuickFilter(
              value: 1,
              label: '未截止',
              tint: CupertinoColors.secondaryLabel,
              selected: deadlineFilter == 1,
              onPressed: () => onToggleDeadline(1),
            ),
            HomeworkQuickFilter(
              value: 3,
              label: '已截止 $overdue',
              tint: overduePending == 0
                  ? CupertinoColors.secondaryLabel
                  : AppleDesign.statusDanger,
              selected: deadlineFilter == 2,
              onPressed: () => onToggleDeadline(2),
            ),
            HomeworkQuickFilter(
              value: 5,
              label: '时间未确认',
              tint: CupertinoColors.secondaryLabel,
              selected: deadlineFilter == 3,
              onPressed: () => onToggleDeadline(3),
            ),
            HomeworkQuickFilter(
              value: 4,
              label: '待确认 $unknown',
              tint: unknown == 0
                  ? CupertinoColors.secondaryLabel
                  : AppleDesign.statusUncertain,
              selected: filter == 4,
              onPressed: () => onToggleFilter(4),
            ),
            if (hasFilter)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onClearFilters,
                child: const Text('清除筛选'),
              ),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: _countHeaderPadding,
        child: Text(
          '${visible.length} 项作业',
          style: GinkgoTypography.callout.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    if (visible.isEmpty)
      SliverToBoxAdapter(
        child: AppleEmptyState(
          title: data.rolesComplete == false
              ? '作业来源尚未完整读取'
              : !includeTeaching &&
                    filter == 1 &&
                    deadlineFilter == 0 &&
                    search.trim().isEmpty &&
                    allPersonalSubmitted
              ? '作业已全部提交'
              : search.trim().isNotEmpty
              ? '没有匹配的作业'
              : hasFilter
              ? '没有符合筛选条件的作业'
              : '暂无作业',
          description: data.rolesComplete == false
              ? '部分课程的作业可能尚未显示，请检查课程范围并重试。'
              : hasFilter
              ? '清除筛选或修改关键词后查看其他作业。'
              : '当前课程范围内没有作业。',
        ),
      )
    else
      SliverList.builder(
        itemCount: visible.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final item = visible[index];
          return Padding(
            padding: GinkgoSpacing.edgeInsetsPage,
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? GinkgoRadii.panel : 0),
                bottom: Radius.circular(
                  index == visible.length - 1 ? GinkgoRadii.panel : 0,
                ),
              ),
              child: ColoredBox(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                child: Column(
                  children: [
                    HomeworkItemTile(
                      item: item,
                      clock: clock,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => HomeworkDetailPage(
                            fileActions: fileActions,
                            item: item,
                            service: service,
                          ),
                        ),
                      ),
                    ),
                    if (index != visible.length - 1)
                      Padding(
                        padding: GinkgoSpacing.edgeInsetsPage,
                        child: Container(
                          height: GinkgoSpacing.hairline,
                          color: dividerColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    SliverToBoxAdapter(
      child: Padding(
        padding: _footerPadding,
        child: Text(
          service.isDemo
              ? '演示数据 · 学校状态与个人待办独立 · 截止按北京时间'
              : '来源：SPOC · 学校状态与个人待办独立 · 截止按北京时间',
          style: AppleDesign.caption.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ),
  ];
}
