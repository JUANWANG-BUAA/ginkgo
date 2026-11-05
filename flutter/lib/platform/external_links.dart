import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternalLink(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
