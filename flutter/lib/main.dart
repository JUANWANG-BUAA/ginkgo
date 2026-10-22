import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'app_preferences.dart';
import 'application/contracts.dart' show SessionResponse, SessionState;
import 'infrastructure/mirror_runtime.dart';
import 'login_page.dart';
import 'mirror_service.dart';
import 'startup_page.dart';
import 'workspace_shell.dart';

// 测试与页面直接使用 ginkgoApp/GinkgoApp，保持既有入口不变。
export 'workspace_shell.dart' show GinkgoApp, ginkgoApp, ginkgoTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.shared.restore();
  try {
    await initializeMirrorRuntime();
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
