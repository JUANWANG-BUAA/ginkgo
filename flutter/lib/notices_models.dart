import 'dart:convert';

/// Typed projection of `ginkgo_domain::features::notices` payloads.
class Notice {
  Notice.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      summary = json['summary'] as String,
      publishedAt = json['published_at'] as String,
      url = json['url'] as String;

  final String title, summary, publishedAt, url;
}

List<Notice> noticeList(String payload) => (jsonDecode(payload) as List)
    .cast<Map<String, dynamic>>()
    .map(Notice.fromJson)
    .toList(growable: false);
