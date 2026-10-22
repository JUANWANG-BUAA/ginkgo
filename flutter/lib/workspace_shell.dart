import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'app_preferences.dart';
import 'application/contracts.dart' show RouteChoice;
import 'course_visibility.dart';
import 'mirror_service.dart';
import 'query_cache_scope.dart';
import 'workspace_back_guard.dart';
import 'workspace_catalog.dart';
import 'reminders.dart';
import 'reminder_badge.dart';
import 'diagnostic_hints.dart';

CupertinoThemeData ginkgoTheme([
  Brightness? brightness,
  Color accent = GinkgoColors.accent,
]) => CupertinoThemeData(
  primaryColor: accent,
  textTheme: CupertinoTextThemeData(
    textStyle: GinkgoTypography.body,
    navTitleTextStyle: const TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: GinkgoColors.label,
    ),
    navLargeTitleTextStyle: GinkgoTypography.largeTitle,
    actionTextStyle: TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 17,
      letterSpacing: -0.25,
      color: accent,
    ),
    dateTimePickerTextStyle: const TextStyle(
      inherit: false,
      fontFamily: GinkgoTypography.font,
      fontFamilyFallback: GinkgoTypography.fallback,
      fontSize: 21,
      color: GinkgoColors.label,
    ),
  ),
  brightness: brightness,
);

Widget ginkgoApp({
  required Widget home,
  Brightness? brightness,
  AppPreferences? preferences,
}) {
  final settings = preferences ?? AppPreferences.shared;
  return ListenableBuilder(
    listenable: settings,
    builder: (context, _) => AppPreferencesScope(
      preferences: settings,
      child: CupertinoApp(
        title: 'Ginkgo 银杏',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalCupertinoLocalizations.delegates,
        theme: ginkgoTheme(
          brightness ?? settings.appearance.brightness,
          settings.accent.color,
        ),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: settings.textSize == 1
                  ? media.textScaler
                  : TextScaler.linear(
                      media.textScaler.scale(14) / 14 * settings.textSize,
                    ),
              disableAnimations:
                  media.disableAnimations || settings.reduceMotion,
            ),
            child: child!,
          );
        },
        home: home,
      ),
    ),
  );
}

/// 工作区外壳：只负责会话切换、移动/桌面布局与功能登记表的消费，
/// 具体页面由 workspace_catalog.dart 登记，壳层不维护功能索引。
class GinkgoApp extends StatelessWidget {
  const GinkgoApp({
    super.key,
    required this.service,
    this.brightness,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final MirrorService service;
  final Brightness? brightness;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  @override
  Widget build(BuildContext context) => ginkgoApp(
    brightness: brightness,
    home: CourseVisibilityScope(
      key: ValueKey(service.isDemo ? 'demo' : accountId ?? 'account'),
      account: service.isDemo ? '__demo__' : accountId ?? '__account__',
      child: ReminderScope(
        service: service,
        account: service.isDemo ? '__demo__' : accountId ?? '__account__',
        child: DiagnosticHintOverlay(
          child: QueryCacheScope(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= GinkgoLayout.desktopBreakpoint
                  ? _DesktopWorkspace(
                      service: service,
                      accountName: accountName,
                      accountId: accountId,
                      route: route,
                      onSignOut: onSignOut,
                    )
                  : _MobileWorkspace(
                      service: service,
                      accountName: accountName,
                      accountId: accountId,
                      route: route,
                      onSignOut: onSignOut,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MobileWorkspace extends StatefulWidget {
  const _MobileWorkspace({
    required this.service,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final MirrorService service;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  @override
  State<_MobileWorkspace> createState() => _MobileWorkspaceState();
}

class _MobileWorkspaceState extends State<_MobileWorkspace> {
  final tabs = CupertinoTabController();
  final back = WorkspaceBackController();

  @override
  void initState() {
    super.initState();
    tabs.addListener(back.disarm);
    tabs.addListener(_readActive);
  }

  @override
  void dispose() {
    tabs.removeListener(back.disarm);
    tabs.removeListener(_readActive);
    back.dispose();
    tabs.dispose();
    super.dispose();
  }

  void _readActive() =>
      ReminderScope.of(context)?.setActive(mobileDestinations[tabs.index].id);

  WorkspaceContext _contextFor(BuildContext navigatorContext) =>
      WorkspaceContext(
        service: widget.service,
        mobile: true,
        accountName: widget.accountName,
        accountId: widget.accountId,
        route: widget.route,
        onSignOut: widget.onSignOut,
        openFeature: (id) {
          final index = mobileDestinations.indexWhere(
            (destination) => destination.id == id,
          );
          if (index >= 0) tabs.index = index;
        },
        openSettings: () => Navigator.of(navigatorContext).push(
          CupertinoPageRoute<void>(
            builder: (_) =>
                destinationById('settings')!
                    .build(_contextFor(navigatorContext)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final destinations = mobileDestinations;
    return guardWorkspaceBack(
      // Keep Android back delivery in Flutter while a newly selected tab's
      // navigator is mounting. Its own first-route guard handles the action.
      onBack: () {},
      child: Stack(
        children: [
          CupertinoTabScaffold(
            controller: tabs,
            tabBar: CupertinoTabBar(
              items: [
                for (final destination in destinations)
                  BottomNavigationBarItem(
                    icon: ReminderBadge(
                      count:
                          ReminderScope.of(context)?.unread(destination.id) ??
                          0,
                      child: Icon(destination.icon),
                    ),
                    label: destination.mobileLabel ?? destination.title,
                  ),
              ],
            ),
            tabBuilder: (tabContext, index) => CupertinoTabView(
              navigatorObservers: [_DisarmExitOnNavigation(back)],
              builder: (navigatorContext) => guardWorkspaceBack(
                onBack: () => back.back(
                  atWorkspace: tabs.index == 0,
                  goToWorkspace: () => tabs.index = 0,
                ),
                child: destinations[index].build(_contextFor(navigatorContext)),
              ),
            ),
          ),
          WorkspaceBackHint(controller: back),
        ],
      ),
    );
  }
}

class _DisarmExitOnNavigation extends NavigatorObserver {
  _DisarmExitOnNavigation(this.back);
  final WorkspaceBackController back;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    back.disarm();
  }
}

class _DesktopWorkspace extends StatefulWidget {
  const _DesktopWorkspace({
    required this.service,
    this.accountName,
    this.accountId,
    this.route,
    this.onSignOut,
  });
  final MirrorService service;
  final String? accountName;
  final String? accountId;
  final RouteChoice? route;
  final Future<void> Function()? onSignOut;
  @override
  State<_DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<_DesktopWorkspace> {
  String selected = 'today';
  final navigators = <String, GlobalKey<NavigatorState>>{};

  /// IndexedStack builds every child, which would fire real read requests for
  /// pages the user never opened. Build a page on first visit and keep it
  /// mounted afterwards so sidebar state survives switching.
  final Set<String> visited = {'today'};

  void select(String id) {
    ReminderScope.of(context)?.setActive(id);
    if (selected == id) {
      navigators[id]?.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      selected = id;
      visited.add(id);
    });
  }

  WorkspaceContext _contextFor() => WorkspaceContext(
    service: widget.service,
    mobile: false,
    accountName: widget.accountName,
    accountId: widget.accountId,
    route: widget.route,
    onSignOut: widget.onSignOut,
    // 移动端专属的“预约”聚合页在桌面没有对应目的地，沿用旧行为落到图书馆。
    openFeature: (id) => select(id == 'reservations' ? 'library' : id),
    openSettings: () => select('settings'),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        key: const Key('desktop-sidebar'),
        width: GinkgoLayout.desktopSidebarWidth,
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sidebarBrandIdentity(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  children: [
                    for (final section in WorkspaceSection.values) ...[
                      _section(section.title),
                      for (final destination in sidebarDestinations(section))
                        _sidebar(destination),
                    ],
                  ],
                ),
              ),
              _sidebarFooter(context),
            ],
          ),
        ),
      ),
      Container(
        width: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
      Expanded(
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: IndexedStack(
            index: workspaceDestinations.indexWhere(
              (destination) => destination.id == selected,
            ),
            children: [
              for (final destination in workspaceDestinations)
                if (visited.contains(destination.id))
                  ExcludeFocus(
                    excluding: selected != destination.id,
                    child: TickerMode(
                      enabled: selected == destination.id,
                      child: CupertinoTabView(
                        key: ValueKey('desktop-destination-${destination.id}'),
                        navigatorKey: navigators.putIfAbsent(
                          destination.id,
                          () => GlobalKey<NavigatorState>(),
                        ),
                        builder: (_) => destination.build(_contextFor()),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _sidebarBrandIdentity(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final isDemo = widget.service.isDemo;
    final accountText = widget.accountName ?? (isDemo ? '离线演示' : '校园工作台');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.16),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: 0.72)],
              ),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.leaf_arrow_circlepath,
                size: 20,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ginkgo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        accountText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDemo
                            ? GinkgoColors.connectionOffline
                            : GinkgoColors.connectionOnline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDemo ? '演示' : '已连接',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarFooter(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.16),
          width: 0.5,
        ),
      ),
    ),
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final destination in footerDestinations) _sidebar(destination),
      ],
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: CupertinoColors.secondaryLabel,
      ),
    ),
  );

  Widget _sidebar(WorkspaceDestination destination) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: AppleNavigationItem(
      key: ValueKey('desktop-sidebar-${destination.id}'),
      title: destination.title,
      unreadCount: ReminderScope.of(context)?.unread(destination.id) ?? 0,
      icon: destination.icon,
      selected: selected == destination.id,
      onPressed: () => select(destination.id),
    ),
  );
}
