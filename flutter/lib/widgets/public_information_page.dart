import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class PublicInformationPage<T, Q> extends StatefulWidget {
  const PublicInformationPage({
    super.key,
    required this.service,
    required this.initialQuery,
    required this.read,
    required this.queryBuilder,
    required this.contentBuilder,
    required this.scrollKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.refreshLabel,
    required this.loadingLabel,
    required this.unsupportedTitle,
    this.section = '资讯与就业',
  });

  /// The typed port this page reads. `null` means the current service does not
  /// offer the capability, and the page shows that explicitly.
  final Object? service;
  final Q initialQuery;
  final Future<SectionResult<T>> Function(Q query, bool forceRefresh) read;
  final Widget Function(
    BuildContext context,
    Q query,
    bool loading,
    ValueChanged<Q> select,
  )
  queryBuilder;
  final Widget Function(BuildContext context, T data) contentBuilder;
  final Key scrollKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final String refreshLabel;
  final String loadingLabel;
  final String unsupportedTitle;
  final String section;

  @override
  State<PublicInformationPage<T, Q>> createState() =>
      _PublicInformationPageState<T, Q>();
}

class _PublicInformationPageState<T, Q>
    extends State<PublicInformationPage<T, Q>> {
  late final RefreshSection<T> section;
  late Q query = widget.initialQuery;

  @override
  void initState() {
    super.initState();
    section = RefreshSection<T>()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    load();
  }

  @override
  void didUpdateWidget(PublicInformationPage<T, Q> oldWidget) {
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
    if (widget.service == null) return Future.value();
    final currentQuery = query;
    return section.refresh(
      () => widget.read(currentQuery, force),
      fallbackError: failureMessage(null),
      force: force,
    );
  }

  void select(Q value) {
    if (value == query) return;
    section
      ..invalidate()
      ..value = null
      ..error = null
      ..failure = null;
    setState(() => query = value);
    load(force: true);
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: widget.scrollKey,
      slivers: [
        AppleRefreshPageHeader(
          title: widget.title,
          section: widget.section,
          subtitle: widget.subtitle,
          icon: widget.icon,
          refreshLabel: widget.refreshLabel,
          busy: section.loading,
          onRefresh: () => load(force: true),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            if (widget.service == null)
              AppleStatusSection(
                title: widget.unsupportedTitle,
                description: '请连接真实服务后重试。',
                error: true,
              )
            else ...[
              widget.queryBuilder(context, query, section.loading, select),
              if (section.error != null)
                AppleStatusSection(
                  title: section.error!,
                  description: failureAdvice(
                    hasStaleValue: section.value != null,
                    failure: section.failure,
                  ),
                  onAction: () => load(force: true),
                  error: true,
                ),
              if (section.value == null && section.loading)
                AppleSection(
                  children: [GinkgoLoadingView(label: widget.loadingLabel)],
                ),
              if (section.value case final data?)
                widget.contentBuilder(context, data),
              Padding(padding: GinkgoSpacing.edgeInsetsPage),
            ],
          ],
        ),
      ],
    ),
  );
}
