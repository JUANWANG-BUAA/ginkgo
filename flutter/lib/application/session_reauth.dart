import 'package:flutter/widgets.dart';

typedef SessionReauthCallback = Future<void> Function({String? reason});

/// Provides a non-destructive return to the login screen when an upstream
/// school session expires mid-use, keeping the user's remembered Keystore
/// password and auto-restore preference intact (unlike destructive sign-out).
class SessionReauthScope extends InheritedWidget {
  const SessionReauthScope({
    super.key,
    required this.onReauthenticate,
    required super.child,
  });

  final SessionReauthCallback? onReauthenticate;

  static SessionReauthCallback? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SessionReauthScope>()
      ?.onReauthenticate;

  @override
  bool updateShouldNotify(SessionReauthScope oldWidget) =>
      oldWidget.onReauthenticate != onReauthenticate;
}
