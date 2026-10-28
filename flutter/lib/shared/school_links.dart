import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

const schoolLinkError = '无法打开官网，请稍后重试。';

Future<bool> openSchoolLink(
  String value, {
  Future<bool> Function(Uri url)? launcher,
}) async {
  final url = Uri.tryParse(value);
  if (url == null ||
      url.scheme != 'https' ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty) {
    return false;
  }
  try {
    return await (launcher ??
        (url) => launchUrl(url, mode: LaunchMode.externalApplication))(url);
  } catch (_) {
    return false;
  }
}

Future<void> showSchoolLinkError(BuildContext context) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('无法打开官网'),
        content: const Text('请稍后重试。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
