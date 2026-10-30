import '../application/contracts.dart';
import '../application/library_loans.dart';
import '../src/rust/api/live.dart' as live;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

/// Decode the business projection, never the school OPAC envelope.
LibraryLoansRead decodeLibraryLoans(live.LibraryLoansResponse response) {
  final page = response.data;
  if (page == null) {
    return LibraryLoansRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return LibraryLoansRead(
    data: LibraryLoanPage(
      items: List.unmodifiable(
        page.items.map(
          (loan) => LibraryLoan(
            id: loan.id,
            title: loan.title,
            author: loan.author,
            callNumber: loan.callNumber,
            borrowedAt: loan.borrowedAt,
            dueAt: loan.dueAt,
          ),
        ),
      ),
      page: page.page,
      total: page.total,
      hasMore: page.hasMore,
    ),
    failure: response.failure,
  );
}

mixin NativeLibraryLoans
    implements LibraryLoansGateway, LibraryLoansOfficialGateway {
  @override
  String libraryLoansPortalUrl() => live.libraryLoansPortalUrl();
  String? get expectedAccount;
  @override
  Future<LibraryLoansRead> libraryLoans({int page = 1}) async {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      return const LibraryLoansRead(failure: FailureCode.sessionExpired);
    }
    return decodeLibraryLoans(
      await boundedNativeRead(
        () => live.loadLibraryLoans(expectedAccount: owner, page: page),
      ),
    );
  }
}
