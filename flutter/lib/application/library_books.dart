import 'package:ginkgo_mirror/application/contracts.dart';

/// Public OPAC catalogue values. Read-only, never personal records.

class BookHit {
  const BookHit({
    required this.bibId,
    required this.title,
    required this.author,
    required this.publisher,
    required this.year,
    required this.callno,
    required this.isbn,
    this.itemsAvailable,
    this.itemCount,
  });

  final String bibId, title, author, publisher, year, callno, isbn;

  /// Null means the school stayed silent; it is not zero.
  final int? itemsAvailable, itemCount;

  String get displayTitle => title.isNotEmpty ? title : '未命名书目';

  String get factLine =>
      [author, publisher, year].where((part) => part.isNotEmpty).join(' · ');
}

class BookPage {
  const BookPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
    required this.hasMore,
    this.actualTotal,
  });

  final int page, pageSize, total;
  final int? actualTotal;
  final List<BookHit> items;
  final bool hasMore;
}

class BookPageRead {
  const BookPageRead({this.data, this.failure});
  final BookPage? data;
  final FailureCode? failure;
}
