import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apple_widgets.dart';
import 'src/rust/api/live.dart' as live;

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, this.demo = false});
  final bool demo;
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<Map<String, dynamic>>? notices;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = widget.demo
          ? await live.loadDemoNotices()
          : await live.loadNotices(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) {
          notices = (jsonDecode(result.payload!) as List)
              .cast<Map<String, dynamic>>();
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
          border: null,
          trailing: AppleGlassButton(
            label: '刷新校园通知',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
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
              const Padding(
                padding: EdgeInsets.all(24),
                child: CupertinoActivityIndicator(),
              ),
            if (notices != null)
              AppleSection(
                children: [
                  for (final notice in notices!)
                    AppleListTile(
                      title: Text(notice['title'] as String),
                      subtitle: Text(notice['published_at'] as String),
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
  final Map<String, dynamic> notice;
  @override
  State<_NoticeDetail> createState() => _NoticeDetailState();
}

class _NoticeDetailState extends State<_NoticeDetail> {
  String? error;
  Future<void> open() async {
    try {
      final url = Uri.parse(widget.notice['url'] as String);
      if (url.scheme != 'https' ||
          url.host != 'news.buaa.edu.cn' ||
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
            widget.notice['title'] as String,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            widget.notice['published_at'] as String,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 24),
          Text(
            (widget.notice['summary'] as String).isEmpty
                ? '列表未提供摘要，请查看官网原文。'
                : widget.notice['summary'] as String,
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
