import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/application/contracts.dart'
    show RouteChoice, SessionResponse, SessionState, FailureCode;
import 'package:ginkgo_mirror/application/session_reauth.dart';
import 'package:ginkgo_mirror/infrastructure/display_preferences_file_store.dart';
import 'package:ginkgo_mirror/infrastructure/mirror_runtime.dart';
import 'package:ginkgo_mirror/infrastructure/offline_cache_store.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/features/auth/session_recovery_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_auth_challenge.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/startup_page.dart';
import 'package:ginkgo_mirror/application/startup_update_controller.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/infrastructure/native_school_rules.dart';
import 'package:ginkgo_mirror/infrastructure/checkin_qr_saver.dart';
import 'package:ginkgo_mirror/infrastructure/homework_file_io.dart';
import 'package:ginkgo_mirror/infrastructure/learning_file_actions.dart';
import 'package:ginkgo_mirror/infrastructure/maintenance_service.dart';
import 'package:ginkgo_mirror/platform/system_settings_service.dart';
import 'package:ginkgo_mirror/platform/update_gate.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

// Keep the explicitly named Android service library in the application bundle.
export 'package:ginkgo_mirror/infrastructure/background_reminders.dart'
    show runBackgroundReminders;

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
  final initialHint = preferences.explicitSignOut || preferences.readFailed
      ? null
      : await OfflineCacheStore.shared.readSessionHint();
  try {
    await initializeMirrorRuntime();
    runApp(
      GinkgoRoot(
        preferences: preferences,
        initialSessionHint: initialHint,
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
const _systemSettings = NativeSystemSettingsService();

final _platformActions = PlatformActions(
  learningFileSaver: saveLearningFile,
  homeworkFilePicker: pickHomeworkFile,
  homeworkFileSave: saveAndOpenSchoolFile,
  checkinQrSaver: saveCheckinQrPng,
  checkinQrHelper: AndroidCheckinQrQuickHelper.shared,
  maintenance: const NativeMaintenanceService(),
  networkStatus: _systemSettings.networkStatus,
  openWifiSettings: _systemSettings.openWifiSettings,
);

class GinkgoRoot extends StatefulWidget {
  const GinkgoRoot({
    super.key,
    this.liveService = const NativeMirrorService(),
    this.demoService = const DemoMirrorService(),
    this.preferences,
    this.initialSessionHint,
    this.loadUpdateGate,
    this.startupUpdates,
    this.challengeGateway,
  });
  final MirrorService liveService;
  final MirrorService demoService;
  final AppPreferences? preferences;
  final OfflineSessionHint? initialSessionHint;
  final AuthChallengeGateway? challengeGateway;

  /// Null preserves explicitly offline/test compositions. Production checks once.
  final MaintenanceService? startupUpdates;

  /// 启动时读取最低版本清单；测试与离线场景传 null 即跳过门禁。
  final Future<UpdateGate?> Function()? loadUpdateGate;
  @override
  State<GinkgoRoot> createState() => _GinkgoRootState();
}

enum _Stage { restoring, restoreFailed, signedOut, signedIn, demo }

class _GinkgoRootState extends State<GinkgoRoot> {
  AppPreferences get _preferences =>
      widget.preferences ?? AppPreferences.shared;

  _Stage stage = _Stage.restoring;
  SessionResponse? session;
  String? message;
  bool captchaRequired = false;
  bool _restorePending = false;
  Future<void>? _pendingRevocation;
  UpdateGate? blockingGate;
  String? installedVersion;
  StartupUpdateController? startupUpdate;
  WorkspaceOfflineState _offlineState = WorkspaceOfflineState.online;
  String? _offlineMessage;
  bool _offlineReauthNeeded = false;

  @override
  void initState() {
    super.initState();
    final hint = widget.initialSessionHint;
    if (hint != null &&
        !_preferences.explicitSignOut &&
        !_preferences.readFailed) {
      session = hint.toPlaceholderSession();
      stage = _Stage.signedIn;
      _offlineState = WorkspaceOfflineState.syncing;
    }
    // Let the first frame paint before touching JNI/Keystore/network work.
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

  /// 最低版本门禁失败或不可达时放行；仅命中最低 build 时立即拦截，不阻塞冷启动首屏。
  Future<void> checkUpdateGate() async {
    final loader = widget.loadUpdateGate;
    if (loader == null) return;
    final gateFuture = loader().catchError((Object _) => null);
    final infoFuture = PackageInfo.fromPlatform().then<PackageInfo?>(
      (info) => info,
      onError: (Object _) => null,
    );
    final gate = await gateFuture;
    if (!mounted) return;
    final info = await infoFuture;
    final label = info == null ? null : '${info.version} (${info.buildNumber})';
    final build = info == null ? null : int.tryParse(info.buildNumber);
    if (!mounted) return;
    setState(() {
      installedVersion = label;
      blockingGate = gate != null && build != null && gate.blocks(build)
          ? gate
          : null;
    });
  }

  Future<void> retryPreferences() async {
    if (!mounted || stage == _Stage.restoring) return;
    setState(() => stage = _Stage.restoring);
    await _preferences.restore();
    if (mounted) await restore();
  }

  Future<void> restore() async {
    if (!mounted || _restorePending) return;
    _restorePending = true;
    final inCachedWorkspace =
        stage == _Stage.signedIn &&
        _offlineState != WorkspaceOfflineState.online;
    setState(() {
      if (inCachedWorkspace) {
        _offlineState = WorkspaceOfflineState.syncing;
        _offlineMessage = null;
        _offlineReauthNeeded = false;
      } else {
        stage = _Stage.restoring;
      }
    });
    try {
      await _restoreSession(inCachedWorkspace: inCachedWorkspace);
    } finally {
      _restorePending = false;
    }
  }

  Future<void> _awaitPendingRevocation() async {
    final pending = _pendingRevocation;
    if (pending != null) {
      await pending;
      if (identical(_pendingRevocation, pending)) {
        _pendingRevocation = null;
      }
    }
  }

  Future<void> _restoreSession({bool inCachedWorkspace = false}) async {
    if (_pendingRevocation != null) {
      await _awaitPendingRevocation();
      if (!mounted) return;
    }
    if (_preferences.readFailed) {
      setState(() {
        stage = _Stage.signedOut;
        session = null;
        captchaRequired = false;
        _offlineState = WorkspaceOfflineState.online;
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
        _handleRestoreFailure(
          inCachedWorkspace: inCachedWorkspace,
          reason: failureMessage(result.failure),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      _handleRestoreFailure(
        inCachedWorkspace: inCachedWorkspace,
        reason: '网络路线初始化失败，请重试恢复，或手动选择路线登录',
      );
      return;
    }
    if (!mounted) return;

    // An explicit sign-out persists until the next successful sign-in: the
    // user chose to leave, so a later start shows the login page instead of
    // auto-restoring a saved session.
    if (_preferences.explicitSignOut) {
      setState(() {
        stage = _Stage.signedOut;
        session = null;
        message = null;
        captchaRequired = false;
        _offlineState = WorkspaceOfflineState.online;
      });
      return;
    }
    if (!inCachedWorkspace) {
      setState(() {
        stage = _Stage.restoring;
        message = null;
      });
    }
    try {
      final response = await widget.liveService.restoreSession();
      if (!mounted) return;
      if (response.state == SessionState.signedIn) {
        _persistHint(response);
        setState(() {
          session = response;
          stage = _Stage.signedIn;
          _offlineState = WorkspaceOfflineState.online;
          _offlineMessage = null;
          _offlineReauthNeeded = false;
        });
        return;
      }
      if (response.failure != null &&
          response.failure != FailureCode.sessionExpired &&
          response.failure != FailureCode.invalidCredentials &&
          response.state != SessionState.captchaRequired) {
        _handleRestoreFailure(
          inCachedWorkspace: inCachedWorkspace,
          reason: failureMessage(response.failure),
        );
        return;
      }
      if (inCachedWorkspace) {
        setState(() {
          _offlineState = WorkspaceOfflineState.offline;
          _offlineReauthNeeded = true;
          _offlineMessage = response.state == SessionState.captchaRequired
              ? '需要验证码登录，当前显示离线缓存'
              : '登录已过期，当前显示离线缓存';
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
      _handleRestoreFailure(
        inCachedWorkspace: inCachedWorkspace,
        reason: failureMessage(null),
      );
    }
  }

  void _handleRestoreFailure({
    required bool inCachedWorkspace,
    required String reason,
  }) {
    if (inCachedWorkspace) {
      setState(() {
        _offlineState = WorkspaceOfflineState.offline;
        _offlineReauthNeeded = false;
        _offlineMessage = reason;
      });
    } else {
      setState(() {
        session = null;
        stage = _Stage.restoreFailed;
        message = reason;
      });
    }
  }

  void _persistHint(SessionResponse response) {
    if (widget.liveService is! NativeMirrorService) return;
    final account = response.account;
    if (account == null || account.isEmpty) return;
    unawaited(
      OfflineCacheStore.shared.saveSessionHint(
        OfflineSessionHint(
          account: account,
          name: response.name,
          route: response.route,
        ),
      ),
    );
  }

  Future<void> signOut() async {
    // Recorded and applied to UI immediately so a slow in-flight school read
    // can never trap the user inside the workspace. Backend revocation still
    // runs to completion and serializes ahead of any subsequent login/restore.
    final saved = _preferences.setExplicitSignOut(true);
    ServiceHealthTracker.shared.clear();
    if (widget.liveService is NativeMirrorService) {
      unawaited(OfflineCacheStore.shared.clearSessionHint());
    }
    final revoking = widget.liveService.signOut().then<void>(
      (_) {},
      onError: (Object _) {},
    );
    _pendingRevocation = revoking;
    if (mounted) {
      setState(() {
        session = null;
        stage = _Stage.signedOut;
        captchaRequired = false;
        message = null;
        _offlineState = WorkspaceOfflineState.online;
        _offlineMessage = null;
        _offlineReauthNeeded = false;
      });
    }
    await saved;
  }

  /// Returns to [LoginPage] without wiping saved credentials or setting
  /// [AppPreferences.explicitSignOut], so an expired 24h session can be
  /// renewed in one tap with pre-filled Keystore credentials.
  Future<void> reauthenticate({String? reason}) async {
    ServiceHealthTracker.shared.clear();
    if (!mounted) return;
    setState(() {
      session = null;
      stage = _Stage.signedOut;
      captchaRequired = false;
      _offlineState = WorkspaceOfflineState.online;
      _offlineMessage = null;
      _offlineReauthNeeded = false;
      message = reason ?? '学校会话已过期，已自动填入记住的账号密码，请重新登录。';
    });
  }

  void signedIn(SessionResponse response) {
    ServiceHealthTracker.shared.clear();
    _preferences.setExplicitSignOut(false);
    _persistHint(response);
    setState(() {
      session = response;
      stage = _Stage.signedIn;
      captchaRequired = false;
      message = null;
      _offlineState = WorkspaceOfflineState.online;
      _offlineMessage = null;
      _offlineReauthNeeded = false;
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
    return switch (stage) {
      _Stage.restoring => ginkgoApp(
        preferences: _preferences,
        home: const StartupPage(),
      ),
      _Stage.restoreFailed => ginkgoApp(
        preferences: _preferences,
        home: SessionRecoveryPage(
          message: message,
          onRetry: restore,
          onLogin: () => setState(() {
            stage = _Stage.signedOut;
            captchaRequired = false;
            message = null;
          }),
        ),
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
          beforeSessionAction: _awaitPendingRevocation,
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
            ? NativeMirrorService(
                expectedAccount: session?.account,
                offlineFastPath: _offlineState != WorkspaceOfflineState.online,
              )
            : widget.liveService,
        startupUpdate: startupUpdate,
        accountName: session?.name ?? session?.account,
        accountId: session?.account,
        route: session?.route,
        offlineState: _offlineState,
        offlineMessage: _offlineMessage,
        onRetryRestore: _offlineReauthNeeded
            ? () => reauthenticate(reason: _offlineMessage)
            : restore,
        onSignOut: signOut,
        onReauthenticate: reauthenticate,
      ),
    };
  }
}
