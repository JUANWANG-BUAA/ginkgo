import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/features/campus_card/campus_card_page.dart';
import 'package:ginkgo_mirror/features/campus/campus_activities_page.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_page.dart';
import 'package:ginkgo_mirror/features/career/career_events_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/application/graduate.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_page.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_page.dart';
import 'package:ginkgo_mirror/features/notices/notices_page.dart';
import 'package:ginkgo_mirror/features/reservations/reservations_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_page.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';

import 'package:ginkgo_mirror/workspace/workspace_types.dart';

export 'package:ginkgo_mirror/workspace/workspace_types.dart'
    show WorkspaceContext, WorkspaceDestination, WorkspaceSection;

/// 功能登记表。id 是稳定标识，供导航、快捷入口与测试引用；不要用索引当标识。
final List<WorkspaceDestination> workspaceDestinations = List.unmodifiable([
  WorkspaceDestination(
    id: 'today',
    title: '今天',
    mobileLabel: '工作台',
    icon: CupertinoIcons.sun_max,
    section: WorkspaceSection.workbench,
    mobileTab: 0,
    build: (context) => TodayPage(fileActions: context.platformActions,
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
              platformActions: context.platformActions,
              destinations: workspaceDestinations,
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
        TasksPage(fileActions: context.platformActions,service: context.service),
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
    build: (context) => HomeworkPage(fileActions: context.platformActions,service: context.service),
  ),
  WorkspaceDestination(
    id: 'learning',
    title: 'SPOC 学习',
    icon: CupertinoIcons.book_circle,
    section: WorkspaceSection.academics,
    build: (context) =>
        LearningPage(fileActions: context.platformActions,service: context.service, accountId: context.accountId),
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
    build: (context) => GraduatePage(
      service: context.service,
      creditMapGateway: context.capabilities.graduateCreditMap,
    ),
  ),
  WorkspaceDestination(
    id: 'graduate-credit-map',
    title: '研究生学分图',
    icon: CupertinoIcons.chart_bar,
    section: WorkspaceSection.academics,
    sidebar: false,
    build: (context) => GraduatePage(
      service: context.service,
      creditMapGateway: context.capabilities.graduateCreditMap,
      initialView: GraduateView.credits,
    ),
  ),
  WorkspaceDestination(
    id: 'library-loans',
    title: '本人借阅',
    icon: CupertinoIcons.bookmark,
    section: WorkspaceSection.spaces,
    build: (context) => LibraryLoansPage(
      gateway: context.capabilities.libraryLoans,
      officialGateway: context.capabilities.libraryLoansOfficial,
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
    build: (context) => CgyyPage(
      demo: context.service.isDemo,
      service: context.service,
      bookingGateway: context.capabilities.cgyyBooking,
    ),
  ),
  WorkspaceDestination(
    id: 'classroom',
    title: '空教室',
    icon: CupertinoIcons.building_2_fill,
    section: WorkspaceSection.spaces,
    build: (context) => ClassroomPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'campus-card',
    title: '校园卡',
    icon: CupertinoIcons.creditcard,
    section: WorkspaceSection.campus,
    build: (context) =>
        CampusCardPage(gateway: context.capabilities.campusCard),
  ),
  WorkspaceDestination(
    id: 'notices',
    title: '校园通知',
    icon: CupertinoIcons.news_solid,
    section: WorkspaceSection.campus,
    build: (context) =>
        NoticesPage(service: context.service),
  ),
  WorkspaceDestination(
    id: 'career-events',
    title: '就业活动',
    icon: CupertinoIcons.briefcase,
    section: WorkspaceSection.campus,
    build: (context) =>
        CareerEventsPage(service: context.capabilities.careerEvents),
  ),
  WorkspaceDestination(
    id: 'campus-activities',
    title: '学术文化',
    icon: CupertinoIcons.music_note,
    section: WorkspaceSection.campus,
    build: (context) =>
        CampusActivitiesPage(service: context.capabilities.campusActivities),
  ),
  WorkspaceDestination(
    id: 'shuttle',
    title: '校车时刻表',
    icon: CupertinoIcons.bus,
    section: WorkspaceSection.campus,
    sidebar: false,
    build: (context) => ShuttlePage(service: context.service),
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
    build: (context) => SettingsPage(maintenance: context.platformActions.maintenance,
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
