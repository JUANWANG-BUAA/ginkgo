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
  GinkgoSpacing.sm,
  GinkgoSpacing.pageInset,
  0,
);
const EdgeInsets _countHeaderPadding = EdgeInsets.fromLTRB(
  GinkgoSpacing.desktopPageInset,
  GinkgoSpacing.base,
  GinkgoSpacing.desktopPageInset,
  GinkgoSpacing.sm,
);

/// Builds the optional unknown-status filter, count header, unified progressive
/// homework list (or calm empty state) for [HomeworkPage].
List<Widget> buildHomeworkListSlivers({
  required BuildContext context,
  required HomeworkResponse data,
  required List<HomeworkItem> visible,
  required int unknown,
  required int filter,
  required bool includeTeaching,
  required bool allPersonalSubmitted,
  required String search,
  required DateTime clock,
  required AcademicGateway service,
  required PlatformActions fileActions,
  required ValueChanged<int> onToggleFilter,
  required VoidCallback onShowAll,
  required VoidCallback onClearFilters,
}) {
  final hasSearch = search.trim().isNotEmpty;
  final dividerColor = GinkgoSurfaceTokens.dividerColor(context);
  final radius = GinkgoSurfaceTokens.cardRadius(context);

  return [
    if (unknown > 0 || hasSearch || filter == 4)
      SliverToBoxAdapter(
        child: Padding(
          padding: _quickFilterPadding,
          child: Wrap(
            spacing: GinkgoSpacing.sm,
            runSpacing: GinkgoSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (unknown > 0)
                GinkgoActionButton(
                  label: '待确认 $unknown',
                  icon: CupertinoIcons.question_circle_fill,
                  variant: GinkgoButtonVariant.tinted,
                  tint: AppleDesign.statusUncertain,
                  selected: filter == 4,
                  pill: true,
                  onPressed: () => onToggleFilter(4),
                ),
              if (hasSearch || filter == 4)
                GinkgoActionButton(
                  label: '重置筛选',
                  variant: GinkgoButtonVariant.subtle,
                  pill: true,
                  onPressed: onClearFilters,
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
          style: GinkgoTypography.footnote.copyWith(
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    ),
    if (visible.isEmpty)
      SliverToBoxAdapter(
        child: AppleEmptyState(
          icon: !includeTeaching && filter == 0 && !hasSearch
              ? CupertinoIcons.checkmark_circle
              : CupertinoIcons.doc_text,
          title: data.rolesComplete == false
              ? '作业来源尚未完整读取'
              : hasSearch
              ? '没有匹配的作业'
              : filter == 0 && allPersonalSubmitted
              ? '作业已全部提交'
              : filter == 0
              ? '暂无待提交作业'
              : filter == 1
              ? '暂无已提交作业'
              : filter == 2
              ? '暂无已截止作业'
              : '暂无作业',
          description: data.rolesComplete == false
              ? '部分课程的身份尚未核对，请检查课程范围并重试。'
              : hasSearch
              ? '清除搜索关键词后查看其他作业。'
              : filter == 0 && data.items.isNotEmpty
              ? '当前没有待提交项，可切换到已提交或全部查看历史记录。'
              : '当前课程范围内没有对应作业。',
          action: filter == 0 && !hasSearch && data.items.isNotEmpty
              ? '查看全部作业'
              : null,
          onAction: filter == 0 && !hasSearch && data.items.isNotEmpty
              ? onShowAll
              : null,
        ),
      )
    else
      SliverList.builder(
        itemCount: visible.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final item = visible[index];
          final isFirst = index == 0;
          final isLast = index == visible.length - 1;
          final borderColor = GinkgoSurfaceTokens.borderColor(context);
          final bw = GinkgoSurfaceTokens.borderWidth;
          return Padding(
            padding: GinkgoSpacing.edgeInsetsPage,
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isFirst ? radius : 0),
                bottom: Radius.circular(isLast ? radius : 0),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GinkgoColors.secondaryGroupedBackground.resolveFrom(
                    context,
                  ),
                  border: Border(
                    top: isFirst
                        ? BorderSide(color: borderColor, width: bw)
                        : BorderSide.none,
                    bottom: isLast
                        ? BorderSide(color: borderColor, width: bw)
                        : BorderSide.none,
                    left: BorderSide(color: borderColor, width: bw),
                    right: BorderSide(color: borderColor, width: bw),
                  ),
                ),
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
                    if (!isLast)
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
  ];
}
