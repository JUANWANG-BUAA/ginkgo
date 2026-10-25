import 'dart:convert';

/// Typed projection of `ginkgo_domain::features::library_books` payloads
/// (camelCase). Public OPAC values only: read-only, never personal records.

class BookHit {
  BookHit.fromJson(Map<String, dynamic> json)
    : bibId = _text(json['bibId']),
      title = _text(json['title']),
      author = _text(json['author']),
      publisher = _text(json['publisher']),
      year = _text(json['year']),
      callno = _text(json['callno']),
      isbn = _text(json['isbn']),
      itemsAvailable = json['itemsAvailable'] as int?,
      itemCount = json['itemCount'] as int?;

  final String bibId, title, author, publisher, year, callno, isbn;
  // Null means the school stayed silent; it is not zero.
  final int? itemsAvailable, itemCount;

  String get displayTitle => title.isNotEmpty ? title : '未命名书目';

  String get factLine =>
      [author, publisher, year].where((part) => part.isNotEmpty).join(' · ');

  static String _text(Object? value) => value is String ? value.trim() : '';
}

class BookPage {
  BookPage.fromJson(Map<String, dynamic> json)
    : page = json['page'] as int? ?? 1,
      pageSize = json['pageSize'] as int? ?? 0,
      total = json['total'] as int? ?? 0,
      actualTotal = json['actualTotal'] as int?,
      items = (json['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BookHit.fromJson)
          .toList(growable: false),
      hasMore = json['hasMore'] == true;

  final int page, pageSize, total;
  final int? actualTotal;
  final List<BookHit> items;
  final bool hasMore;
}

/// One physical copy. Status stays the school's own text; it is never turned
/// into a local "available" boolean.
class BookHolding {
  BookHolding.fromJson(Map<String, dynamic> json)
    : callNo = _text(json['callNo']),
      barCode = _text(json['barCode']),
      library = _text(json['library']),
      location = _text(json['location']),
      status = _text(json['status']);

  final String callNo, barCode, library, location, status;

  String get place =>
      [library, location].where((part) => part.isNotEmpty).join(' · ');

  static String _text(Object? value) => value is String ? value.trim() : '';
}

BookPage bookPage(String payload) =>
    BookPage.fromJson(jsonDecode(payload) as Map<String, dynamic>);

List<BookHolding> bookHoldings(String payload) => (jsonDecode(payload) as List)
    .cast<Map<String, dynamic>>()
    .map(BookHolding.fromJson)
    .toList(growable: false);
