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

CupertinoThemeData ginkgoTheme([
  Brightness? brightness,
  Color accent = AppleDesign.accent,
]) => CupertinoThemeData(
  primaryColor: accent,
  textTheme: CupertinoTextThemeData(
    textStyle: AppleDesign.body,
    navTitleTextStyle: const TextStyle(
      inherit: false,
      fontFamily: AppleDesign.font,
      fontFamilyFallback: AppleDesign.fallback,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: CupertinoColors.label,
    ),
    navLargeTitleTextStyle: AppleDesign.title,
    actionTextStyle: TextStyle(
      inherit: false,
      fontFamily: AppleDesign.font,
      fontFamilyFallback: AppleDesign.fallback,
      fontSize: 17,
      letterSpacing: -0.25,
      color: accent,
    ),
    dateTimePickerTextStyle: const TextStyle(
      inherit: false,
      fontFamily: AppleDesign.font,
      fontFamilyFallback: AppleDesign.fallback,
      fontSize: 21,
      color: CupertinoColors.label,
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
      child: QueryCacheScope(
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 760
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
  }

  @override
  void dispose() {
    tabs.removeListener(back.disarm);
    back.dispose();
    tabs.dispose();
    super.dispose();
  }

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
                    icon: Icon(destination.icon),
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
        width: 232,
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Text(
                  'Ginkgo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final section in WorkspaceSection.values) ...[
                      _section(section.title),
                      for (final destination in sidebarDestinations(section))
                        _sidebar(destination),
                    ],
                  ],
                ),
              ),
              for (final destination in footerDestinations)
                _sidebar(destination),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  widget.accountName ??
                      (widget.service.isDemo ? '离线演示' : '学校账户'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Container(
        width: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
      Expanded(
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
    ],
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel,
      ),
    ),
  );

  Widget _sidebar(WorkspaceDestination destination) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: AppleNavigationItem(
      key: ValueKey('desktop-sidebar-${destination.id}'),
      title: destination.title,
      icon: destination.icon,
      selected: selected == destination.id,
      onPressed: () => select(destination.id),
    ),
  );
}
