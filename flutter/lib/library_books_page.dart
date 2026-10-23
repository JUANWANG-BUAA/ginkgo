import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';

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
  Map<String, dynamic>? page;
  String? error;
  bool busy = false;
  int requested = 1;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search({int page = 1}) async {
    final text = query.text.trim();
    if (busy || text.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryBooks(
        query: text,
        page: page,
      );
      if (!mounted) return;
      if (result.payload != null && result.failure == null) {
        setState(() {
          this.page = jsonDecode(result.payload!) as Map<String, dynamic>;
          requested = page;
        });
      } else {
        setState(() => error = '检索未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted) setState(() => error = '检索未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openHoldings(Map<String, dynamic> hit) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LibraryHoldingsPage(
          service: widget.service,
          bibId: hit['bibId'] as String,
          title: hit['title'] as String? ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = (page?['items'] as List?)?.cast<Map<String, dynamic>>();
    final total = page?['actualTotal'] as int?;
    final hasMore = page?['hasMore'] == true;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: const CupertinoNavigationBar(middle: Text('查书目与馆藏')),
      child: SafeArea(
        child: ListView(
          key: const Key('library-books-scroll'),
          children: [
            AppleSection(
              footer: const Text(
                '公开目录检索，不需要登录；只读，不包含本人借阅记录、续借或预约。',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: CupertinoSearchTextField(
                    key: const Key('library-books-query'),
                    controller: query,
                    placeholder: '书名、作者或 ISBN',
                    onSubmitted: (_) => search(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: CupertinoButton.filled(
                    key: const Key('library-books-submit'),
                    minimumSize: const Size.fromHeight(44),
                    onPressed: busy ? null : () => search(),
                    child: busy
                        ? const CupertinoActivityIndicator()
                        : const Text('检索'),
                  ),
                ),
              ],
            ),
            if (error != null)
              AppleSection(
                children: [AppleListTile(title: Text(error!))],
              ),
            if (items != null && items.isEmpty)
              AppleSection(
                children: const [
                  AppleListTile(
                    title: Text('没有匹配的书目'),
                    subtitle: Text('换个关键词或检查拼写后再试。'),
                  ),
                ],
              ),
            if (items != null && items.isNotEmpty)
              AppleSection(
                header: Text(
                  total == null ? '检索结果' : '共 $total 条（本页 ${items.length} 条）',
                ),
                footer: const Text('数量与可借状态来自学校目录，可能会变化。'),
                children: [
                  for (final hit in items)
                    AppleListTile(
                      key: Key('library-book-${hit['bibId']}'),
                      title: Text(
                        (hit['title'] as String?)?.trim().isNotEmpty == true
                            ? hit['title'] as String
                            : '未命名书目',
                      ),
                      subtitle: Text(_subtitle(hit)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => openHoldings(hit),
                    ),
                ],
              ),
            if (items != null && hasMore)
              AppleSection(
                children: [
                  AppleListTile(
                    key: const Key('library-books-more'),
                    title: const Text('载入下一页'),
                    subtitle: Text('当前第 $requested 页'),
                    onTap: busy ? null : () => search(page: requested + 1),
                  ),
                ],
              ),
            if (items == null && !busy)
              const AppleSection(
                children: [
                  AppleListTile(
                    title: Text('输入关键词开始检索'),
                    subtitle: Text('例如书名、作者或 ISBN；结果按学校默认相关度排序。'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Map<String, dynamic> hit) {
    final parts = [
      hit['author'],
      hit['publisher'],
      hit['year'],
      hit['callno'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty);
    return parts.isEmpty ? '书目信息待确认' : parts.join(' · ');
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
  List<Map<String, dynamic>>? rows;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryHoldings(widget.bibId);
      if (!mounted) return;
      if (result.payload != null && result.failure == null) {
        setState(() {
          rows = (jsonDecode(result.payload!) as List)
              .cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => error = '馆藏读取未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted) setState(() => error = '馆藏读取未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => busy = false);
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
          if (busy && rows == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: SectionFeedback(
                loading: true,
                label: '正在读取馆藏…',
                hasData: false,
              ),
            ),
          if (error != null)
            AppleSection(children: [AppleListTile(title: Text(error!))]),
          if (rows != null && rows!.isEmpty)
            const AppleSection(
              children: [
                AppleListTile(
                  title: Text('没有可显示的馆藏复本'),
                  subtitle: Text('可能全部借出或尚未上架，请以学校页面为准。'),
                ),
              ],
            ),
          if (rows != null && rows!.isNotEmpty)
            AppleSection(
              header: Text('复本 ${rows!.length} 条'),
              footer: const Text('状态文字来自学校目录，未转换为本地“可借”判断。'),
              children: [
                for (final row in rows!)
                  AppleListTile(
                    title: Text(_label(row)),
                    subtitle: Text(_detail(row)),
                  ),
              ],
            ),
        ],
      ),
    ),
  );

  String _label(Map<String, dynamic> row) {
    final status = (row['status'] as String?)?.trim() ?? '';
    final callNo = (row['callNo'] as String?)?.trim() ?? '';
    if (callNo.isEmpty) return status.isEmpty ? '复本信息待确认' : status;
    return status.isEmpty ? callNo : '$callNo · $status';
  }

  String _detail(Map<String, dynamic> row) {
    final parts = [
      row['library'],
      row['location'],
      row['barCode'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty);
    return parts.isEmpty ? '馆藏位置待确认' : parts.join(' · ');
  }
}

/// Style constants shared with the rest of the library surface.
const libraryBooksAccent = AppleDesign.resourceBlue;
