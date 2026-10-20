import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'checkin_page.dart';
import 'bykc_page.dart';
import 'graduate_page.dart';
import 'classroom_page.dart';
import 'coming_soon_page.dart';
import 'grades_page.dart';
import 'mirror_service.dart';
import 'settings_page.dart';
import 'src/rust/api/live.dart' show RouteChoice;

class MorePage extends StatelessWidget {
  const MorePage({
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
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(
          largeTitle: Text('更多'),
          border: null,
        ),
        SliverList.list(
          children: [
            AppleSection(
              children: [
                AppleListTile(
                  leading: const Icon(
                    CupertinoIcons.person_crop_circle_fill,
                    color: AppleDesign.accent,
                    size: 32,
                  ),
                  title: Text(accountName ?? '校园账号'),
                  subtitle: Text(accountId ?? '未获取学号'),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                  minimumHeight: 64,
                  onTap: () => _push(
                    context,
                    SettingsPage(
                      service: service,
                      onSignOut: onSignOut,
                      accountName: accountName,
                      accountId: accountId,
                      route: route,
                    ),
                  ),
                ),
              ],
            ),
            AppleSection(
              header: const Text('工作台'),
              children: [
                _row(
                  context,
                  '课程签到',
                  CupertinoIcons.checkmark_seal_fill,
                  AppleDesign.accent,
                  CheckInPage(service: service),
                ),
                _row(
                  context,
                  '待办',
                  CupertinoIcons.list_bullet,
                  CupertinoColors.systemOrange,
                  const ComingSoonPage(
                    title: '待办',
                    description: '本机待办尚未迁移到 Flutter 镜像。',
                    symbol: CupertinoIcons.list_bullet,
                    details: ['本机待办增删改', '账号隔离与提醒'],
                  ),
                ),
              ],
            ),
            AppleSection(
              header: const Text('学习'),
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
                  '空教室',
                  CupertinoIcons.building_2_fill,
                  CupertinoColors.systemIndigo,
                  ClassroomPage(service: service),
                ),
                _row(
                  context,
                  '博雅',
                  CupertinoIcons.book_solid,
                  CupertinoColors.systemTeal,
                  BykcPage(demo: service.isDemo),
                ),
                _row(
                  context,
                  '研究生教务',
                  CupertinoIcons.building_2_fill,
                  CupertinoColors.systemBrown,
                  GraduatePage(demo: service.isDemo),
                ),
                _row(
                  context,
                  '研讨室',
                  CupertinoIcons.person_3_fill,
                  CupertinoColors.systemPurple,
                  const ComingSoonPage(
                    title: '研讨室',
                    description: '教学楼 CGYY 研讨室需要独立的 CAS 会话、签名与时段数据。',
                    symbol: CupertinoIcons.person_3,
                    details: ['场馆与时段只读', '预约/取消二次确认', '门锁密码仅内存展示'],
                  ),
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
            AppleSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ginkgo 镜像 · 按 iOS 信息层级组织；未迁移模块明确标注，不伪造数据。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
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
