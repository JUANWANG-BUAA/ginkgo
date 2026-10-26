import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_page.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_page.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_page.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/notices/notices_page.dart';
import 'package:ginkgo_mirror/features/reservations/reservations_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show RouteChoice;
import 'package:ginkgo_mirror/application/library_loans.dart';

/// 侧栏分组。顺序即桌面侧栏的呈现顺序；新增功能只登记到既有分组即可。
enum WorkspaceSection {
  workbench('工作台'),
  academics('学业'),
  spaces('空间资源'),
  campus('校园');

  const WorkspaceSection(this.title);
  final String title;
}

/// 功能页面构建上下文：页面只拿到服务与工作区导航能力，不接触壳层状态。
class WorkspaceContext {
  const WorkspaceContext({
    required this.service,
    required this.mobile,
    required this.openFeature,
    required this.openSettings,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });

  final MirrorService service;
  final bool mobile;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  final ValueChanged<String> openFeature;
  final VoidCallback openSettings;
}

/// 一次功能登记：标题、图标、所在分组、移动端标签位置与页面构建器。
///
/// 这是壳层与功能页之间唯一的登记点：移动端标签、桌面侧栏、今日快捷入口与
/// 工作区返回逻辑都从 [workspaceDestinations] 派生。登记是编译期静态表，
/// 不做运行时插件加载或远程下发；新增功能仍需显式接入并重新构建。
class WorkspaceDestination {
  const WorkspaceDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.build,
    this.mobileLabel,
    this.section,
    this.mobileTab,
    this.sidebar = true,
    this.footer = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final Widget Function(WorkspaceContext context) build;

  /// 移动端标签文案，默认沿用侧栏标题。
  final String? mobileLabel;

  /// 桌面侧栏分组；为 null 表示不进入分组列表。
  final WorkspaceSection? section;

  /// 移动端标签顺序；为 null 表示不是一级标签，只能从其它入口进入。
  final int? mobileTab;

  /// 是否进入桌面侧栏分组列表。
  final bool sidebar;

  /// 是否固定在桌面侧栏底部（设置类入口）。
  final bool footer;
}

/// 功能登记表。id 是稳定标识，供导航、快捷入口与测试引用；不要用索引当标识。
final List<WorkspaceDestination> workspaceDestinations = List.unmodifiable([
  WorkspaceDestination(
    id: 'today',
    title: '今天',
    mobileLabel: '工作台',
    icon: CupertinoIcons.sun_max,
    section: WorkspaceSection.workbench,
    mobileTab: 0,
    build: (context) => TodayPage(
      service: context.service,
      accountName: context.accountName,
      accountId: context.accountId,
      onAccountAction: context.onSignOut,
      onOpenSettings: context.openSettings,
      onOpenFeature: context.openFeature,
      shortcutChoices: [
        for (final destination in workspaceDestinations)
          if (destination.id != 'today' && destination.id != 'settings')
            WorkspaceShortcut(
              id: destination.id,
              title: switch (destination.id) {
                'schedule' => '查看课表',
                'reservations' => '空间预约',
                _ => destination.title,
              },
              icon: destination.icon,
            ),
      ],
      directory: context.mobile
          ? ServiceDirectory(
              service: context.service,
              accountName: context.accountName,
              accountId: context.accountId,
              route: context.route,
              onSignOut: context.onSignOut ?? () async {},
            )
          : null,
    ),
  ),
  WorkspaceDestination(
    id: 'tasks',
    title: '待办',
    icon: CupertinoIcons.list_bullet,
    section: WorkspaceSection.workbench,
    build: (context) =>
        TasksPage(demo: context.service.isDemo, service: context.service),
  ),
  WorkspaceDestination(
    id: 'checkin',
    title: '课程签到',
    mobileLabel: '签到',
    icon: CupertinoIcons.checkmark_seal,
    section: WorkspaceSection.workbench,
    mobileTab: 1,
    build: (context) => CheckInPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'schedule',
    title: '课表',
    icon: CupertinoIcons.calendar,
    section: WorkspaceSection.academics,
    mobileTab: 2,
    build: (context) => SchedulePage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'grades',
    title: '成绩',
    icon: CupertinoIcons.chart_bar_alt_fill,
    section: WorkspaceSection.academics,
    build: (context) => GradesPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'homework',
    title: '学校作业',
    mobileLabel: '作业',
    icon: CupertinoIcons.doc_text,
    section: WorkspaceSection.academics,
    mobileTab: 3,
    build: (context) => HomeworkPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'learning',
    title: 'SPOC 学习',
    icon: CupertinoIcons.book_circle,
    section: WorkspaceSection.academics,
    build: (context) =>
        LearningPage(service: context.service, accountId: context.accountId),
  ),
  WorkspaceDestination(
    id: 'bykc',
    title: '博雅',
    icon: CupertinoIcons.book_solid,
    section: WorkspaceSection.academics,
    build: (context) =>
        BykcPage(demo: context.service.isDemo, service: context.service),
  ),
  WorkspaceDestination(
    id: 'graduate',
    title: '研究生教务',
    icon: CupertinoIcons.briefcase_fill,
    section: WorkspaceSection.academics,
    build: (context) =>
        GraduatePage(demo: context.service.isDemo, service: context.service),
  ),
  WorkspaceDestination(
    id: 'graduate-credit-map',
    title: '研究生学分图',
    icon: CupertinoIcons.chart_bar,
    section: WorkspaceSection.academics,
    build: (context) => GraduateCreditMapPage(
      service: context.service,
      accountId: context.accountId,
    ),
  ),
  WorkspaceDestination(
    id: 'library-loans',
    title: '本人借阅',
    icon: CupertinoIcons.bookmark,
    section: WorkspaceSection.spaces,
    build: (context) => LibraryLoansPage(
      gateway: context.service is LibraryLoansGateway
          ? context.service as LibraryLoansGateway
          : null,
    ),
  ),
  WorkspaceDestination(
    id: 'library',
    title: '图书馆',
    icon: CupertinoIcons.book,
    section: WorkspaceSection.spaces,
    build: (context) => LibraryPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'cgyy',
    title: '研讨室',
    icon: CupertinoIcons.person_3,
    section: WorkspaceSection.spaces,
    build: (context) =>
        CgyyPage(demo: context.service.isDemo, service: context.service),
  ),
  WorkspaceDestination(
    id: 'classroom',
    title: '空教室',
    icon: CupertinoIcons.building_2_fill,
    section: WorkspaceSection.spaces,
    build: (context) => ClassroomPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'notices',
    title: '校园通知',
    icon: CupertinoIcons.news_solid,
    section: WorkspaceSection.campus,
    build: (context) =>
        NoticesPage(demo: context.service.isDemo, service: context.service),
  ),
  WorkspaceDestination(
    id: 'reservations',
    title: '预约',
    icon: CupertinoIcons.square_stack_3d_up,
    mobileTab: 4,
    sidebar: false,
    build: (context) => ReservationsPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'settings',
    title: '设置',
    icon: CupertinoIcons.gear_alt,
    sidebar: false,
    footer: true,
    build: (context) => SettingsPage(
      service: context.service,
      accountName: context.accountName,
      accountId: context.accountId,
      route: context.route,
      onSignOut: context.onSignOut ?? () async {},
    ),
  ),
]);

/// 按 id 查找；壳层与今日快捷入口只使用字符串标识。
WorkspaceDestination? destinationById(String id) {
  for (final destination in workspaceDestinations) {
    if (destination.id == id) return destination;
  }
  return null;
}

/// 移动端一级标签，按 [WorkspaceDestination.mobileTab] 排序。
List<WorkspaceDestination> get mobileDestinations {
  final tabs =
      workspaceDestinations
          .where((destination) => destination.mobileTab != null)
          .toList()
        ..sort((left, right) => left.mobileTab!.compareTo(right.mobileTab!));
  return tabs;
}

/// 某个侧栏分组内的条目，顺序即登记顺序。
List<WorkspaceDestination> sidebarDestinations(WorkspaceSection section) =>
    workspaceDestinations
        .where(
          (destination) =>
              destination.sidebar && destination.section == section,
        )
        .toList(growable: false);

/// 固定在侧栏底部的入口。
List<WorkspaceDestination> get footerDestinations => workspaceDestinations
    .where((destination) => destination.footer)
    .toList(growable: false);
