import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show SessionResponse, SessionState;
import 'package:ginkgo_mirror/infrastructure/mirror_runtime.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_auth_challenge.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/startup_page.dart';
import 'package:ginkgo_mirror/platform/startup_update.dart';
import 'package:ginkgo_mirror/infrastructure/maintenance_service.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

// 测试与页面直接使用 ginkgoApp/GinkgoApp，保持既有入口不变。
export 'package:ginkgo_mirror/workspace/workspace_shell.dart'
    show GinkgoApp, ginkgoApp, ginkgoTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.shared.restore();
  try {
    await initializeMirrorRuntime();
    runApp(
      GinkgoRoot(
        loadUpdateGate: UpdateGate.fetch,
        startupUpdates: const NativeMaintenanceService(),
      ),
    );
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
    this.loadUpdateGate,
    this.startupUpdates,
    this.challengeGateway,
  });
  final MirrorService liveService;
  final MirrorService demoService;
  final AuthChallengeGateway? challengeGateway;

  /// Null preserves explicitly offline/test compositions. Production checks once.
  final MaintenanceService? startupUpdates;

  /// 启动时读取最低版本清单；测试与离线场景传 null 即跳过门禁。
  final Future<UpdateGate?> Function()? loadUpdateGate;
  @override
  State<GinkgoRoot> createState() => _GinkgoRootState();
}

enum _Stage { restoring, signedOut, signedIn, demo }

class _GinkgoRootState extends State<GinkgoRoot> {
  _Stage stage = _Stage.restoring;
  SessionResponse? session;
  String? message;
  bool captchaRequired = false;
  UpdateGate? blockingGate;
  bool gateResolved = false;
  String? installedVersion;
  StartupUpdateController? startupUpdate;

  @override
  void initState() {
    super.initState();
    // Let the startup page paint before touching JNI/Keystore/network work.
    final updates = widget.startupUpdates;
    if (updates != null) startupUpdate = StartupUpdateController(updates);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      restore();
      startupUpdate?.checkOnce();
    });
    checkUpdateGate();
  }

  @override
  void dispose() {
    startupUpdate?.dispose();
    super.dispose();
  }

  /// 最低版本门禁失败或不可达时放行；只有明确要求且低于最低 build 才阻塞。
  Future<void> checkUpdateGate() async {
    final loader = widget.loadUpdateGate;
    if (loader == null) return;
    UpdateGate? gate;
    try {
      gate = await loader();
    } catch (_) {
      gate = null;
    }
    if (!mounted) return;
    String? label;
    int? build;
    try {
      final info = await PackageInfo.fromPlatform();
      label = '${info.version} (${info.buildNumber})';
      build = int.tryParse(info.buildNumber);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      installedVersion = label;
      blockingGate = gate != null && build != null && gate.blocks(build)
          ? gate
          : null;
      gateResolved = true;
    });
  }

  Future<void> restore() async {
    // An explicit sign-out persists until the next successful sign-in: the
    // user chose to leave, so a later start shows the login page instead of
    // auto-restoring a saved session.
    if (AppPreferences.shared.explicitSignOut) {
      setState(() {
        stage = _Stage.signedOut;
        message = null;
        captchaRequired = false;
      });
      return;
    }
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
            ? '学校要求验证码，请重新登录并完成页面中的验证码挑战。'
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
    // Recorded before the state change: even if a vault deletion once failed,
    // the next start must show the login page, never auto-restore.
    final saved = AppPreferences.shared.setExplicitSignOut(true);
    if (mounted) {
      setState(() {
        session = null;
        stage = _Stage.signedOut;
        message = null;
      });
    }
    await saved;
  }

  void signedIn(SessionResponse response) {
    AppPreferences.shared.setExplicitSignOut(false);
    setState(() {
      session = response;
      stage = _Stage.signedIn;
      captchaRequired = false;
      message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gate = blockingGate;
    if (gate != null) {
      return ginkgoApp(
        home: UpdateRequiredPage(
          gate: gate,
          installedVersion: installedVersion,
          onRetry: checkUpdateGate,
        ),
      );
    }
    // Until the manifest check settles (bounded by its own timeout), only the
    // startup surface is available: a stale build must not reach the workspace
    // — or school writes — before the gate has decided.
    if (widget.loadUpdateGate != null && !gateResolved) {
      return ginkgoApp(home: const StartupPage());
    }
    return switch (stage) {
      _Stage.restoring => ginkgoApp(home: const StartupPage()),
      _Stage.demo => GinkgoApp(
        service: widget.demoService,
        startupUpdate: startupUpdate,
        onSignOut: () async => setState(() => stage = _Stage.signedOut),
      ),
      _Stage.signedOut => ginkgoApp(
        startupUpdate: startupUpdate,
        home: LoginPage(
          service: widget.liveService,
          initialMessage: message,
          initialCaptcha: captchaRequired,
          challengeGateway:
              widget.challengeGateway ??
              (widget.liveService is NativeMirrorService
                  ? const NativeAuthChallengeGateway()
                  : null),
          onSignedIn: signedIn,
          onDemo: () => setState(() {
            stage = _Stage.demo;
            captchaRequired = false;
            message = null;
          }),
        ),
      ),
      _Stage.signedIn => GinkgoApp(
        service: widget.liveService is NativeMirrorService
            ? NativeMirrorService(expectedAccount: session?.account)
            : widget.liveService,
        startupUpdate: startupUpdate,
        accountName: session?.name ?? session?.account,
        accountId: session?.account,
        route: session?.route,
        onSignOut: signOut,
      ),
    };
  }
}
