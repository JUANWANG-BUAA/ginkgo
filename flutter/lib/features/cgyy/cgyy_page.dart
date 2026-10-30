import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'cgyy_day_page.dart';
import 'cgyy_gateway.dart';
import 'cgyy_lock_code_page.dart';
import 'cgyy_models.dart';
import 'cgyy_widgets.dart';

export 'cgyy_day_page.dart' show CgyyDayPage, CgyyLoader;

class CgyyPage extends StatefulWidget {
  const CgyyPage({
    super.key,
    this.demo = false,
    this.loader,
    this.service,
    this.bookingGateway,
  });
  final bool demo;
  final CgyyLoader? loader;
  final CgyyGateway? service;

  /// The CGYY write capability, injected by the composition root.
  final CgyyBookingGateway? bookingGateway;
  @override
  State<CgyyPage> createState() => _CgyyPageState();
}

class _CgyyPageState extends State<CgyyPage> {
  late final RefreshSection<List<CgyySite>> section;
  List<CgyySite>? get sites => section.value;
  String? get error => section.error;
  bool get busy => section.loading;

  @override
  void initState() {
    super.initState();
    section = RefreshSection<List<CgyySite>>()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    load();
  }

  @override
  void didUpdateWidget(CgyyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.loader != widget.loader ||
        oldWidget.demo != widget.demo) {
      section
        ..invalidate()
        ..value = null
        ..error = null
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
    final loader = widget.loader;
    final service = widget.service;
    return section.refresh(
      () async {
        final result = await cgyyRead(
          loader: loader,
          service: service,
          kind: 'venues',
          siteId: 0,
          date: '',
          forceRefresh: force,
        );
        return SectionResult(
          value: result.sites,
          error: result.failure == null ? null : failureMessage(result.failure),
        );
      },
      fallbackError: failureMessage(null),
      force: force,
    );
  }

  void open({CgyySite? site}) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => CgyyDayPage(
        demo: widget.demo,
        site: site,
        loader: widget.loader,
        service: widget.service,
        bookingGateway: widget.bookingGateway,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('cgyy-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: const Text('研讨室'),
          section: '空间资源',
          subtitle: '选择场馆并查看可预约空间',
          icon: CupertinoIcons.person_3,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新场馆',
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
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                '预约研讨室',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            AppleSection(
              children: [
                CgyyInteractiveRow(
                  onTap: () => open(),
                  child: CgyyTileContent(
                    icon: CupertinoIcons.calendar_badge_plus,
                    tint: CupertinoColors.systemIndigo,
                    title: '我的预约记录',
                    detail: '最近最多 20 条',
                    chevron: true,
                  ),
                ),
                CgyyInteractiveRow(
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => CgyyLockCodePage(
                        loader: widget.loader,
                        service: widget.service,
                      ),
                    ),
                  ),
                  child: CgyyTileContent(
                    icon: CupertinoIcons.lock_open,
                    tint: CupertinoColors.systemTeal,
                    title: '门锁密码',
                    detail: '查看当前可开门密码与有效期',
                    chevron: true,
                  ),
                ),
              ],
            ),
            if (error != null)
              AppleStatusSection(
                title: error!,
                description: sites == null ? '请稍后重试。' : '正在显示上次场馆。',
                onAction: () => load(force: true),
                error: true,
              ),
            if (sites == null && busy)
              const GinkgoLoadingView(label: '正在读取研讨室…'),
            if (sites?.isEmpty == true)
              const AppleStatusSection(
                title: '暂无公开场馆',
                description: '学校暂未提供公开场馆。',
              ),
            if (sites != null && sites!.isNotEmpty)
              AppleSection(
                header: const Text('公开场馆'),
                children: [
                  for (final site in sites!)
                    CgyyInteractiveRow(
                      key: ValueKey('cgyy-site-${site.id}'),
                      onTap: () => open(site: site),
                      child: cgyySiteContent(site, chevron: true),
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
