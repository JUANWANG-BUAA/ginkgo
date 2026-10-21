import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/live.dart' show LibraryHistoryResponse;

/// member/seat is a read-only POST. Page failures never advance the cursor.
class LibraryHistoryPage extends StatefulWidget {
  const LibraryHistoryPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<LibraryHistoryPage> createState() => _LibraryHistoryPageState();
}

class _LibraryHistoryPageState extends State<LibraryHistoryPage> {
  LibraryHistoryResponse? data;
  String? error;
  int requestedPage = 1;
  int serial = 0;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load(1);
  }

  Future<void> load(int page, {bool force = false}) async {
    final request = ++serial;
    setState(() {
      requestedPage = page;
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryHistory(
        page,
        forceRefresh: force,
      );
      if (!mounted || request != serial) return;
      setState(() {
        busy = false;
        if (result.failure == null || result.stale) data = result;
        if (result.failure != null) error = failureMessage(result.failure);
      });
    } catch (_) {
      if (!mounted || request != serial) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  String clock(String value) =>
      RegExp(r'^\d{2}:\d{2}').firstMatch(value)?.group(0) ?? value;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('library-history-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('预约记录'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新预约记录',
            onPressed: busy ? null : () => load(requestedPage, force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(
          onRefresh: () => load(requestedPage, force: true),
        ),
        SliverList.list(
          children: [
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: data == null
                        ? '请重试。'
                        : '保留上次读取的第 ${data!.page} 页；请求页码未覆盖旧结果。',
                    error: true,
                    action: '重试',
                    onAction: () => load(requestedPage, force: true),
                  ),
                ],
              ),
            if (data == null && busy)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CupertinoActivityIndicator(),
              ),
            if (data case final result?) ...[
              AppleSection(
                footer: Text(
                  widget.service.isDemo ? '离线合成样例' : '学校预约记录，包含进行中及已结束记录；此页只读。',
                ),
                children: [
                  AppleListTile(
                    title: Text('第 ${result.page} 页'),
                    subtitle: Text(
                      [
                        '${result.bookings.length} 条记录',
                        if (result.total != null) '共 ${result.total} 条',
                        if (result.fetchedAt != null)
                          '更新于 ${result.fetchedAt!.replaceFirst('T', ' ')}',
                        if (result.stale) '上次结果',
                      ].join(' · '),
                    ),
                  ),
                ],
              ),
              AppleContentTransition(
                identity: result,
                child: AppleSection(
                  children: [
                    if (result.bookings.isEmpty)
                      const AppleEmptyState(
                        title: '本页没有预约记录',
                        description: '学校返回空列表，可以返回上一页。',
                      ),
                    for (final booking in result.bookings)
                      AppleListTile(
                        key: Key('library-history-${booking.id}'),
                        minimumHeight: 92,
                        title: Text(
                          booking.title.isEmpty ? '图书馆座位' : booking.title,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  booking.day,
                                  if (booking.startTime.isNotEmpty)
                                    '${clock(booking.startTime)}–${clock(booking.endTime)}',
                                ].where((s) => s.isNotEmpty).join(' · '),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                booking.statusName.isEmpty
                                    ? '状态未确认'
                                    : booking.statusName,
                                style: TextStyle(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      key: const Key('library-history-previous'),
                      onPressed: busy || result.page <= 1
                          ? null
                          : () => load(result.page - 1),
                      child: const Text('上一页'),
                    ),
                    CupertinoButton(
                      key: const Key('library-history-next'),
                      onPressed: busy || !result.hasNext
                          ? null
                          : () => load(result.page + 1),
                      child: const Text('下一页'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );
}
