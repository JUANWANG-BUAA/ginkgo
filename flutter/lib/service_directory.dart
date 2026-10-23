import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'bykc_page.dart';
import 'graduate_page.dart';
import 'tasks_page.dart';
import 'notices_page.dart';
import 'grades_page.dart';
import 'mirror_service.dart';
import 'settings_page.dart';
import 'shuttle_page.dart';
import 'application/contracts.dart' show RouteChoice;

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
        header: const Text('个人与校园'),
        children: [
          _row(
            context,
            '校园通知',
            CupertinoIcons.news_solid,
            CupertinoColors.systemBlue,
            NoticesPage(demo: service.isDemo, service: service),
          ),
          _row(
            context,
            '待办',
            CupertinoIcons.list_bullet,
            CupertinoColors.systemOrange,
            TasksPage(demo: service.isDemo, service: service),
          ),
          _row(
            context,
            '校车时刻表',
            CupertinoIcons.bus,
            CupertinoColors.systemIndigo,
            ShuttlePage(service: service),
          ),
        ],
      ),
      AppleSection(
        header: const Text('学业'),
        children: [
          _row(
            context,
            '成绩',
            CupertinoIcons.chart_bar_alt_fill,
            CupertinoColors.systemPink,
            GradesPage(service: service),
          ),
          _row(
            context,
            '博雅',
            CupertinoIcons.book_solid,
            CupertinoColors.systemTeal,
            BykcPage(demo: service.isDemo, service: service),
          ),
          _row(
            context,
            '研究生教务',
            CupertinoIcons.building_2_fill,
            CupertinoColors.systemBrown,
            GraduatePage(demo: service.isDemo, service: service),
          ),
        ],
      ),
      AppleSection(
        children: [
          _row(
            context,
            '设置',
            CupertinoIcons.gear_alt_fill,
            CupertinoColors.systemGrey,
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

  Widget _row(
    BuildContext context,
    String title,
    IconData icon,
    Color tint,
    Widget page,
  ) => AppleListTile(
    leading: Icon(icon, color: tint, size: 22),
    title: Text(title),
    trailing: const Icon(
      CupertinoIcons.chevron_right,
      size: 16,
      color: CupertinoColors.tertiaryLabel,
    ),
    onTap: () => _push(context, page),
  );
}
