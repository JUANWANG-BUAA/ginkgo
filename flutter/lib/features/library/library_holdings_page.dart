import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'package:ginkgo_mirror/application/library_holdings.dart';

import 'library_cards.dart';

/// The copies the school holds for one catalogue record. The status text is
/// the school's own wording; it is never turned into a local "available"
/// judgement.
class LibraryHoldingsPage extends StatefulWidget {
  const LibraryHoldingsPage({
    super.key,
    required this.service,
    required this.bibId,
    required this.title,
  });
  final LibraryCatalogGateway service;
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
  int requestSerial = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(LibraryHoldingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.bibId != widget.bibId) {
      requestSerial++;
      rows = null;
      error = null;
      busy = false;
      _pendingReload = false;
      load();
    }
  }

  Future<void> load() async {
    if (busy) {
      _pendingReload = true;
      return;
    }
    final serial = ++requestSerial;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryHoldings(widget.bibId);
      if (!mounted || serial != requestSerial) return;
      final decoded = result.data;
      if (result.failure == null && decoded != null) {
        setState(() => rows = decoded);
      } else {
        setState(() => error = '馆藏读取未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted && serial == requestSerial) {
        setState(() => error = '馆藏读取未完成，请稍后重试');
      }
    } finally {
      if (mounted && serial == requestSerial) {
        setState(() => busy = false);
      }
    }
    if (!mounted || serial != requestSerial) return;
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
            AppleStatusSection(
              title: error!,
              description: '请检查网络后重试。',
              action: '重试',
              onAction: load,
              error: true,
            ),
          if (rows != null && rows!.isEmpty)
            const AppleStatusSection(
              title: '没有可显示的馆藏复本',
              description: '可能全部借出或尚未上架，请以学校页面为准。',
            ),
          if (rows != null && rows!.isNotEmpty)
            AppleSection(
              header: Text('复本 ${rows!.length} 条'),
              footer: const Text('馆藏地、状态、索书号和册条码按学校目录原样展示；状态文字未转换为本地“可借”判断。'),
              children: _holdingTiles(),
            ),
        ],
      ),
    ),
  );

  /// A repeated call number is labelled as such, so the same call number is
  /// not read twice in a row.
  List<Widget> _holdingTiles() {
    final tiles = <Widget>[];
    var previousCallNo = '';
    for (final (index, row) in rows!.indexed) {
      final repeated = row.callNo.isNotEmpty && row.callNo == previousCallNo;
      previousCallNo = row.callNo;
      tiles.add(
        LibraryHoldingCard(
          key: Key('library-holding-$index'),
          holding: row,
          repeatedCallNo: repeated,
        ),
      );
    }
    return tiles;
  }
}
