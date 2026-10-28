import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/library_loans.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'library_controls.dart';

/// Private records exist only while this page is active. No background reads.
class LibraryLoansPage extends StatefulWidget {
  const LibraryLoansPage({super.key, this.gateway, this.officialGateway});
  final LibraryLoansGateway? gateway;

  /// The official portal entry is an independent capability; a service may
  /// offer the private read without offering the public link.
  final LibraryLoansOfficialGateway? officialGateway;
  @override
  State<LibraryLoansPage> createState() => _LibraryLoansPageState();
}

class _LibraryLoansPageState extends State<LibraryLoansPage>
    with WidgetsBindingObserver {
  LibraryLoanPage? _data;
  FailureCode? _failure;
  bool _busy = false, _showPrivacy = false;
  int _generation = 0;
  void _clear() {
    _generation++;
    _data = null;
    _failure = null;
    _busy = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _clear();
  }

  @override
  void didUpdateWidget(LibraryLoansPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gateway, widget.gateway)) _clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) setState(_clear);
  }

  @override
  void dispose() {
    _clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _read(int page) async {
    final gateway = widget.gateway;
    if (_busy || gateway == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failure = null;
    });
    LibraryLoansRead result;
    try {
      result = await gateway.libraryLoans(page: page);
    } catch (_) {
      result = const LibraryLoansRead(failure: FailureCode.serviceUnavailable);
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _failure = result.failure;
      if (result.failure == FailureCode.sessionExpired) _data = null;
      if (result.failure == null && result.data != null) _data = result.data;
      if (result.failure == null && result.data == null) {
        _failure = FailureCode.changedResponse;
      }
    });
  }

  Future<void> _openOfficial() async {
    final gateway = widget.officialGateway;
    if (gateway == null) return;
    try {
      final url = gateway.libraryLoansPortalUrl();
      if (!await openSchoolLink(url)) {
        throw StateError('official website unavailable');
      }
    } catch (_) {
      if (mounted) setState(() => _failure = FailureCode.serviceUnavailable);
    }
  }

  String get _error => switch (_failure) {
    FailureCode.sessionExpired => '读者认证未完成或已过期，请重新登录；官网可单独查看本人借阅。',
    FailureCode.redirectLimit => '读者认证反复跳转，尚未建立图书馆会话；请通过图书馆官网完成认证后核对。',
    FailureCode.changedResponse => '借阅接口路径或数据结构发生变化，请通过官网核对。',
    FailureCode.accessPolicyDenied => '当前网络或读者权限不允许查询，请通过官网核对。',
    FailureCode.businessRejected => '图书馆未受理本次查询，请通过官网核对。',
    _ => '借阅服务暂不可用，请稍后重试；不能据此判断接口不存在。',
  };
  @override
  Widget build(BuildContext context) {
    final data = _data;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: const CupertinoNavigationBar(middle: Text('本人借阅')),
      child: SafeArea(
        child: ListView(
          children: [
            AppleSection(
              header: const Text('当前借阅'),
              footer: const Text('仅临时查看，不保存到磁盘；不提供续借或到期提醒。'),
              children: [
                AppleListTile(
                  leading: const Icon(CupertinoIcons.lock_shield),
                  title: const Text('仅在本页临时查看'),
                  subtitle: const Text('离开栏目或进入后台后清除'),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _showPrivacy = !_showPrivacy),
                    child: Text(_showPrivacy ? '收起' : '说明'),
                  ),
                ),
                if (_showPrivacy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '点击后读取当前账号记录，不保存到磁盘，不提供续借、归还或到期通知。App 认证与非空记录仍待实网验收。',
                    ),
                  ),
                if (widget.gateway == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('当前服务未提供本人借阅读取能力。'),
                  )
                else
                  CupertinoButton(
                    onPressed: _busy ? null : () => _read(data?.page ?? 1),
                    child: Text(data == null ? '读取本人借阅' : '刷新本人借阅'),
                  ),
                if (_busy) const GinkgoActivity(size: 24),
                if (widget.officialGateway != null)
                  CupertinoButton(
                    onPressed: _openOfficial,
                    child: const Text('打开图书馆官网'),
                  ),
                if (_failure != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '$_error${data == null ? '' : ' 保留本页上次结果（非最新）。'}',
                    ),
                  ),
                if (data != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('第 ${data.page} 页 · 学校返回共 ${data.total} 条'),
                  ),
                  if (data.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无当前借阅（本次查询已确认）'),
                    ),
                  for (final loan in data.items)
                    AppleListTile(
                      title: Text(loan.title ?? '题名未提供'),
                      subtitle: Text(
                        [
                          if (loan.author != null) loan.author!,
                          if (loan.callNumber != null) '索书号：${loan.callNumber}',
                          '借出：${loan.borrowedAt ?? '未知'}',
                          '应还：${loan.dueAt ?? '未知'}',
                        ].join('\n'),
                      ),
                    ),
                  if (data.page > 1 || data.hasMore)
                    LibraryPageButtons(
                      canGoPrevious: !_busy && data.page > 1,
                      canGoNext: !_busy && data.hasMore && data.page < 100,
                      spread: false,
                      onPrevious: () => _read(data.page - 1),
                      onNext: () => _read(data.page + 1),
                    ),
                  if (data.hasMore && data.page >= 100)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('已达本机查询页数上限，请到官网查看其余记录。'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
