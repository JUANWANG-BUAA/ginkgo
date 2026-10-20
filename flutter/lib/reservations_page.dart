import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'cgyy_page.dart';
import 'classroom_page.dart';
import 'library_page.dart';
import 'mirror_service.dart';

/// Resource hub does not start all service logins in the background.
class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key, required this.service});
  final MirrorService service;

  void open(BuildContext context, Widget page) =>
      Navigator.of(context)
          .push(CupertinoPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(
          largeTitle: Text('预约'),
          border: null,
        ),
        SliverList.list(
          children: [
            AppleSection(
              header: const Text('空间与我的预约'),
              children: [
                _resource(
                  context,
                  '图书馆座位',
                  '查看我的预约，按馆区查找座位',
                  CupertinoIcons.book_fill,
                  CupertinoColors.systemBlue,
                  LibraryPage(service: service),
                ),
                _resource(
                  context,
                  '研讨室与场馆',
                  '查看场地、可用时段与订单',
                  CupertinoIcons.person_3_fill,
                  CupertinoColors.systemPurple,
                  CgyyPage(demo: service.isDemo),
                ),
              ],
            ),
            AppleSection(
              header: const Text('寻找学习空间'),
              footer: const Text('空闲查询不保证现场可用，也不会占用教室。'),
              children: [
                _resource(
                  context,
                  '空教室',
                  '按校区、日期与节次查询',
                  CupertinoIcons.building_2_fill,
                  CupertinoColors.systemTeal,
                  ClassroomPage(service: service),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '当前可查询资源与已有预约；预约提交、入座签到及取消尚未开放。',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _resource(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    CupertinoDynamicColor color,
    Widget page,
  ) => AppleListTile(
    minimumHeight: 100,
    leading: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.resolveFrom(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color.resolveFrom(context), size: 26),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle),
    trailing: const CupertinoListTileChevron(),
    onTap: () => open(context, page),
  );
}
