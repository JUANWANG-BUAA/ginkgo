import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/application/notices.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.service});
  final NoticeGateway service;
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  late final RefreshSection<List<Notice>> section;
  List<Notice>? get notices => section.value;
  String? get error => section.error;
  bool get busy => section.loading;

  @override
  void initState() {
    super.initState();
    section = RefreshSection<List<Notice>>()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    load();
  }

  @override
  void didUpdateWidget(NoticesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      section
        ..invalidate()
        ..value = null
        ..error = null
        ..failure = null
        ..loading = false;
      load();
    }
  }

  @override
  void dispose() {
    section.dispose();
    super.dispose();
  }

  Future<void> load({bool force = false}) {
    final service = widget.service;
    return section.refresh(
      () async {
        final result = await service.notices(forceRefresh: force);
        return SectionResult(
          value: result.data,
          error: result.failure == null ? null : failureMessage(result.failure),
          failure: result.failure,
        );
      },
      fallbackError: failureMessage(null),
      force: force,
    );
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
              AppleStatusSection(
                title: error!,
                description: failureAdvice(
                  hasStaleValue: notices != null,
                  failure: section.failure,
                ),
                onAction: () => load(force: true),
                error: true,
              ),
            if (notices == null && busy)
              const AppleSection(
                children: [GinkgoLoadingView(label: '正在读取校园通知…')],
              ),
            if (notices != null && notices!.isEmpty && !busy)
              const AppleStatusSection(
                title: '暂无校园通知',
                description: '学校通知列表当前为空；可下拉刷新或稍后再看。',
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
    if (!await openSchoolLink(widget.notice.url) && mounted) {
      setState(() => error = schoolLinkError);
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
