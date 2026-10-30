import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/library_books.dart';

/// Test fixtures stay map-shaped; production now receives a typed DTO.
BookPageRead bookPageRead(Map<String, dynamic>? json, {FailureCode? failure}) {
  if (json == null) return BookPageRead(failure: failure);
  final items = (json['items'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  return BookPageRead(
    data: BookPage(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      actualTotal: json['actualTotal'] as int?,
      hasMore: json['hasMore'] == true,
      items: [
        for (final hit in items)
          BookHit(
            bibId: hit['bibId'] as String? ?? '',
            title: hit['title'] as String? ?? '',
            author: hit['author'] as String? ?? '',
            publisher: hit['publisher'] as String? ?? '',
            year: hit['year'] as String? ?? '',
            callno: hit['callno'] as String? ?? '',
            isbn: hit['isbn'] as String? ?? '',
            itemsAvailable: hit['itemsAvailable'] as int?,
            itemCount: hit['itemCount'] as int?,
          ),
      ],
    ),
    failure: failure,
  );
}
