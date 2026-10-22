import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'apple_design.dart';
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
        const ApplePageHeader(largeTitle: Text('预约'), border: null),
        SliverLayoutBuilder(
          builder: (context, constraints) => SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ((constraints.crossAxisExtent - 820) / 2).clamp(
                0,
                double.infinity,
              ),
            ),
            sliver: SliverList.list(
              children: [
                AppleSection(
                  header: const Text('空间与我的预约'),
                  children: [
                    _resource(
                      context,
                      '图书馆座位',
                      '选座预约、查看记录与管理入座状态',
                      CupertinoIcons.book_fill,
                      AppleDesign.resourceBlue,
                      LibraryPage(service: service),
                    ),
                    _resource(
                      context,
                      '研讨室与场馆',
                      '查看场地、可用时段与订单',
                      CupertinoIcons.person_3_fill,
                      AppleDesign.resourcePurple,
                      CgyyPage(demo: service.isDemo, service: service),
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
                      AppleDesign.resourceTeal,
                      ClassroomPage(service: service),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '图书馆支持选座与预约管理；研讨室和场馆提供查询，提交以各页面提示为准。',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  ) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: () => open(context, page),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.resolveFrom(context).withValues(alpha: 0.09),
            color.resolveFrom(context).withValues(alpha: 0.015),
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.resolveFrom(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color.resolveFrom(context), size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      title == '图书馆座位'
                          ? '选择座位'
                          : title == '空教室'
                          ? '查询空闲'
                          : '查看时段',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.arrow_right,
                      size: 15,
                      color: color.resolveFrom(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
