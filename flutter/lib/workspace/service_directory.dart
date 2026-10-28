import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/design/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/notices/notices_page.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/workspace/service_search_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;

class ServiceDirectory extends StatelessWidget {
  const ServiceDirectory({
    super.key,
    required this.service,
    required this.onSignOut,
    this.accountName,
    this.accountId,
    this.route,
  });
  final MirrorService service;
  final Future<void> Function() onSignOut;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppleSection(
        children: [
          AppleListTile(
            leading: const Icon(CupertinoIcons.search),
            title: const Text('全部服务 / 搜索服务'),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => _push(
              context,
              ServiceSearchPage(context: _featureContext(context)),
            ),
          ),
        ],
      ),
      AppleSection(
        header: const Text('个人与校园'),
        children: [
          _row(
            context,
            '校园通知',
            CupertinoIcons.news_solid,
            GinkgoColors.resourceBlue,
            NoticesPage(demo: service.isDemo, service: service),
          ),
          _row(
            context,
            '待办',
            CupertinoIcons.list_bullet,
            GinkgoColors.accent,
            TasksPage(demo: service.isDemo, service: service),
          ),
          _destination(context, 'campus-card', GinkgoColors.accent),
          _destination(context, 'shuttle', GinkgoColors.resourceTeal),
        ],
      ),
      AppleSection(
        header: const Text('学业'),
        children: [
          _row(
            context,
            '成绩',
            CupertinoIcons.chart_bar_alt_fill,
            GinkgoColors.resourcePurple,
            GradesPage(service: service),
          ),
          _destination(context, 'learning', GinkgoColors.resourceBlue),
          _row(
            context,
            '博雅',
            CupertinoIcons.book_solid,
            GinkgoColors.resourceTeal,
            BykcPage(demo: service.isDemo, service: service),
          ),
          _row(
            context,
            '研究生教务',
            CupertinoIcons.briefcase_fill,
            GinkgoColors.accent,
            GraduatePage(demo: service.isDemo, service: service),
          ),
        ],
      ),
      AppleSection(
        header: const Text('图书与借阅'),
        children: [
          _destination(context, 'library-loans', GinkgoColors.resourceTeal),
        ],
      ),
      AppleSection(
        children: [
          _row(
            context,
            '设置',
            CupertinoIcons.gear_alt_fill,
            GinkgoColors.statusInactive,
            SettingsPage(
              service: service,
              onSignOut: onSignOut,
              accountName: accountName,
              accountId: accountId,
              route: route,
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
    ],
  );

  WorkspaceContext _featureContext(BuildContext context) => WorkspaceContext(
    service: service,
    mobile: true,
    accountName: accountName,
    accountId: accountId,
    route: route,
    onSignOut: onSignOut,
    openFeature: (id) => _pushDestination(context, id),
    openSettings: () => _pushDestination(context, 'settings'),
  );

  void _pushDestination(BuildContext context, String id) {
    final destination = destinationById(id);
    if (destination != null) {
      _push(context, destination.build(_featureContext(context)));
    }
  }

  // Reuse catalog metadata and factories, including the injected account context.
  Widget _destination(BuildContext context, String id, Color tint) {
    final destination = destinationById(id)!;
    return _row(
      context,
      destination.title,
      destination.icon,
      tint,
      destination.build(_featureContext(context)),
    );
  }

  Widget _row(
    BuildContext context,
    String title,
    IconData icon,
    Color tint,
    Widget page,
  ) => AppleListTile(
    leading: GinkgoIconTile(icon: icon, size: 34, iconSize: 18, color: tint),
    leadingSize: 34,
    title: Text(title),
    trailing: const Icon(
      CupertinoIcons.chevron_right,
      size: 16,
      color: CupertinoColors.tertiaryLabel,
    ),
    onTap: () => _push(context, page),
  );
}
