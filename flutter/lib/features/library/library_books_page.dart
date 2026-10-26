import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/library/library_books_models.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/mirror_service.dart';

/// Public OPAC search. Anonymous, read-only and never personal: holdings are
/// fetched on demand and the school's nested JSON is decoded in Rust.
class LibraryBooksPage extends StatefulWidget {
  const LibraryBooksPage({super.key, required this.service});
  final LibraryGateway service;
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
            ApplePageHeader(
              largeTitle: const Text('查书目与馆藏'),
              section: '图书与借阅',
              subtitle: '公开目录检索 · 复本状态',
              icon: CupertinoIcons.book_solid,
              border: null,
            ),
            SliverList.list(
              children: [
                AppleSection(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: _searchBox(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        key: const Key('library-books-sort-row'),
                        children: [
                          Expanded(
                            child: CupertinoSlidingSegmentedControl<String>(
                              key: const Key('library-books-sort'),
                              groupValue: sort,
                              children: const {
                                'relevance': Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('相关度'),
                                ),
                                'pub_year': Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('出版年'),
                                ),
                                'title': Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Text('题名'),
                                ),
                              },
                              onValueChanged: (value) {
                                if (busy || value == null || value == sort) {
                                  return;
                                }
                                setState(() => sort = value);
                                if (page != null) search(page: 1);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: descending ? '当前降序，切换为升序' : '当前升序，切换为降序',
                            child: CupertinoButton(
                              key: const Key('library-books-direction'),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(48, 48),
                              onPressed: busy
                                  ? null
                                  : () {
                                      setState(() => descending = !descending);
                                      if (page != null) search(page: 1);
                                    },
                              child: Icon(
                                descending
                                    ? CupertinoIcons.arrow_down
                                    : CupertinoIcons.arrow_up,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
                        child: Semantics(
                          button: true,
                          label: '检索说明',
                          expanded: _showHelp,
                          onTap: () => setState(() => _showHelp = !_showHelp),
                          excludeSemantics: true,
                          child: CupertinoButton(
                            key: const Key('library-books-help'),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(44, 32),
                            onPressed: () =>
                                setState(() => _showHelp = !_showHelp),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.info,
                                  size: 14,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showHelp ? '收起说明' : '检索说明',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _showHelp
                                      ? CupertinoIcons.chevron_up
                                      : CupertinoIcons.chevron_down,
                                  size: 12,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_showHelp)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Text(
                          '公开目录检索，不需要登录；只读，不包含本人借阅记录、续借或预约。'
                          '排序只列出已在官方接口验证可用的字段，切换后从第 1 页重新检索。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (error != null)
                  AppleSection(
                    children: [
                      AppleEmptyState(
                        title: error!,
                        description: items == null
                            ? '请检查网络后重试。'
                            : '正在保留上一次检索结果。',
                        action: '重试',
                        onAction: () => search(page: attemptedPage),
                        error: true,
                      ),
                    ],
                  ),
                if (busy && items == null)
                  const GinkgoLoadingView(label: '正在读取书目…'),
                if (items != null && items.isEmpty)
                  const AppleSection(
                    children: [
                      AppleEmptyState(
                        title: '没有匹配的书目',
                        description: '换个关键词或检查拼写后再试。',
                      ),
                    ],
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
                        AppleListTile(
                          key: Key('library-book-$index-${hit.bibId}'),
                          title: Text(
                            hit.displayTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hit.factLine.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    hit.factLine,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ),
                              if (hit.callno.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '索书号 ${hit.callno}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => openHoldings(hit),
                        ),
                    ],
                  ),
                if (items != null && (hasMore || requested > 1))
                  AppleSection(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                        // Wrap, not Row: large-type widths reflow the pager
                        // onto two lines instead of overflowing.
                        child: Wrap(
                          key: const Key('library-books-pager'),
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 4,
                          children: [
                            CupertinoButton(
                              key: const Key('library-books-prev'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(48, 48),
                              onPressed: busy || requested <= 1
                                  ? null
                                  : () => search(page: requested - 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(CupertinoIcons.chevron_left, size: 15),
                                  SizedBox(width: 4),
                                  Text('上一页', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                            Semantics(
                              header: true,
                              child: Text(
                                '当前第 $requested 页',
                                key: const Key('library-books-page-label'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ),
                            CupertinoButton(
                              key: const Key('library-books-more'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(48, 48),
                              onPressed: busy || !hasMore
                                  ? null
                                  : () => search(page: requested + 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('下一页', style: TextStyle(fontSize: 15)),
                                  SizedBox(width: 4),
                                  Icon(CupertinoIcons.chevron_right, size: 15),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (items == null && !busy && error == null)
                  const AppleSection(
                    children: [
                      AppleEmptyState(
                        title: '输入关键词开始检索',
                        description: '例如书名、作者或 ISBN；结果按学校默认相关度排序。',
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      key: const Key('library-books-search-box'),
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
              key: const Key('library-books-query'),
              controller: query,
              placeholder: '书名、作者或 ISBN',
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => search(),
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 11),
              style: const TextStyle(fontSize: 17),
              placeholderStyle: TextStyle(fontSize: 17, color: secondary),
            ),
          ),
          CupertinoButton(
            key: const Key('library-books-submit'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(48, 48),
            onPressed: busy ? null : () => search(),
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Text(
                    '检索',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}

class LibraryHoldingsPage extends StatefulWidget {
  const LibraryHoldingsPage({
    super.key,
    required this.service,
    required this.bibId,
    required this.title,
  });
  final LibraryGateway service;
  final String bibId;
  final String title;
  @override
  State<LibraryHoldingsPage> createState() => _LibraryHoldingsPageState();
}

class _LibraryHoldingsPageState extends State<LibraryHoldingsPage> {
  List<BookHolding>? rows;
  String? error;
  bool busy = false;
  bool _pendingReload = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    // A reload request during an in-flight read is remembered and rerun once
    // it settles, never silently dropped.
    if (busy) {
      _pendingReload = true;
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryHoldings(widget.bibId);
      if (!mounted) return;
      if (result.payload != null && result.failure == null) {
        setState(() {
          rows = bookHoldings(result.payload!);
        });
      } else {
        setState(() => error = '馆藏读取未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted) setState(() => error = '馆藏读取未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    if (_pendingReload) {
      _pendingReload = false;
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: CupertinoNavigationBar(
      middle: Text(
        widget.title.isEmpty ? '馆藏复本' : widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    child: SafeArea(
      child: ListView(
        key: const Key('library-holdings-scroll'),
        children: [
          if (busy && rows == null) const GinkgoLoadingView(label: '正在读取馆藏…'),
          if (error != null)
            AppleSection(
              children: [
                AppleEmptyState(
                  title: error!,
                  description: '请检查网络后重试。',
                  action: '重试',
                  onAction: load,
                  error: true,
                ),
              ],
            ),
          if (rows != null && rows!.isEmpty)
            const AppleSection(
              children: [
                AppleEmptyState(
                  title: '没有可显示的馆藏复本',
                  description: '可能全部借出或尚未上架，请以学校页面为准。',
                ),
              ],
            ),
          if (rows != null && rows!.isNotEmpty)
            AppleSection(
              header: Text('复本 ${rows!.length} 条'),
              footer: const Text('馆藏地、状态、索书号和册条码按学校目录原样展示；状态文字未转换为本地“可借”判断。'),
              children: _holdingTiles(context),
            ),
        ],
      ),
    ),
  );

  List<Widget> _holdingTiles(BuildContext context) {
    final secondary = CupertinoColors.tertiaryLabel.resolveFrom(context);
    final tiles = <Widget>[];
    var previousCallNo = '';
    for (final (index, row) in rows!.indexed) {
      final repeated = row.callNo.isNotEmpty && row.callNo == previousCallNo;
      previousCallNo = row.callNo;
      tiles.add(
        AppleListTile(
          key: Key('library-holding-$index'),
          title: Text(row.place.isEmpty ? '馆藏位置待确认' : '馆藏地：${row.place}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('状态：${row.status.isEmpty ? '未标注' : row.status}'),
              Text(
                repeated
                    ? '同索书号：${row.callNo}'
                    : '索书号：${row.callNo.isEmpty ? '未标注' : row.callNo}',
              ),
              Text(
                '册条码：${row.barCode.isEmpty ? '未标注' : row.barCode}',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ],
          ),
        ),
      );
    }
    return tiles;
  }
}
