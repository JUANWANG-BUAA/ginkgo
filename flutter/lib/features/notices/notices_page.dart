import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/notices/notices_models.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, this.demo = false, this.service});
  final bool demo;
  final CampusGateway? service;
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<Notice>? notices;
  String? error;
  bool busy = false;
  bool _pendingRefresh = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    // A pull-to-refresh during an in-flight read is remembered and rerun
    // once it settles, never silently dropped.
    if (busy) {
      if (force) _pendingRefresh = true;
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = widget.service ?? mirrorServiceFor(demo: widget.demo);
      final result = await service.notices(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) {
          notices = noticeList(result.payload!);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failureMessage(null);
        });
      }
    }
    if (!mounted) return;
    if (_pendingRefresh) {
      _pendingRefresh = false;
      await load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('notices-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('校园通知'),
          section: '校园',
          subtitle: '查看通知与校内资讯',
          icon: CupertinoIcons.news_solid,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新校园通知',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Icon(CupertinoIcons.refresh),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Text(
                '北航新闻网 · 最新 5 条通知',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: notices == null ? '请重试或前往官网。' : '正在显示上次结果。',
                    action: '重试',
                    onAction: () => load(force: true),
                    error: true,
                  ),
                ],
              ),
            if (notices == null && busy)
              const AppleSection(
                children: [GinkgoLoadingView(label: '正在读取校园通知…')],
              ),
            if (notices != null && notices!.isEmpty && !busy)
              const AppleSection(
                children: [
                  AppleEmptyState(
                    title: '暂无校园通知',
                    description: '学校通知列表当前为空；可下拉刷新或稍后再看。',
                  ),
                ],
              ),
            if (notices != null && notices!.isNotEmpty)
              AppleSection(
                children: [
                  for (final notice in notices!)
                    AppleListTile(
                      title: Text(notice.title),
                      subtitle: Text(notice.publishedAt),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                      ),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => _NoticeDetail(notice: notice),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );
}

class _NoticeDetail extends StatefulWidget {
  const _NoticeDetail({required this.notice});
  final Notice notice;
  @override
  State<_NoticeDetail> createState() => _NoticeDetailState();
}

class _NoticeDetailState extends State<_NoticeDetail> {
  String? error;
  Future<void> open() async {
    try {
      final url = Uri.parse(widget.notice.url);
      if (url.scheme != 'https' ||
          url.host.isEmpty ||
          !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) setState(() => error = '无法打开官网，请稍后重试。');
      }
    } catch (_) {
      if (mounted) setState(() => error = '无法打开官网，请稍后重试。');
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
      middle: Text('通知详情'),
      previousPageTitle: '校园通知',
    ),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.notice.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            widget.notice.publishedAt,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 24),
          Text(
            widget.notice.summary.isEmpty
                ? '列表未提供摘要，请查看官网原文。'
                : widget.notice.summary,
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: open,
            child: const Text('在浏览器查看原文'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(error!),
            ),
        ],
      ),
    ),
  );
}
