import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'checkin_page.dart';
import 'classroom_page.dart';
import 'tasks_page.dart';
import 'bykc_page.dart';
import 'graduate_page.dart';
import 'notices_page.dart';
import 'cgyy_page.dart';
import 'grades_page.dart';
import 'homework_page.dart';
import 'library_page.dart';
import 'login_page.dart';
import 'startup_page.dart';
import 'query_cache_scope.dart';
import 'service_directory.dart';
import 'reservations_page.dart';
import 'mirror_service.dart';
import 'rules_page.dart';
import 'schedule_page.dart';
import 'settings_page.dart';
import 'src/rust/api/live.dart' show RouteChoice, SessionResponse, SessionState;
import 'src/rust/frb_generated.dart';
import 'today_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
    runApp(const GinkgoRoot());
  } catch (_) {
    runApp(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('本地服务启动失败，请重试'),
                CupertinoButton(onPressed: main, child: const Text('重新启动')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chooses between the real-account session and the explicit offline demo.
/// The workspace itself stays a plain widget so page tests can inject a fake
/// service without touching Rust or a keychain.
class GinkgoRoot extends StatefulWidget {
  const GinkgoRoot({
    super.key,
    this.liveService = const NativeMirrorService(),
    this.demoService = const DemoMirrorService(),
  });
  final MirrorService liveService;
  final MirrorService demoService;
  @override
  State<GinkgoRoot> createState() => _GinkgoRootState();
}

enum _Stage { restoring, signedOut, signedIn, demo }

class _GinkgoRootState extends State<GinkgoRoot> {
  _Stage stage = _Stage.restoring;
  SessionResponse? session;
  String? message;
  bool captchaRequired = false;

  @override
  void initState() {
    super.initState();
    // Let the startup page paint before touching JNI/Keystore/network work.
    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
  }

  Future<void> restore() async {
    setState(() {
      stage = _Stage.restoring;
      message = null;
    });
    try {
      final response = await widget.liveService.restoreSession();
      if (!mounted) return;
      if (response.state == SessionState.signedIn) {
        setState(() {
          session = response;
          stage = _Stage.signedIn;
        });
        return;
      }
      setState(() {
        session = null;
        stage = _Stage.signedOut;
        captchaRequired = response.state == SessionState.captchaRequired;
        message = captchaRequired
            ? '学校要求验证码，请重新登录。验证码图片展示尚未接入。'
            : response.failure == null
            ? null
            : failureMessage(response.failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        stage = _Stage.signedOut;
        message = failureMessage(null);
      });
    }
  }

  Future<void> signOut() async {
    await widget.liveService.signOut();
    if (!mounted) return;
    setState(() {
      session = null;
      stage = _Stage.signedOut;
      message = null;
    });
  }

  void signedIn(SessionResponse response) => setState(() {
    session = response;
    stage = _Stage.signedIn;
    captchaRequired = false;
    message = null;
  });

  @override
  Widget build(BuildContext context) => switch (stage) {
    _Stage.restoring => ginkgoApp(home: const StartupPage()),
    _Stage.demo => GinkgoApp(
      service: widget.demoService,
      onSignOut: () async => setState(() => stage = _Stage.signedOut),
    ),
    _Stage.signedOut => ginkgoApp(
      home: LoginPage(
        service: widget.liveService,
        initialMessage: message,
        initialCaptcha: captchaRequired,
        onSignedIn: signedIn,
        onDemo: () => setState(() {
          stage = _Stage.demo;
          captchaRequired = false;
          message = null;
        }),
      ),
    ),
    _Stage.signedIn => GinkgoApp(
      service: widget.liveService,
      accountName: session?.name ?? session?.account,
      accountId: session?.account,
      route: session?.route,
      onSignOut: signOut,
    ),
  };
}

CupertinoThemeData ginkgoTheme([Brightness? brightness]) => CupertinoThemeData(
  primaryColor: AppleDesign.accent,
  textTheme: const CupertinoTextThemeData(
    textStyle: AppleDesign.body,
    navTitleTextStyle: TextStyle(
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
      color: AppleDesign.accent,
    ),
    dateTimePickerTextStyle: TextStyle(
      inherit: false,
      fontFamily: AppleDesign.font,
      fontFamilyFallback: AppleDesign.fallback,
      fontSize: 21,
      color: CupertinoColors.label,
    ),
  ),
  brightness: brightness,
);

CupertinoApp ginkgoApp({required Widget home, Brightness? brightness}) =>
    CupertinoApp(
      title: 'Ginkgo 银杏',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalCupertinoLocalizations.delegates,
      theme: ginkgoTheme(brightness),
      home: home,
    );

class GinkgoApp extends StatelessWidget {
  const GinkgoApp({
    super.key,
    this.service = const DemoMirrorService(),
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
    home: QueryCacheScope(
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
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Widget settings() => SettingsPage(
    service: widget.service,
    accountName: widget.accountName,
    accountId: widget.accountId,
    route: widget.route,
    onSignOut: widget.onSignOut ?? () async {},
  );

  @override
  Widget build(BuildContext context) => CupertinoTabScaffold(
    controller: tabs,
    tabBar: CupertinoTabBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.square_grid_2x2),
          label: '工作台',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.checkmark_seal),
          label: '签到',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.calendar),
          label: '课表',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.doc_text),
          label: '作业',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.square_stack_3d_up),
          label: '预约',
        ),
      ],
    ),
    tabBuilder: (_, index) => CupertinoTabView(
      builder: (context) => switch (index) {
        0 => TodayPage(
          service: widget.service,
          accountName: widget.accountName,
          onAccountAction: widget.onSignOut,
          onOpenSettings: () =>
              Navigator.of(context)
                  .push(CupertinoPageRoute<void>(builder: (_) => settings())),
          onOpenFeature: (index) => tabs.index = index,
          directory: ServiceDirectory(
            service: widget.service,
            accountName: widget.accountName,
            accountId: widget.accountId,
            route: widget.route,
            onSignOut: widget.onSignOut ?? () async {},
          ),
        ),
        1 => CheckInPage(service: widget.service),
        2 => SchedulePage(service: widget.service),
        3 => HomeworkPage(service: widget.service),
        _ => ReservationsPage(service: widget.service),
      },
    ),
  );
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
  int selected = 0;

  /// IndexedStack builds every child, which would fire real read requests for
  /// pages the user never opened. Build a page on first visit and keep it
  /// mounted afterwards so sidebar state survives switching.
  final Set<int> visited = {0};
  Future<void> _signOut() => widget.onSignOut?.call() ?? Future.value();

  void select(int index) => setState(() {
    selected = index;
    visited.add(index);
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
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
                    _section('工作台'),
                    _sidebar('今天', CupertinoIcons.sun_max, 0),
                    _sidebar('待办', CupertinoIcons.list_bullet, 7),
                    _sidebar('课程签到', CupertinoIcons.checkmark_seal, 1),
                    _section('学业'),
                    _sidebar('课表', CupertinoIcons.calendar, 2),
                    _sidebar('成绩', CupertinoIcons.chart_bar_alt_fill, 3),
                    _sidebar('作业', CupertinoIcons.doc_text, 4),

                    _sidebar('博雅', CupertinoIcons.book_solid, 10),
                    _sidebar('研究生教务', CupertinoIcons.building_2_fill, 11),
                    _section('空间资源'),
                    _sidebar('图书馆', CupertinoIcons.book, 6),

                    _sidebar('研讨室', CupertinoIcons.person_3, 13),
                    _sidebar('空教室', CupertinoIcons.building_2_fill, 5),
                    _section('校园'),
                    _sidebar('校园通知', CupertinoIcons.news_solid, 12),
                  ],
                ),
              ),
              _sidebar('设置', CupertinoIcons.gear_alt, 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.accountName ??
                          (widget.service.isDemo ? '离线合成样例' : '未登录'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    if (widget.accountId != null)
                      Text(
                        widget.accountId!,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.tertiaryLabel,
                        ),
                      ),
                    if (widget.onSignOut != null) ...[
                      const SizedBox(height: 6),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        onPressed: () => widget.onSignOut!(),
                        child: Text(
                          widget.service.isDemo ? '返回登录' : '退出登录',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ],
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
          index: selected,
          children: [
            for (var index = 0; index < 14; index++)
              if (visited.contains(index))
                _page(index)
              else
                const SizedBox.shrink(),
          ],
        ),
      ),
    ],
  );

  Widget _page(int index) => switch (index) {
    0 => TodayPage(
      service: widget.service,
      accountName: widget.accountName,
      onAccountAction: widget.onSignOut,
    ),
    1 => CheckInPage(service: widget.service),
    2 => SchedulePage(service: widget.service),
    3 => GradesPage(service: widget.service),
    4 => HomeworkPage(service: widget.service),
    5 => ClassroomPage(service: widget.service),
    6 => LibraryPage(service: widget.service),
    7 => TasksPage(demo: widget.service.isDemo),
    8 => SettingsPage(
      service: widget.service,
      onSignOut: _signOut,
      accountName: widget.accountName,
      accountId: widget.accountId,
      route: widget.route,
    ),
    10 => BykcPage(demo: widget.service.isDemo),
    11 => GraduatePage(demo: widget.service.isDemo),
    12 => NoticesPage(demo: widget.service.isDemo),
    13 => CgyyPage(demo: widget.service.isDemo),
    _ => RulesPage(service: widget.service),
  };

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

  Widget _sidebar(String title, IconData icon, int index) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: AppleNavigationItem(
      title: title,
      icon: icon,
      selected: selected == index,
      onPressed: () => select(index),
    ),
  );
}
