import 'package:ginkgo_mirror/application/mirror_service.dart';

/// The update and self-check capability the settings pages use.
///
/// The port lives here; the native implementation stays in the infrastructure
/// layer, so the pages depend on the contract and not on the adapter.
class InstalledVersion {
  const InstalledVersion(this.version, this.build);
  final String version, build;
  String get label => '$version ($build)';
}

class AndroidDownload {
  const AndroidDownload({
    required this.version,
    required this.name,
    required this.url,
    required this.apiUrl,
    required this.size,
    required this.sha256,
  });
  final String version, name, url, apiUrl, sha256;
  final int size;
  bool get isValid =>
      RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(version) &&
      name == 'Ginkgo-$version-android-arm64.apk' &&
      url ==
          'https://github.com/JUANWANG-BUAA/ginkgo/releases/download/'
              'android-v$version/$name' &&
      RegExp(
        r'^https://api\.github\.com/repos/JUANWANG-BUAA/ginkgo/releases/assets/[1-9][0-9]*$',
      ).hasMatch(apiUrl) &&
      size > 0 &&
      size <= 268435456 &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256);
}

class UpdateResult {
  const UpdateResult({
    required this.latest,
    required this.available,
    required this.apkAvailable,
    this.pageUrl,
    this.notes,
    this.download,
  });
  final String? latest, pageUrl, notes;
  final bool available, apkAvailable;
  final AndroidDownload? download;
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

  /// Network check is deliberately separate from the local checks. A cached
  /// fallback cannot prove connectivity, and synthetic demo data cannot prove a
  /// live API.
  Future<bool> checkPublicService(MirrorService service);
  Future<InstalledVersion> version();
  Future<UpdateResult> checkUpdate(String current);
  Future<bool> openReleases(String? page);
  Future<bool> checkBridge();
  Future<bool> checkStorage();
  Future<bool> checkVault();
}
