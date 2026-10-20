import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mirror_service.dart';
import 'src/rust/api/live.dart' as live;
import 'src/rust/api/mirror.dart' as bridge;

class InstalledVersion {
  const InstalledVersion(this.version, this.build);
  final String version, build;
  String get label => '$version ($build)';
}

class UpdateResult {
  const UpdateResult({
    required this.latest,
    required this.available,
    required this.apkAvailable,
    this.pageUrl,
    this.notes,
  });
  factory UpdateResult.fromJson(Map<String, dynamic> json) => UpdateResult(
    latest: json['latest'] as String?,
    available: json['available'] as bool,
    apkAvailable: json['apkAvailable'] as bool,
    pageUrl: json['pageUrl'] as String?,
    notes: json['notes'] as String?,
  );
  final String? latest, pageUrl, notes;
  final bool available, apkAvailable;
  String get headline => latest == null
      ? '尚无 Android 发布'
      : !apkAvailable
      ? '发布尚未提供 Android 安装包'
      : available
      ? '发现 Android 新版本'
      : '当前已是最新 Android 版本';
}

abstract interface class MaintenanceService {
  bool get supportsUpdates;
  Future<InstalledVersion> version();
  Future<UpdateResult> checkUpdate(String current);
  Future<bool> openReleases(String? page);
  Future<bool> checkBridge();
  Future<bool> checkStorage();
  Future<bool> checkVault();
}

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
    final result = await live.checkAndroidUpdate(current: current);
    if (result.failure != null || result.payload == null) {
      throw const FormatException('Update unavailable');
    }
    return UpdateResult.fromJson(
      jsonDecode(result.payload!) as Map<String, dynamic>,
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
  Future<bool> checkVault() => live.verifyCredentialStorage(
    account:
        '__ginkgo_vault_test__settings_${DateTime.now().microsecondsSinceEpoch}',
    secret: 'synthetic-diagnostic-not-a-password',
  );
}

/// Network check is deliberately separate from local checks. Cached fallback
/// cannot prove connectivity, and synthetic demo data cannot prove a live API.
Future<bool> checkPublicService(MirrorService service) async {
  if (service.isDemo) return false;
  final result = await service.libraryStats(forceRefresh: true);
  if (result.failure != null || result.stale || result.payload == null) {
    return false;
  }
  final json = jsonDecode(result.payload!) as Map<String, dynamic>;
  return json['fromCache'] == false && json['campuses'] is List;
}
