import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../mirror_service.dart';


import '../application/maintenance.dart';

import '../src/rust/api/live.dart' as live;
import '../src/rust/api/mirror.dart' as bridge;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

class NativeMaintenanceService implements MaintenanceService {
  const NativeMaintenanceService();
  static const repository = 'https://github.com/JUANWANG-BUAA/ginkgo';
  @override
  bool get supportsUpdates => Platform.isAndroid;
  @override
  Future<InstalledVersion> version() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledVersion(info.version, info.buildNumber);
  }

  @override
  Future<UpdateResult> checkUpdate(String current) async {
    final result = await boundedNativeRead(
      () => live.checkAndroidUpdate(current: current),
    );
    final summary = result.data;
    if (summary == null) throw const FormatException('Update unavailable');
    final asset = summary.download;
    return UpdateResult(
      latest: summary.latest,
      available: summary.available,
      apkAvailable: summary.apkAvailable,
      pageUrl: summary.pageUrl,
      notes: summary.notes,
      download: asset == null
          ? null
          : AndroidDownload(
              version: asset.version,
              name: asset.name,
              url: asset.url,
              apiUrl: asset.apiUrl,
              size: asset.size,
              sha256: asset.sha256,
            ),
    );
  }

  @override
  Future<bool> openReleases(String? page) async {
    final uri = Uri.parse(page ?? '$repository/releases');
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !(uri.path == '/JUANWANG-BUAA/ginkgo/releases' ||
            uri.path.startsWith(
              '/JUANWANG-BUAA/ginkgo/releases/tag/android-v',
            ))) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> checkBridge() async {
    final result = await bridge.loadDemoSchedule();
    return result.failure == null && result.courses.isNotEmpty;
  }

  @override
  Future<bool> checkStorage() async {
    Directory? probe;
    var passed = false;
    try {
      final root = await getApplicationSupportDirectory();
      await root.create(recursive: true);
      probe = await root.createTemp('diagnostic-');
      final file = File('${probe.path}/probe');
      await file.writeAsString('ginkgo-synthetic-check', flush: true);
      passed = await file.readAsString() == 'ginkgo-synthetic-check';
    } finally {
      if (probe != null) {
        await probe.delete(recursive: true);
        passed = passed && !await probe.exists();
      }
    }
    return passed;
  }

  @override
  Future<bool> checkPublicService(MirrorService service) async {
    if (service.isDemo) return false;
    final result = await service.libraryStats(forceRefresh: true);
    final data = result.data;
    if (result.failure != null || data == null) return false;
    return !data.fromCache;
  }

  @override
  Future<bool> checkVault() => boundedNativeRead(
    () => live.verifyCredentialStorage(
      account:
          '__ginkgo_vault_test__settings_${DateTime.now().microsecondsSinceEpoch}',
      secret: 'synthetic-diagnostic-not-a-password',
    ),
  );
}
