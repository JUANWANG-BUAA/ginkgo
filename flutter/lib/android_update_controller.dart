import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AndroidDownload {
  const AndroidDownload({
    required this.version,
    required this.name,
    required this.url,
    required this.apiUrl,
    required this.size,
    required this.sha256,
  });
  factory AndroidDownload.fromJson(Map<String, dynamic> value) {
    final asset = AndroidDownload(
      version: value['version'] as String,
      name: value['name'] as String,
      url: value['url'] as String,
      apiUrl: value['apiUrl'] as String,
      size: value['size'] as int,
      sha256: value['sha256'] as String,
    );
    if (!asset.isValid) throw const FormatException('Invalid update asset');
    return asset;
  }
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

enum UpdateDownloadSource {
  automatic('自动选择官方入口'),
  github('GitHub 发布入口'),
  api('GitHub API 入口');

  const UpdateDownloadSource(this.label);
  final String label;
}

enum UpdateDownloadPhase { idle, downloading, paused, verifying, ready, failed }

typedef UpdateRoot = Future<Directory> Function();
typedef ApkInstaller = Future<String> Function(AndroidDownload asset);

Future<String> _digest(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

class AndroidUpdateController extends ChangeNotifier {
  AndroidUpdateController({
    UpdateRoot? root,
    HttpClient Function()? client,
    ApkInstaller? installer,
    this.allowTestHttp = false,
  }) : _root = root ?? getTemporaryDirectory,
       _newClient = client ?? HttpClient.new,
       _installer = installer ?? _install;
  static final shared = AndroidUpdateController();
  final UpdateRoot _root;
  final HttpClient Function() _newClient;
  final ApkInstaller _installer;
  @visibleForTesting
  final bool allowTestHttp;
  static const _channel = MethodChannel('cn.edu.buaa.ginkgo/update');
  static Future<String> _install(AndroidDownload asset) async =>
      await _channel.invokeMethod<String>('install', {
        'sha256': asset.sha256,
        'version': asset.version,
      }) ??
      'failed';

  AndroidDownload? asset;
  UpdateDownloadPhase phase = UpdateDownloadPhase.idle;
  UpdateDownloadSource source = UpdateDownloadSource.automatic;
  String? message;
  int received = 0;
  HttpClient? _activeClient;
  bool _pauseRequested = false;
  bool _running = false;
  bool installing = false;
  bool get busy => _running || installing;
  double get progress =>
      asset == null ? 0 : (received / asset!.size).clamp(0, 1);
  void selectSource(UpdateDownloadSource value) {
    if (busy) return;
    source = value;
    notifyListeners();
  }

  String get sizeLabel =>
      '${(received / 1048576).toStringAsFixed(1)} / '
      '${((asset?.size ?? 0) / 1048576).toStringAsFixed(1)} MB';

  Future<Directory> _directory() async {
    final root = await _root();
    return Directory('${root.path}/updates')..createSync(recursive: true);
  }

  void pause() {
    if (phase != UpdateDownloadPhase.downloading) return;
    _pauseRequested = true;
    _activeClient?.close(force: true);
  }

  Future<void> download(AndroidDownload next) async {
    if (busy) return;
    if (!next.isValid) {
      message = '更新信息不完整，请重新检查更新';
      phase = UpdateDownloadPhase.failed;
      notifyListeners();
      return;
    }
    _running = true;
    _pauseRequested = false;
    asset = next;
    received = 0;
    message = null;
    phase = UpdateDownloadPhase.downloading;
    notifyListeners();
    try {
      final directory = await _directory();
      final completed = File('${directory.path}/${next.sha256}.apk');
      final part = File('${directory.path}/${next.sha256}.part');
      if (await completed.exists()) {
        phase = UpdateDownloadPhase.verifying;
        notifyListeners();
        if (await _verified(completed, next)) {
          received = next.size;
          phase = UpdateDownloadPhase.ready;
          return;
        }
        await completed.delete();
      }
      if (await part.exists() && await part.length() > next.size) {
        await part.delete();
      }
      final urls = switch (source) {
        UpdateDownloadSource.automatic => [next.url, next.apiUrl],
        UpdateDownloadSource.github => [next.url],
        UpdateDownloadSource.api => [next.apiUrl],
      };
      var downloaded = false;
      for (final url in urls) {
        if (_pauseRequested) break;
        try {
          await _transfer(Uri.parse(url), part, next);
          downloaded = true;
          break;
        } catch (_) {
          if (_pauseRequested) break;
          message =
              source == UpdateDownloadSource.automatic && url == urls.first
              ? '正在尝试另一个 GitHub 官方入口…'
              : null;
          notifyListeners();
        }
      }
      if (_pauseRequested) {
        received = await part.exists() ? await part.length() : 0;
        phase = UpdateDownloadPhase.paused;
        message = '已暂停，继续下载会保留已有进度';
        return;
      }
      if (!downloaded) throw const FormatException('Download unavailable');
      phase = UpdateDownloadPhase.verifying;
      notifyListeners();
      if (!await _verified(part, next)) {
        await part.delete();
        received = 0;
        throw const FormatException('Integrity failure');
      }
      await part.rename(completed.path);
      phase = UpdateDownloadPhase.ready;
      message = '安装包已校验，点击安装后由 Android 确认';
    } catch (_) {
      phase = UpdateDownloadPhase.failed;
      message = '下载或校验未完成。可切换官方入口继续；请检查网络并重试。';
    } finally {
      _activeClient?.close(force: true);
      _activeClient = null;
      _running = false;
      notifyListeners();
    }
  }

  Future<bool> _verified(File file, AndroidDownload asset) async {
    if (await file.length() != asset.size) return false;
    final path = file.path;
    return await Isolate.run(() => _digest(path)) == asset.sha256;
  }

  bool _allowed(Uri uri) =>
      (uri.scheme == 'https' &&
          uri.userInfo.isEmpty &&
          !uri.hasPort &&
          const {
            'github.com',
            'api.github.com',
            'release-assets.githubusercontent.com',
          }.contains(uri.host)) ||
      (allowTestHttp && uri.scheme == 'http' && uri.host == '127.0.0.1');

  Future<void> _transfer(Uri uri, File part, AndroidDownload next) async {
    final client = _newClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _activeClient = client;
    try {
      await _transferWithClient(client, uri, part, next);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _transferWithClient(
    HttpClient client,
    Uri uri,
    File part,
    AndroidDownload next,
  ) async {
    var offset = await part.exists() ? await part.length() : 0;
    received = offset;
    if (offset == next.size) return;
    HttpClientResponse? response;
    for (var hop = 0; hop < 6; hop++) {
      if (!_allowed(uri)) throw const FormatException('Untrusted redirect');
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(
        HttpHeaders.acceptHeader,
        uri.host == 'api.github.com'
            ? 'application/octet-stream'
            : 'application/vnd.android.package-archive',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Ginkgo-Android-Updater',
      );
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      response = await request.close().timeout(const Duration(seconds: 15));
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw const FormatException('Missing redirect');
        uri = uri.resolve(location);
        await response.drain<void>().timeout(const Duration(seconds: 5));
        response = null;
        continue;
      }
      break;
    }
    if (response == null) throw const FormatException('Redirect limit');
    if (response.statusCode == 206) {
      final range = response.headers.value(HttpHeaders.contentRangeHeader);
      if (range != 'bytes $offset-${next.size - 1}/${next.size}') {
        throw const FormatException('Invalid range');
      }
    } else if (response.statusCode == 200) {
      // Some CDNs ignore Range; replace the partial file rather than appending.
      offset = 0;
    } else {
      throw const FormatException('Download rejected');
    }
    if (response.contentLength >= 0 &&
        response.contentLength != next.size - offset) {
      throw const FormatException('Size mismatch');
    }
    received = offset;
    final sink = part.openWrite(
      mode: offset == 0 ? FileMode.write : FileMode.append,
    );
    var lastNotice = DateTime.now();
    try {
      await for (final bytes in response.timeout(const Duration(seconds: 20))) {
        if (_pauseRequested) break;
        if (received + bytes.length > next.size) {
          throw const FormatException('Oversized download');
        }
        sink.add(bytes);
        await sink.flush();
        received += bytes.length;
        if (DateTime.now().difference(lastNotice).inMilliseconds >= 150) {
          lastNotice = DateTime.now();
          notifyListeners();
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (!_pauseRequested && received != next.size) {
      throw const FormatException('Truncated download');
    }
  }

  Future<void> install() async {
    final selected = asset;
    if (busy || selected == null || phase != UpdateDownloadPhase.ready) return;
    installing = true;
    notifyListeners();
    try {
      message = switch (await _installer(selected)) {
        'opened' => '已打开 Android 安装确认，请在系统界面完成',
        'permission' => '请允许 Ginkgo 安装应用，返回后再次点击安装',
        'invalid' => '安装包校验失败，包名、版本或签名不符合要求，请重新下载',
        _ => '未能打开安装界面，请重试或前往发布页下载',
      };
    } catch (_) {
      message = '未能打开安装界面，请重试';
    } finally {
      installing = false;
      notifyListeners();
    }
  }
}
