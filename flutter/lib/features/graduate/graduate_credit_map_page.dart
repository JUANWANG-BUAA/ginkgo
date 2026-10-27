import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/graduate_credit_map.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'graduate_credit_map_widgets.dart';

/// Parent supplies an account-scoped gateway and identity. This page never
/// reads credentials, raw school fields, or global native commands.
class GraduateCreditMapPage extends StatefulWidget {
  const GraduateCreditMapPage({
    super.key,
    required this.service,
    this.accountId,
  });
  final Object service;
  final String? accountId;
  @override
  State<GraduateCreditMapPage> createState() => _GraduateCreditMapPageState();
}

class _GraduateCreditMapPageState extends State<GraduateCreditMapPage> {
  late RefreshSection<GraduateCreditMapRead> report;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    report = RefreshSection()..addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool force = false}) {
    final service = widget.service;
    if (service is! GraduateCreditMapGateway) return Future.value();
    final target = report;
    return target.refresh(
      () async {
        GraduateCreditMapRead result;
        try {
          result = await service.graduateCreditMap(forceRefresh: force);
        } on TimeoutException {
          result = const GraduateCreditMapRead(
            issue: GraduateCreditReadIssue(GraduateCreditIssueKind.timeout),
          );
        } catch (_) {
          result = const GraduateCreditMapRead(
            issue: GraduateCreditReadIssue(GraduateCreditIssueKind.unknown),
          );
        }
        final authentication =
            result.issue?.kind == GraduateCreditIssueKind.authentication;
        if (authentication) target.value = null;
        return SectionResult(
          value: authentication || result.data == null ? null : result,
          error:
              result.issue?.message ??
              (result.data == null ? '暂未取得可确认的执行报告' : null),
        );
      },
      fallbackError: '暂未取得可确认的执行报告',
      force: force,
    );
  }

  @override
  void didUpdateWidget(covariant GraduateCreditMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.accountId != widget.accountId) {
      report.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    report.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.service is GraduateCreditMapGateway;
    final read = report.value;
    final data = read?.data;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('graduate-credit-map-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('研究生学分地图'),
            section: '研究生教务',
            subtitle: '学校执行报告的要求、已获与待考核，不等于毕业资格认定',
            icon: CupertinoIcons.chart_bar,
            trailing: AppleGlassButton(
              label: '刷新学分地图',
              onPressed: supported && !report.loading
                  ? () => _load(force: true)
                  : null,
              child: const Icon(CupertinoIcons.refresh),
            ),
          ),
          if (!supported)
            const SliverToBoxAdapter(
              child: GraduateCreditMapNotice('当前服务未接入学分地图；未发起学校读取，不能据此判断接口失效'),
            ),
          if (report.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: GinkgoActivity(size: 24),
              ),
            ),
          if (report.error case final error?)
            SliverToBoxAdapter(
              child: GraduateCreditMapNotice(
                '${data == null ? '' : '保留上次成功内容。'}$error',
                warning: true,
              ),
            ),
          if (read?.stale == true && report.error == null)
            const SliverToBoxAdapter(
              child: GraduateCreditMapNotice(
                '当前显示上次成功内容，尚未取得最新报告',
                warning: true,
              ),
            ),
          if (data != null) ...[
            if (data.notice case final notice?)
              SliverToBoxAdapter(child: GraduateCreditMapNotice(notice)),
            if (data.isEmpty)
              const SliverToBoxAdapter(
                child: GraduateCreditMapNotice('学校返回的执行报告暂无条目'),
              ),
            if (data.summary case final summary?)
              SliverToBoxAdapter(
                child: GraduateCreditMapNodeCard(node: summary, summary: true),
              ),
            if (!data.isEmpty && data.summary == null)
              const SliverToBoxAdapter(
                child: GraduateCreditMapNotice(
                  '未提供可确认的执行报告总进度。以下可能是方案课程池，不推算总学分或毕业缺口。',
                  warning: true,
                ),
              ),
            SliverList.builder(
              itemCount: data.nodes.length,
              itemBuilder: (context, index) =>
                  GraduateCreditMapNodeCard(node: data.nodes[index]),
            ),
            const SliverToBoxAdapter(
              child: GraduateCreditMapNotice(
                '类别、课组和课程可能重叠，不累加为总学分；待考核不计入已获，缺失值显示“未确认”。',
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
