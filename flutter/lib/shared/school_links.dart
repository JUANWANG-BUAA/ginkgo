import 'package:ginkgo_mirror/application/external_links.dart';

const schoolLinkError = '无法打开官网，请稍后重试。';

Future<bool> openSchoolLink(
  String value, {
  required ExternalLinkLauncher launcher,
}) async {
  final url = Uri.tryParse(value);
  if (url == null ||
      url.scheme != 'https' ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty) {
    return false;
  }
  try {
    return await launcher(url);
  } catch (_) {
    return false;
  }
}
