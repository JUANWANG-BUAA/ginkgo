import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';
import 'package:ginkgo_mirror/platform/android_update_controller.dart';

/// Redirect the trusted initial URL to an isolated local server. The production
/// allowlist and redirect checks still run before each request.
class LocalUpdateClient implements HttpClient {
  LocalUpdateClient(this.endpoint);
  final Uri endpoint;
  final inner = HttpClient();
  @override
  Future<HttpClientRequest> getUrl(Uri url) => inner.getUrl(endpoint);
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  void close({bool force = false}) => inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late HttpServer server;
  late Uri endpoint;
  final bytes = List<int>.generate(4096, (i) => i % 251);
  late AndroidDownload asset;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ginkgo-update-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint = Uri.parse('http://127.0.0.1:${server.port}/asset');
    asset = AndroidDownload(
      version: '0.1.0-alpha.4',
      name: 'Ginkgo-0.1.0-alpha.4-android-arm64.apk',
      url:
          'https://github.com/JUANWANG-BUAA/ginkgo/releases/download/'
          'android-v0.1.0-alpha.4/Ginkgo-0.1.0-alpha.4-android-arm64.apk',
      apiUrl: 'https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases/assets/123',
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
  });
  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  AndroidUpdateController controller({ApkInstaller? installer}) =>
      AndroidUpdateController(
        root: () async => root,
        client: () => LocalUpdateClient(endpoint),
        installer: installer,
      );

  test(
    'resumes a persisted partial file and verifies the complete digest',
    () async {
      final directory = await Directory('${root.path}/updates').create();
      await File('${directory.path}/${asset.sha256}.part')
          .writeAsBytes(bytes.take(1024).toList());
      var requests = 0;
      server.listen((request) async {
        requests++;
        expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=1024-');
        expect(request.headers.value(HttpHeaders.cookieHeader), isNull);
        expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
        request.response.statusCode = 206;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 1024-4095/4096',
        );
        request.response.contentLength = bytes.length - 1024;
        request.response.add(bytes.sublist(1024));
        await request.response.close();
      });
      final download = controller();
      await download.download(asset);
      expect(download.phase, UpdateDownloadPhase.ready);
      expect(download.received, 4096);
      expect(requests, 1);
      expect(
        await File('${directory.path}/${asset.sha256}.apk').readAsBytes(),
        bytes,
      );
      download.dispose();
    },
  );

  test(
    'a server ignoring Range replaces partial bytes instead of appending',
    () async {
      final directory = await Directory('${root.path}/updates').create();
      await File('${directory.path}/${asset.sha256}.part')
          .writeAsBytes([1, 2, 3]);
      server.listen((request) async {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      final download = controller();
      await download.download(asset);
      expect(download.phase, UpdateDownloadPhase.ready);
      expect(
        await File('${directory.path}/${asset.sha256}.apk').length(),
        bytes.length,
      );
      download.dispose();
    },
  );

  test(
    'corruption never becomes installable and removes invalid partial bytes',
    () async {
      server.listen((request) async {
        request.response.contentLength = bytes.length;
        request.response.add(List<int>.filled(bytes.length, 0));
        await request.response.close();
      });
      var installs = 0;
      final download = controller(
        installer: (_) async {
          installs++;
          return 'opened';
        },
      );
      await download.download(asset);
      await download.install();
      expect(download.phase, UpdateDownloadPhase.failed);
      expect(installs, 0);
      expect(
        await File('${root.path}/updates/${asset.sha256}.part').exists(),
        isFalse,
      );
      download.dispose();
    },
  );

  test('untrusted redirects cannot reach an installer', () async {
    var count = 0;
    server.listen((request) async {
      count++;
      request.response.statusCode = 302;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        'https://evil.example/download.apk',
      );
      await request.response.close();
    });
    final download = controller();
    await download.download(asset);
    expect(download.phase, UpdateDownloadPhase.failed);
    expect(count, 2); // Only the two original official entries were attempted.
    download.dispose();
  });

  test(
    'a mismatched Content-Range never appends or becomes installable',
    () async {
      final directory = await Directory('${root.path}/updates').create();
      final part = File('${directory.path}/${asset.sha256}.part');
      await part.writeAsBytes(bytes.take(1024).toList());
      server.listen((request) async {
        request.response.statusCode = 206;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 0-4095/4096',
        );
        request.response.add(bytes);
        await request.response.close();
      });
      final download = controller();
      await download.download(asset);
      expect(download.phase, UpdateDownloadPhase.failed);
      expect(await part.length(), 1024);
      download.dispose();
    },
  );

  test(
    'pause keeps received bytes and a later resume requests only the remainder',
    () async {
      final download = controller();
      final paused = Completer<void>();
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (requests == 1) {
          request.response.bufferOutput = false;
          request.response.contentLength = bytes.length;
          request.response.add(bytes.take(1024).toList());
          await request.response.flush();
          // Wait for the client to persist the first chunk before pausing.
          final part = File('${root.path}/updates/${asset.sha256}.part');
          for (var i = 0; i < 100; i++) {
            if (download.received == 1024 &&
                await part.exists() &&
                await part.length() == 1024) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          download.pause();
          paused.complete();
          try {
            await request.response.close();
          } catch (_) {}
        } else {
          expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=1024-');
          request.response.statusCode = 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 1024-4095/4096',
          );
          request.response.contentLength = bytes.length - 1024;
          request.response.add(bytes.sublist(1024));
          await request.response.close();
        }
      });
      await download.download(asset);
      await paused.future;
      expect(download.phase, UpdateDownloadPhase.paused);
      expect(download.received, 1024);
      await download.download(asset);
      expect(download.phase, UpdateDownloadPhase.ready);
      expect(requests, 2);
      download.dispose();
    },
  );

  test('verified download requires an explicit install and reports unknown-sources permission', () async {
    server.listen((request) async {
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    var installs = 0;
    final download = controller(
      installer: (_) async {
        installs++;
        return 'permission';
      },
    );
    await download.download(asset);
    expect(installs, 0);
    await download.install();
    expect(installs, 1);
    expect(download.message, contains('返回后再次点击安装'));
    download.dispose();
  });

  test(
    'a natively rejected APK is discarded and becomes re-downloadable',
    () async {
      server.listen((request) async {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
      var installs = 0;
      final download = controller(
        installer: (_) async {
          installs++;
          return 'invalid';
        },
      );
      await download.download(asset);
      expect(download.phase, UpdateDownloadPhase.ready);
      await download.install();
      expect(installs, 1);
      expect(download.phase, UpdateDownloadPhase.failed);
      expect(download.message, contains('重新下载'));
      expect(download.received, 0);
      final directory = Directory('${root.path}/updates');
      expect(
        await File('${directory.path}/${asset.sha256}.apk').exists(),
        isFalse,
      );
      expect(
        await File('${directory.path}/${asset.sha256}.part').exists(),
        isFalse,
      );

      // The download action is reachable again and produces a fresh ready file.
      await download.download(asset);
      expect(download.phase, UpdateDownloadPhase.ready);
      expect(installs, 1);
      expect(
        await File('${directory.path}/${asset.sha256}.apk').exists(),
        isTrue,
      );
      download.dispose();
    },
  );
}
