import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show RouteChoice, SessionResponse, SessionState;
import 'package:ginkgo_mirror/infrastructure/display_preferences_file_store.dart';
import 'package:ginkgo_mirror/infrastructure/mirror_runtime.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_auth_challenge.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/startup_page.dart';
import 'package:ginkgo_mirror/platform/startup_update.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/infrastructure/native_school_rules.dart';
import 'package:ginkgo_mirror/infrastructure/homework_file_io.dart';
import 'package:ginkgo_mirror/infrastructure/learning_file_actions.dart';
import 'package:ginkgo_mirror/infrastructure/maintenance_service.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

// 测试与页面直接使用 ginkgoApp/GinkgoApp，保持既有入口不变。
export 'package:ginkgo_mirror/workspace/workspace_shell.dart'
    show GinkgoApp, ginkgoApp, ginkgoTheme;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The school rules live in the domain; the app uses them through the bridge.
  schoolRules = const NativeSchoolRules();
  final preferenceStore = DisplayPreferencesFileStore();
  final preferences = AppPreferences(
    writer: preferenceStore.write,
    reader: preferenceStore.read,
  );
  await preferences.restore();
  try {
    await initializeMirrorRuntime();
    runApp(
      GinkgoRoot(
        preferences: preferences,
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
/// The platform actions the pages may use, bound once for the whole app.
final _platformActions = PlatformActions(
  learningFileSaver: saveLearningFile,
  homeworkFilePicker: pickHomeworkFile,
  homeworkFileSave: saveAndOpenSchoolFile,
  maintenance: const NativeMaintenanceService(),
);

class GinkgoRoot extends StatefulWidget {
  const GinkgoRoot({
    super.key,
    this.liveService = const NativeMirrorService(),
    this.demoService = const DemoMirrorService(),
    this.preferences,
    this.loadUpdateGate,
    this.startupUpdates,
    this.challengeGateway,
  });
  final MirrorService liveService;
  final MirrorService demoService;
  final AppPreferences? preferences;
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
  AppPreferences get _preferences =>
      widget.preferences ?? AppPreferences.shared;

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

  Future<void> retryPreferences() async {
    if (!mounted || stage == _Stage.restoring) return;
    setState(() => stage = _Stage.restoring);
    await _preferences.restore();
    if (mounted) await restore();
  }

  Future<void> restore() async {
    if (_preferences.readFailed) {
      setState(() {
        stage = _Stage.signedOut;
        session = null;
        captchaRequired = false;
        message = '未能读取本机设置，已停止自动恢复。请重新读取设置，或选择路线后手动登录。';
      });
      return;
    }
    // The route chosen on the login page must apply before the session is
    // restored or the first sign-in runs, otherwise a later start silently
    // logs in on a different path than the one the user picked.
    final route = switch (_preferences.routeMode) {
      'direct' => RouteChoice.direct,
      'webVpn' => RouteChoice.webVpn,
      _ => RouteChoice.automatic,
    };
    try {
      final result = await widget.liveService.setRoute(route);
      if (result.failure != null) {
        if (!mounted) return;
        setState(() {
          stage = _Stage.signedOut;
          message = failureMessage(result.failure);
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        stage = _Stage.signedOut;
        message = '网络路线初始化失败，请重新选择路线后登录';
      });
      return;
    }
    if (!mounted) return;

    // An explicit sign-out persists until the next successful sign-in: the
    // user chose to leave, so a later start shows the login page instead of
    // auto-restoring a saved session.
    if (_preferences.explicitSignOut) {
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
    final saved = _preferences.setExplicitSignOut(true);
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
    _preferences.setExplicitSignOut(false);
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
        preferences: _preferences,
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
      return ginkgoApp(preferences: _preferences, home: const StartupPage());
    }
    return switch (stage) {
      _Stage.restoring => ginkgoApp(
        preferences: _preferences,
        home: const StartupPage(),
      ),
      _Stage.demo => GinkgoApp(
        preferences: _preferences,
        service: widget.demoService,
        platformActions: _platformActions,
        startupUpdate: startupUpdate,
        onSignOut: () async => setState(() => stage = _Stage.signedOut),
      ),
      _Stage.signedOut => ginkgoApp(
        preferences: _preferences,
        startupUpdate: startupUpdate,
        home: LoginPage(
          service: widget.liveService,
          initialMessage: message,
          initialCaptcha: captchaRequired,
          onRetryPreferences: _preferences.readFailed ? retryPreferences : null,
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
        preferences: _preferences,
        platformActions: _platformActions,
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
