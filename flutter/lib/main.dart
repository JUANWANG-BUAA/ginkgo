import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'classroom_page.dart';
import 'grades_page.dart';
import 'homework_page.dart';
import 'login_page.dart';
import 'mirror_service.dart';
import 'rules_page.dart';
import 'schedule_page.dart';
import 'src/rust/api/live.dart' show SessionResponse, SessionState;
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
    _Stage.restoring => ginkgoApp(home: const _StartupPage()),
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

class _StartupPage extends StatelessWidget {
  const _StartupPage();
  @override
  Widget build(BuildContext context) => const CupertinoPageScaffold(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 14),
          SizedBox(height: 14),
          Text('正在恢复本地会话…'),
        ],
      ),
    ),
  );
}

class GinkgoApp extends StatelessWidget {
  const GinkgoApp({
    super.key,
    this.service = const DemoMirrorService(),
    this.brightness,
    this.accountName,
    this.onSignOut,
  });
  final MirrorService service;
  final Brightness? brightness;
  final String? accountName;
  final Future<void> Function()? onSignOut;
  @override
  Widget build(BuildContext context) => ginkgoApp(
    brightness: brightness,
    home: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 760
          ? _DesktopWorkspace(
              service: service,
              accountName: accountName,
              onSignOut: onSignOut,
            )
          : CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.sun_max),
                    label: '今天',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.building_2_fill),
                    label: '空教室',
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
                    icon: Icon(CupertinoIcons.chart_bar_alt_fill),
                    label: '成绩',
                  ),
                ],
              ),
              tabBuilder: (context, index) => switch (index) {
                0 => TodayPage(
                  service: service,
                  accountName: accountName,
                  onAccountAction: onSignOut,
                ),
                1 => ClassroomPage(service: service),
                2 => SchedulePage(service: service),
                3 => HomeworkPage(service: service),
                _ => GradesPage(service: service),
              },
            ),
    ),
  );
}

class _DesktopWorkspace extends StatefulWidget {
  const _DesktopWorkspace({
    required this.service,
    this.accountName,
    this.onSignOut,
  });
  final MirrorService service;
  final String? accountName;
  final Future<void> Function()? onSignOut;
  @override
  State<_DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<_DesktopWorkspace> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 220,
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Ginkgo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 16, bottom: 8),
                child: Text(
                  '校园',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
              _sidebar('今天', CupertinoIcons.sun_max, 0),
              _sidebar('空教室', CupertinoIcons.building_2_fill, 1),
              _sidebar('课表', CupertinoIcons.calendar, 2),
              _sidebar('作业', CupertinoIcons.doc_text, 3),
              _sidebar('成绩', CupertinoIcons.chart_bar_alt_fill, 4),
              _sidebar('规则示例', CupertinoIcons.checkmark_shield, 5),
              const Spacer(),
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
            TodayPage(
              service: widget.service,
              accountName: widget.accountName,
              onAccountAction: widget.onSignOut,
            ),
            ClassroomPage(service: widget.service),
            SchedulePage(service: widget.service),
            HomeworkPage(service: widget.service),
            GradesPage(service: widget.service),
            RulesPage(service: widget.service),
          ],
        ),
      ),
    ],
  );
  Widget _sidebar(String title, IconData icon, int index) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: selected == index
          ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
          : null,
      onPressed: () => setState(() => selected = index),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}
