import '../application/contracts.dart';
import '../application/library_books.dart';
import '../src/rust/api/live.dart' as live;

BookPageRead decodeBookPage(live.BookPageResponse response) {
  final page = response.data;
  if (page == null) {
    return BookPageRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return BookPageRead(
    data: BookPage(
      page: page.page,
      pageSize: page.pageSize,
      total: page.total,
      actualTotal: page.actualTotal,
      hasMore: page.hasMore,
      items: List.unmodifiable(
        page.items.map(
          (hit) => BookHit(
            bibId: hit.bibId,
            title: hit.title,
            author: hit.author,
            publisher: hit.publisher,
            year: hit.year,
            callno: hit.callno,
            isbn: hit.isbn,
            // Absent counts stay null: the school stayed silent, not zero.
            itemsAvailable: hit.itemsAvailable,
            itemCount: hit.itemCount,
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}
