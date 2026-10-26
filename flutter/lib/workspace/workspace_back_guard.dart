import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Attached to each tab's first route, so detail routes and dialogs retain
/// their own back behavior. The exit window never survives leaving the tab.
class WorkspaceBackController extends ChangeNotifier
    with WidgetsBindingObserver {
  WorkspaceBackController() {
    WidgetsBinding.instance.addObserver(this);
  }

  Timer? _exitWindow;
  bool get exitArmed => _exitWindow?.isActive ?? false;

  void disarm() {
    final wasArmed = _exitWindow != null;
    _exitWindow?.cancel();
    _exitWindow = null;
    if (wasArmed) notifyListeners();
  }

  void back({required bool atWorkspace, required VoidCallback goToWorkspace}) {
    if (!atWorkspace) {
      disarm();
      goToWorkspace();
    } else if (exitArmed) {
      disarm();
      SystemNavigator.pop();
    } else {
      _exitWindow = Timer(const Duration(seconds: 2), () {
        disarm();
      });
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) disarm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitWindow?.cancel();
    super.dispose();
  }
}

class WorkspaceBackHint extends StatelessWidget {
  const WorkspaceBackHint({super.key, required this.controller});
  final WorkspaceBackController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      return controller.exitArmed
          ? Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 72,
              left: 32,
              right: 32,
              child: IgnorePointer(
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: CupertinoColors.separator.resolveFrom(context),
                          width: 0.5,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Text('再返回一次退出 Ginkgo'),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink();
    },
  );
}

Widget guardWorkspaceBack({
  required Widget child,
  required VoidCallback onBack,
}) => defaultTargetPlatform == TargetPlatform.android
    ? PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onBack();
        },
        child: child,
      )
    : child;
