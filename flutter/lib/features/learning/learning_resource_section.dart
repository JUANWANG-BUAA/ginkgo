import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

import 'learning_widgets.dart';

({IconData icon, Color color, String badge}) _resourceVisual(
  CourseResource item,
) {
  final lower = item.name.trim().toLowerCase();
  if (lower.endsWith('.pdf')) {
    return (
      icon: CupertinoIcons.doc_richtext,
      color: const Color(0xFFDC2626),
      badge: 'PDF',
    );
  }
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
    return (
      icon: CupertinoIcons.play_rectangle_fill,
      color: const Color(0xFFD97706),
      badge: 'PPT',
    );
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return (
      icon: CupertinoIcons.doc_text_fill,
      color: GinkgoColors.resourceBlue,
      badge: 'DOC',
    );
  }
  if (lower.endsWith('.xls') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.csv')) {
    return (
      icon: CupertinoIcons.table_fill,
      color: const Color(0xFF059669),
      badge: '表格',
    );
  }
  if (lower.endsWith('.zip') ||
      lower.endsWith('.rar') ||
      lower.endsWith('.7z') ||
      lower.endsWith('.tar.gz')) {
    return (
      icon: CupertinoIcons.archivebox_fill,
      color: GinkgoColors.resourcePurple,
      badge: '压缩包',
    );
  }
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.mkv')) {
    return (
      icon: CupertinoIcons.film_fill,
      color: GinkgoColors.resourceTeal,
      badge: '视频',
    );
  }
  return (
    icon: CupertinoIcons.doc_fill,
    color: GinkgoColors.resourceBlue,
    badge: '文件',
  );
}

/// 课程资料的目录浏览区：面包屑、当前页筛选、条目列表与分页。
///
/// 只列当前目录的当前页；筛选不跨页。下载由用户主动发起，不会批量保存。
class LearningResourceSection extends StatelessWidget {
  const LearningResourceSection({
    super.key,
    required this.path,
    required this.page,
    required this.items,
    required this.resourceQuery,
    required this.resources,
    required this.supported,
    required this.hasContext,
    required this.saveFile,
    required this.contextToken,
    required this.onQueryChanged,
    required this.onNavigate,
    required this.onRefresh,
    required this.onDownload,
    required this.isCurrent,
  });

  final List<CourseResource> path;
  final int page;
  final List<CourseResource> items;
  final String resourceQuery;
  final RefreshSection<LearningRead<CourseResourcePage>> resources;
  final bool supported;
  final bool hasContext;
  final LearningFileSaver? saveFile;
  final String contextToken;
  final ValueChanged<String> onQueryChanged;
  final void Function(List<CourseResource> nextPath, int nextPage) onNavigate;
  final VoidCallback onRefresh;
  final Future<LearningDownload> Function(CourseResource item) onDownload;
  final bool Function() isCurrent;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: const Text('课程资料'),
    footer: const Text('只列当前目录的当前页；筛选不跨页。下载由你主动发起，不会批量保存。'),
    children: [
      if (path.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '根目录',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
      Wrap(
        children: [
          if (path.isNotEmpty)
            CupertinoButton(
              key: const Key('learning-root'),
              onPressed: () => onNavigate([], 1),
              child: const Text('根目录'),
            ),
          for (var index = 0; index < path.length; index++)
            CupertinoButton(
              onPressed: () => onNavigate(path.take(index + 1).toList(), 1),
              child: Text('/ ${path[index].name}'),
            ),
        ],
      ),
      if (path.isNotEmpty)
        CupertinoButton(
          key: const Key('learning-parent'),
          onPressed: () => onNavigate(path.take(path.length - 1).toList(), 1),
          child: const Text('返回上一级'),
        ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: CupertinoSearchTextField(
          key: ValueKey(
            'learning-resource-search-${path.map((f) => f.id).join('/')}/$page',
          ),
          placeholder: '筛选当前页资料名称',
          onChanged: (value) => onQueryChanged(value.trim()),
        ),
      ),
      LearningReadStatus(
        title: '资料',
        section: resources,
        supported: supported,
        onRefresh: onRefresh,
      ),
      if (resources.value != null && items.isEmpty)
        LearningText(resourceQuery.isEmpty ? '暂无资料' : '当前页没有匹配资料'),
      for (final item in items) ...[
        if (item.folder)
          AppleListTile(
            key: ValueKey('learning-resource-${item.id}'),
            title: Text(item.name),
            subtitle: Text(
              !hasContext && path.isNotEmpty ? '当前服务不支持更深层级，请前往官网' : '目录',
            ),
            leading: const GinkgoIconTile(
              icon: CupertinoIcons.folder_fill,
              size: 32,
              color: GinkgoColors.accent,
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: !hasContext && path.isNotEmpty
                ? null
                : () => onNavigate([...path, item], 1),
          )
        else
          _LearningFileRow(
            item: item,
            saveFile: saveFile,
            contextToken: contextToken,
            onDownload: () => onDownload(item),
            isCurrent: isCurrent,
          ),
      ],
      if (resources.value != null)
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CupertinoButton(
              key: const Key('learning-previous-page'),
              onPressed: page > 1
                  ? () => onNavigate(List.of(path), page - 1)
                  : null,
              child: const Text('上一页'),
            ),
            Text('第 $page 页'),
            CupertinoButton(
              key: const Key('learning-next-page'),
              onPressed: resources.value!.data.hasNext
                  ? () => onNavigate(List.of(path), page + 1)
                  : null,
              child: const Text('下一页'),
            ),
          ],
        ),
    ],
  );
}

class _LearningFileRow extends StatelessWidget {
  const _LearningFileRow({
    required this.item,
    required this.saveFile,
    required this.contextToken,
    required this.onDownload,
    required this.isCurrent,
  });

  final CourseResource item;
  final LearningFileSaver? saveFile;
  final String contextToken;
  final Future<LearningDownload> Function() onDownload;
  final bool Function() isCurrent;

  static const double _iconSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final visual = _resourceVisual(item);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      key: ValueKey('learning-resource-${item.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: GinkgoSpacing.pageInset,
        vertical: GinkgoSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GinkgoIconTile(
                icon: visual.icon,
                size: _iconSize,
                color: visual.color,
              ),
              const SizedBox(width: GinkgoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GinkgoTypography.headline.copyWith(
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: GinkgoSpacing.xs),
                    Wrap(
                      spacing: GinkgoSpacing.sm,
                      runSpacing: GinkgoSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: visual.color.withValues(
                              alpha: dark ? 0.22 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(
                              GinkgoRadii.badge,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: GinkgoSpacing.sm,
                              vertical: GinkgoSpacing.xs,
                            ),
                            child: Text(
                              visual.badge,
                              style: GinkgoTypography.caption2.copyWith(
                                color: visual.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          item.downloadable
                              ? (item.updatedAt ?? '更新时间未知')
                              : '学校未允许下载',
                          style: GinkgoTypography.caption.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.downloadable) ...[
            const SizedBox(height: GinkgoSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: LearningFileButton(
                key: ValueKey('learning-save-${item.id}'),
                download: onDownload,
                saveFile: saveFile,
                isCurrent: isCurrent,
                contextToken: contextToken,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
