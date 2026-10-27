import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'learning_widgets.dart';

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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '根目录',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
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
      for (final item in items)
        if (item.folder)
          AppleListTile(
            key: ValueKey('learning-resource-${item.id}'),
            title: Text(item.name),
            subtitle: Text(
              !hasContext && path.isNotEmpty ? '当前服务不支持更深层级，请前往官网' : '目录',
            ),
            leading: const Icon(CupertinoIcons.folder),
            trailing: const CupertinoListTileChevron(),
            onTap: !hasContext && path.isNotEmpty
                ? null
                : () => onNavigate([...path, item], 1),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppleListTile(
                key: ValueKey('learning-resource-${item.id}'),
                title: Text(item.name),
                subtitle: Text(
                  item.downloadable
                      ? (item.updatedAt ?? '更新时间未知')
                      : '学校未允许下载',
                ),
              ),
              if (item.downloadable)
                LearningFileButton(
                  key: ValueKey('learning-save-${item.id}'),
                  download: () => onDownload(item),
                  saveFile: saveFile,
                  isCurrent: isCurrent,
                  contextToken: contextToken,
                ),
            ],
          ),
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
