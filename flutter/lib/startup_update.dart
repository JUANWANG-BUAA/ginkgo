import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'application/diagnostic_log.dart';
import 'maintenance_pages.dart';
import 'maintenance_service.dart';

/// One best-effort check per root lifetime. No timers, downloads or installation.
class StartupUpdateController extends ChangeNotifier {
  StartupUpdateController(
    this.service, {
    this.timeout = const Duration(seconds: 8),
  });

  final MaintenanceService service;
  final Duration timeout;
  bool _started = false, _closed = false, _dismissed = false;
  InstalledVersion? installed;
  UpdateResult? result;
  DateTime? checkedAt;

  bool get visible => !_dismissed && result != null;

  Future<void> checkOnce() async {
    if (_started || _closed) return;
    _started = true;
    var expired = false;
    try {
      if (!service.supportsUpdates) return;
      final snapshot =
          await (() async {
            final version = await service.version();
            if (_closed || expired) return null;
            final update = await service.checkUpdate(version.version);
            return (version, update);
          })().timeout(
            timeout,
            onTimeout: () {
              expired = true;
              return null;
            },
          );
      if (_closed || snapshot == null) return;
      final (version, update) = snapshot;
      if (!update.available ||
          !update.apkAvailable ||
          (update.latest?.trim().isEmpty ?? true)) {
        return;
      }
      installed = version;
      result = update;
      checkedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      // An optional GitHub check must not block startup or impersonate an error
      // in school services. Late results after timeout are intentionally ignored.
      debugPrint('Startup update check unavailable; continuing normally.');
    }
  }

  void dismiss() {
    if (_closed || _dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

/// Same quiet hint posture as diagnostics, but a separate informational state.
/// The diagnostic hint has priority; this one waits instead of covering it.
class StartupUpdateHint extends StatefulWidget {
  const StartupUpdateHint({
    super.key,
    required this.controller,
    required this.child,
  });
  final StartupUpdateController controller;
  final Widget child;

  @override
  State<StartupUpdateHint> createState() => _StartupUpdateHintState();
}

class _StartupUpdateHintState extends State<StartupUpdateHint>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _view() {
    final controller = widget.controller;
    controller.dismiss();
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SoftwareUpdatePage(
          service: controller.service,
          initialVersion: controller.installed,
          initialResult: controller.result,
          initialCheckedAt: controller.checkedAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, DiagnosticLog.shared]),
    builder: (context, _) {
      final controller = widget.controller;
      final show =
          _foreground &&
          controller.visible &&
          DiagnosticLog.shared.current == null &&
          (ModalRoute.of(context)?.isCurrent ?? true);
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (show)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 72,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Semantics(
                      key: const Key('startup-update-hint'),
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors
                              .secondarySystemGroupedBackground
                              .resolveFrom(context),
                          border: Border.all(
                            color: CupertinoColors.separator.resolveFrom(
                              context,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '发现新版本',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ginkgo ${controller.result!.latest}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              children: [
                                CupertinoButton(
                                  key: const Key('startup-update-view'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  minimumSize: const Size(48, 48),
                                  onPressed: _view,
                                  child: Text(
                                    '查看更新',
                                    style: TextStyle(
                                      color: CupertinoColors.label.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                CupertinoButton(
                                  key: const Key('startup-update-dismiss'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  minimumSize: const Size(48, 48),
                                  onPressed: controller.dismiss,
                                  child: Text(
                                    '稍后',
                                    style: TextStyle(
                                      color: CupertinoColors.label.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
