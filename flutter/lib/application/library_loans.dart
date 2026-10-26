import 'contracts.dart';

/// Private on-demand reads. Implementations must not persist reader records.
class LibraryLoan {
  const LibraryLoan({
    required this.id,
    this.title,
    this.author,
    this.callNumber,
    this.borrowedAt,
    this.dueAt,
  });
  final String id;
  final String? title, author, callNumber, borrowedAt, dueAt;
}

class LibraryLoanPage {
  const LibraryLoanPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });
  final List<LibraryLoan> items;
  final int page, total;
  final bool hasMore;
}

class LibraryLoansRead {
  const LibraryLoansRead({this.data, this.failure});
  final LibraryLoanPage? data;
  final FailureCode? failure;
}

abstract interface class LibraryLoansOfficialGateway {
  String libraryLoansPortalUrl();
}

abstract interface class LibraryLoansGateway {
  Future<LibraryLoansRead> libraryLoans({int page = 1});
}
