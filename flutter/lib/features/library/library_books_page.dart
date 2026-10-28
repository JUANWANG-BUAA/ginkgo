import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'library_books_models.dart';
import 'library_cards.dart';
import 'library_controls.dart';
import 'library_holdings_page.dart';
import 'library_widgets.dart';

/// Public OPAC search. Anonymous, read-only and never personal: holdings are
/// fetched on demand and the school's nested JSON is decoded in Rust.
class LibraryBooksPage extends StatefulWidget {
  const LibraryBooksPage({super.key, required this.service});
  final LibraryCatalogGateway service;
  @override
  State<LibraryBooksPage> createState() => _LibraryBooksPageState();
}

class _LibraryBooksPageState extends State<LibraryBooksPage> {
  final query = TextEditingController();
  BookPage? page;
  String? error;
  bool busy = false;
  int requested = 1;

  /// The page number of the most recent attempt, successful or not, so the
  /// error retry repeats exactly what failed instead of guessing.
  int attemptedPage = 1;
  String sort = 'relevance';
  bool descending = true;
  bool _showHelp = false;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant LibraryBooksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      _generation++;
      page = null;
      error = null;
      busy = false;
      requested = 1;
      attemptedPage = 1;
      sort = 'relevance';
      descending = true;
      _showHelp = false;
      query.clear();
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search({int page = 1}) async {
    final text = query.text.trim();
    if (busy || text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final generation = ++_generation;
    setState(() {
      busy = true;
      error = null;
      attemptedPage = page;
    });
    try {
      final result = await widget.service.libraryBooks(
        query: text,
        page: page,
        sort: sort,
        descending: descending,
      );
      if (!mounted || generation != _generation) return;
      if (result.payload != null && result.failure == null) {
        setState(() {
          this.page = bookPage(result.payload!);
          requested = page;
        });
      } else {
        setState(() => error = '检索未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => error = '检索未完成，请稍后重试');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> openHoldings(BookHit hit) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LibraryHoldingsPage(
          service: widget.service,
          bibId: hit.bibId,
          title: hit.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = page?.items;
    final total = page?.actualTotal;
    final hasMore = page?.hasMore ?? false;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        child: CustomScrollView(
          key: const Key('library-books-scroll'),
          slivers: [
            const AppleRefreshPageHeader(
              title: '查书目与馆藏',
              section: '图书与借阅',
              subtitle: '公开目录检索 · 复本状态',
              icon: CupertinoIcons.book_solid,
            ),
            SliverList.list(
              children: [
                AppleSection(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: LibrarySearchField(
                        controller: query,
                        placeholder: '书名、作者或 ISBN',
                        busy: busy,
                        boxKey: const Key('library-books-search-box'),
                        searchKey: const Key('library-books-query'),
                        submitKey: const Key('library-books-submit'),
                        onSubmit: () => search(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: LibrarySortControl(
                        sort: sort,
                        descending: descending,
                        busy: busy,
                        rowKey: const Key('library-books-sort-row'),
                        sortKey: const Key('library-books-sort'),
                        directionKey: const Key('library-books-direction'),
                        onSortChanged: (value) {
                          setState(() => sort = value);
                          if (page != null) search(page: 1);
                        },
                        onDirectionToggled: () {
                          setState(() => descending = !descending);
                          if (page != null) search(page: 1);
                        },
                      ),
                    ),
                    LibraryDisclosureToggle(
                      label: '检索说明',
                      expanded: _showHelp,
                      onToggle: () => setState(() => _showHelp = !_showHelp),
                      toggleKey: const Key('library-books-help'),
                    ),
                    if (_showHelp)
                      const LibraryNoteText(
                        text:
                            '公开目录检索，不需要登录；只读，不包含本人借阅记录、续借或预约。'
                            '排序只列出已在官方接口验证可用的字段，切换后从第 1 页重新检索。',
                      ),
                  ],
                ),
                if (error != null)
                  AppleStatusSection(
                    title: error!,
                    description: items == null ? '请检查网络后重试。' : '正在保留上一次检索结果。',
                    action: '重试',
                    onAction: () => search(page: attemptedPage),
                    error: true,
                  ),
                if (busy && items == null)
                  const GinkgoLoadingView(label: '正在读取书目…'),
                if (items != null && items.isEmpty)
                  const AppleStatusSection(
                    title: '没有匹配的书目',
                    description: '换个关键词或检查拼写后再试。',
                  ),
                if (items != null && items.isNotEmpty)
                  AppleSection(
                    header: Text(
                      total == null
                          ? '检索结果'
                          : '共 $total 条（本页 ${items.length} 条）',
                    ),
                    footer: const Text('数量与可借状态来自学校目录，可能会变化。打开单条书目查看复本与馆藏地。'),
                    children: [
                      for (final (index, hit) in items.indexed)
                        LibraryBookCard(
                          key: Key('library-book-$index-${hit.bibId}'),
                          hit: hit,
                          onTap: () => openHoldings(hit),
                        ),
                    ],
                  ),
                if (items != null && (hasMore || requested > 1))
                  AppleSection(
                    children: [
                      LibraryPager(
                        page: requested,
                        hasMore: hasMore,
                        busy: busy,
                        previousKey: const Key('library-books-prev'),
                        nextKey: const Key('library-books-more'),
                        labelKey: const Key('library-books-page-label'),
                        onPrevious: () => search(page: requested - 1),
                        onNext: () => search(page: requested + 1),
                      ),
                    ],
                  ),
                if (items == null && !busy && error == null)
                  const AppleStatusSection(
                    title: '输入关键词开始检索',
                    description: '例如书名、作者或 ISBN；结果按学校默认相关度排序。',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
