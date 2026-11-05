import 'dart:async';

import 'package:flutter/foundation.dart';

import 'maintenance.dart';

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
