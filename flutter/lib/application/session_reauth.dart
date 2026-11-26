import 'package:flutter/widgets.dart';

typedef SessionReauthCallback = Future<void> Function({String? reason});

/// Non-blocking status of background session restoration when the workspace
/// opened immediately from an account-scoped offline cache.
enum WorkspaceOfflineState { online, syncing, offline }

/// Provides a non-destructive return to the login screen when an upstream
/// school session expires mid-use, keeping the user's remembered Keystore
/// password and auto-restore preference intact (unlike destructive sign-out).
class SessionReauthScope extends InheritedWidget {
  const SessionReauthScope({
    super.key,
    required this.onReauthenticate,
    this.offlineState = WorkspaceOfflineState.online,
    this.offlineMessage,
    this.onRetryRestore,
    required super.child,
  });

  final SessionReauthCallback? onReauthenticate;
  final WorkspaceOfflineState offlineState;
  final String? offlineMessage;
  final Future<void> Function()? onRetryRestore;

  static SessionReauthCallback? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SessionReauthScope>()
      ?.onReauthenticate;

  static SessionReauthScope? scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionReauthScope>();

  @override
  bool updateShouldNotify(SessionReauthScope oldWidget) =>
      oldWidget.onReauthenticate != onReauthenticate ||
      oldWidget.offlineState != offlineState ||
      oldWidget.offlineMessage != offlineMessage ||
      oldWidget.onRetryRestore != onRetryRestore;
}
