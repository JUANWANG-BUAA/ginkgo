import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// The catalogue search field: one magnifier row with a submit button. The
/// button is disabled while a read is in flight, so a second search never
/// overlaps the first.
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onSubmit,
    required this.busy,
    this.boxKey,
    this.searchKey,
    this.submitKey,
    this.submitLabel = '检索',
  });

  final TextEditingController controller;
  final String placeholder;
  final VoidCallback onSubmit;
  final bool busy;
  final Key? boxKey;
  final Key? searchKey;
  final Key? submitKey;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      key: boxKey,
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.only(left: 12, right: 2),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 17, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: CupertinoTextField(
              key: searchKey,
              controller: controller,
              placeholder: placeholder,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 11),
              style: const TextStyle(fontSize: 17),
              placeholderStyle: TextStyle(fontSize: 17, color: secondary),
            ),
          ),
          CupertinoButton(
            key: submitKey,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(48, 48),
            onPressed: busy ? null : onSubmit,
            child: busy
                ? const GinkgoActivity(size: 17)
                : Text(
                    submitLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A free-text filter over a list that is already on screen. It filters
/// locally and never asks the school for another page.
class LibraryFilterField extends StatelessWidget {
  const LibraryFilterField({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.filterKey,
  });

  final String placeholder;
  final ValueChanged<String> onChanged;
  final Key? filterKey;

  @override
  Widget build(BuildContext context) => CupertinoSearchTextField(
    key: filterKey,
    placeholder: placeholder,
    onChanged: onChanged,
  );
}

/// The sort selector of the public catalogue: one segmented control plus a
/// direction toggle. Changing either restarts the read at the first page.
class LibrarySortControl extends StatelessWidget {
  const LibrarySortControl({
    super.key,
    required this.sort,
    required this.descending,
    required this.busy,
    required this.onSortChanged,
    required this.onDirectionToggled,
    this.rowKey,
    this.sortKey,
    this.directionKey,
    this.options = const {'relevance': '相关度', 'pub_year': '出版年', 'title': '题名'},
  });

  final String sort;
  final bool descending;
  final bool busy;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onDirectionToggled;
  final Key? rowKey;
  final Key? sortKey;
  final Key? directionKey;
  final Map<String, String> options;

  @override
  Widget build(BuildContext context) => Row(
    key: rowKey,
    children: [
      Expanded(
        child: CupertinoSlidingSegmentedControl<String>(
          key: sortKey,
          groupValue: sort,
          children: {
            for (final entry in options.entries)
              entry.key: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(entry.value),
              ),
          },
          onValueChanged: (value) {
            if (busy || value == null || value == sort) return;
            onSortChanged(value);
          },
        ),
      ),
      const SizedBox(width: 8),
      Semantics(
        label: descending ? '当前降序，切换为升序' : '当前升序，切换为降序',
        child: CupertinoButton(
          key: directionKey,
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(48, 48),
          onPressed: busy ? null : onDirectionToggled,
          child: Icon(
            descending ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up,
            size: 20,
          ),
        ),
      ),
    ],
  );
}

/// The pager of a school-paged list. The current page is always stated in
/// text, so the position is readable without counting the arrows.
class LibraryPager extends StatelessWidget {
  const LibraryPager({
    super.key,
    required this.page,
    required this.hasMore,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
    this.previousKey,
    this.nextKey,
    this.labelKey,
  });

  final int page;
  final bool hasMore;
  final bool busy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Key? previousKey;
  final Key? nextKey;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
    // Wrap, not Row: large-type widths reflow the pager
    // onto two lines instead of overflowing.
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        CupertinoButton(
          key: previousKey,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(48, 48),
          onPressed: busy || page <= 1 ? null : onPrevious,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.chevron_left, size: 15),
              SizedBox(width: 4),
              Text('上一页', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            '当前第 $page 页',
            key: labelKey,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        CupertinoButton(
          key: nextKey,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(48, 48),
          onPressed: busy || !hasMore ? null : onNext,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('下一页', style: TextStyle(fontSize: 15)),
              SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, size: 15),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The plain previous / next controls of a list that the school pages. The
/// current position is stated by the caller; these buttons only move.
class LibraryPageButtons extends StatelessWidget {
  const LibraryPageButtons({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    this.previousKey,
    this.nextKey,
    this.spread = true,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Key? previousKey;
  final Key? nextKey;

  /// Whether the two buttons sit at the two ends of the row or stay
  /// together at the start of it.
  final bool spread;

  @override
  Widget build(BuildContext context) {
    final previous = CupertinoButton(
      key: previousKey,
      onPressed: canGoPrevious ? onPrevious : null,
      child: const Text('上一页'),
    );
    final next = CupertinoButton(
      key: nextKey,
      onPressed: canGoNext ? onNext : null,
      child: const Text('下一页'),
    );
    if (!spread) {
      return Wrap(children: [previous, next]);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [previous, next],
    );
  }
}
