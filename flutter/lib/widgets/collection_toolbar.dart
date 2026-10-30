import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'package:ginkgo_mirror/application/collection_window.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// Reusable navigation for large result sets. Query controls stay above it in
/// a pinned sliver; pagination is local and never triggers an upstream write.
class CollectionToolbar extends StatelessWidget {
  const CollectionToolbar({
    super.key,
    required this.window,
    required this.onPageChanged,
    required this.unit,
    this.busy = false,
    this.error,
    this.onRetry,
    this.statusKey,
  });
  final CollectionWindow window;
  final ValueChanged<int> onPageChanged;
  final String unit;
  final bool busy;
  final String? error;
  final VoidCallback? onRetry;
  final Key? statusKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  const GinkgoActivity(size: 17),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    window.count == 0
                        ? '共 0 $unit'
                        : '本页 ${window.start + 1}–${window.end} · 共 ${window.count} $unit',
                    key: const Key('collection-range'),
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (window.pageCount > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _arrow(false),
                  Flexible(
                    child: Builder(
                      builder: (anchor) => CupertinoButton(
                        key: const Key('collection-page-picker'),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(44, 48),
                        onPressed: busy
                            ? null
                            : () async {
                                final value = await choose<int>(
                                  anchor,
                                  '跳转到页',
                                  List.generate(
                                    window.pageCount,
                                    (index) => index,
                                  ),
                                  (index) => '第 ${index + 1} 页',
                                  selected: window.page,
                                );
                                if (anchor.mounted && value != null) {
                                  onPageChanged(value);
                                }
                              },
                        child: Text(
                          '${window.page + 1} / ${window.pageCount}',
                          semanticsLabel:
                              '第 ${window.page + 1} 页，共 ${window.pageCount} 页，选择页码',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  _arrow(true),
                ],
              ),
          ],
        ),
        if (error != null)
          SectionFeedback(
            key: statusKey,
            loading: false,
            label: '',
            hasData: window.count > 0,
            error: error,
            onRetry: onRetry,
          ),
      ],
    ),
  );

  Widget _arrow(bool next) => CupertinoButton(
    key: Key(next ? 'collection-next-page' : 'collection-previous-page'),
    padding: const EdgeInsets.all(10),
    minimumSize: const Size(48, 48),
    onPressed:
        busy || (next ? window.page >= window.pageCount - 1 : window.page == 0)
        ? null
        : () => onPageChanged(window.page + (next ? 1 : -1)),
    child: Semantics(
      label: next ? '下一页结果' : '上一页结果',
      child: Icon(
        next ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
        size: 16,
      ),
    ),
  );
}

/// Opaque separation keeps moving rows from competing with query controls.
class CollectionQuerySurface extends StatelessWidget {
  const CollectionQuerySurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      border: Border(
        bottom: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
    ),
    child: child,
  );
}

/// A non-pinned marker gives page/filter changes a stable start of results.
/// Reveal after layout, so shrinking pages cannot reuse an obsolete extent.
class CollectionAnchor {
  final _key = GlobalKey();
  Widget get sliver => SliverToBoxAdapter(child: SizedBox(key: _key));

  void reveal(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(controller));
  }

  void _reveal(ScrollController controller) {
    final object = _key.currentContext?.findRenderObject();
    if (object == null || !object.attached || !controller.hasClients) return;
    final offset = RenderAbstractViewport.of(object)
        .getOffsetToReveal(object, 0)
        .offset;
    controller.jumpTo(
      offset.clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }
}
