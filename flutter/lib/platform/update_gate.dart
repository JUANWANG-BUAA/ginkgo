import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:url_launcher/url_launcher.dart';

/// 最低版本门禁：学校协议出现不兼容变化时，旧客户端不静默失败。
///
/// 清单是发布前人工维护的静态文件（GitHub Pages），失败一律放行，保证离线可用；
/// 只负责“是否允许继续使用”，不承载协议参数、不下载代码。
class UpdateGate {
  const UpdateGate({required this.minBuild, this.message, this.releasesUrl});

  /// 允许运行的最小 build（package_info 的 buildNumber）。
  final int minBuild;

  /// 可选提示，说明为什么必须更新。
  final String? message;

  /// 可选发布页；默认仓库 Releases。
  final String? releasesUrl;

  static const manifestUrl =
      'https://juanwang-buaa.github.io/ginkgo/update-gate.json';
  static const defaultReleasesUrl =
      'https://github.com/JUANWANG-BUAA/ginkgo/releases';

  /// The manifest is maintained by this project, so its release link may only
  /// name the official release surfaces. Anything else falls back to the
  /// built-in default instead of opening an arbitrary HTTPS host.
  static const _officialReleaseHosts = {
    'github.com',
    'juanwang-buaa.github.io',
  };

  static bool _isOfficialReleasesUrl(Object? value) {
    if (value is! String) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        _officialReleaseHosts.contains(uri.host);
  }

  /// 解析清单；结构不符合预期时视为“没有清单”，不阻塞启动。
  static UpdateGate? parse(String body) {
    if (body.length > 64 * 1024) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final minBuild = decoded['minBuild'];
    if (minBuild is! int || minBuild < 0) return null;
    final message = decoded['message'];
    final releases = decoded['releasesUrl'];
    return UpdateGate(
      minBuild: minBuild,
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : null,
      releasesUrl: _isOfficialReleasesUrl(releases) ? releases : null,
    );
  }

  /// 拉取清单；任何网络/解析错误都返回 null，由调用方放行。
  static Future<UpdateGate?> fetch({
    HttpClient? client,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final httpClient = client ?? HttpClient();
    try {
      final request = await httpClient
          .getUrl(Uri.parse(manifestUrl))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return parse(body);
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close(force: true);
    }
  }

  bool blocks(int buildNumber) => buildNumber < minBuild;

  Uri get releasesUri => Uri.parse(releasesUrl ?? defaultReleasesUrl);
}

/// 低于最低版本时替代工作区的更新页；不提供“跳过”，避免旧客户端继续写上游。
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({
    super.key,
    required this.gate,
    required this.onRetry,
    this.installedVersion,
  });

  final UpdateGate gate;
  final String? installedVersion;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.arrow_down_circle_fill,
                size: 56,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),
              const Text(
                '需要更新',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                gate.message ?? '当前版本已不兼容学校接口的变化，请安装新版本后继续使用。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppleDesign.bodyCondensedSize,
                  height: 1.5,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              if (installedVersion != null) ...[
                const SizedBox(height: 10),
                Text(
                  '当前版本 $installedVersion',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () => launchUrl(
                    gate.releasesUri,
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('打开发布页'),
                ),
              ),
              CupertinoButton(
                onPressed: () => onRetry(),
                child: const Text('重新检查'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
