import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'cgyy_day_page.dart';
import 'cgyy_gateway.dart';
import 'cgyy_lock_code_page.dart';
import 'cgyy_models.dart';
import 'cgyy_widgets.dart';

export 'cgyy_day_page.dart' show CgyyDayPage, CgyyLoader;

class CgyyPage extends StatefulWidget {
  const CgyyPage({super.key, this.demo = false, this.loader, this.service});
  final bool demo;
  final CgyyLoader? loader;
  final CampusGateway? service;
  @override
  State<CgyyPage> createState() => _CgyyPageState();
}

class _CgyyPageState extends State<CgyyPage> {
  List<CgyySite>? sites;
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
      final result = await cgyyRead(
        demo: widget.demo,
        loader: widget.loader,
        service: widget.service,
        kind: 'venues',
        siteId: 0,
        date: '',
        forceRefresh: force,
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.payload != null) sites = cgyySites(result.payload!);
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

  void open({CgyySite? site}) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => CgyyDayPage(
        demo: widget.demo,
        site: site,
        loader: widget.loader,
        service: widget.service,
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
                        demo: widget.demo,
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
              CgyyStatusSection(
                title: error!,
                description: sites == null ? '请稍后重试。' : '正在显示上次场馆。',
                onRetry: () => load(force: true),
                isError: true,
              ),
            if (sites == null && busy)
              const GinkgoLoadingView(label: '正在读取研讨室…'),
            if (sites?.isEmpty == true)
              const CgyyStatusSection(
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
