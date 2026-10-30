import 'package:ginkgo_mirror/application/contracts.dart';

/// One public notice from the school news site. The publish date is never a
/// personal deadline and never creates a reminder.
class Notice {
  const Notice({
    required this.title,
    required this.summary,
    required this.publishedAt,
    required this.url,
  });

  final String title, summary, publishedAt, url;
}

class NoticesRead {
  const NoticesRead({this.data, this.failure});
  final List<Notice>? data;
  final FailureCode? failure;
}
