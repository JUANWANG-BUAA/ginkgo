import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apple_widgets.dart';
import 'bykc_page.dart';
import 'graduate_page.dart';
import 'tasks_page.dart';
import 'notices_page.dart';
import 'grades_page.dart';
import 'mirror_service.dart';
import 'settings_page.dart';
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
          _externalRow(
            context,
            '校车时刻表',
            CupertinoIcons.bus,
            CupertinoColors.systemIndigo,
            // Official public timetable only. Live seat counts need a captured
            // query transaction we do not have, so nothing is scraped or guessed.
            Uri.parse('https://www.buaa.edu.cn/info/1065/1762.htm'),
            detail: '在官方页面查看两校区班次与沙河摆渡车时刻。应用内不代理购票，'
                '也不显示实时余票（该查询协议尚未取证）。',
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

  /// Opens a school page in the system browser instead of pretending the
  /// capability is integrated. The dialog states exactly what is not covered.
  Widget _externalRow(
    BuildContext context,
    String title,
    IconData icon,
    Color tint,
    Uri url, {
    required String detail,
  }) => AppleListTile(
    leading: Icon(icon, color: tint, size: 22),
    title: Text(title),
    subtitle: const Text('官方页面 · 只读'),
    trailing: const Icon(
      CupertinoIcons.arrow_up_right_square,
      size: 16,
      color: CupertinoColors.tertiaryLabel,
    ),
    onTap: () async {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('去官方页面'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      // A missing browser (or a refused launch) must never leave the tap silent.
      var opened = false;
      try {
        opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
      if (opened) return;
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('未能打开浏览器'),
          content: Text('请手动访问：\n$url'),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context);
                }
              },
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    },
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
