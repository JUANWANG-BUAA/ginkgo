import '../application/library_loans.dart';

mixin DemoLibraryLoans implements LibraryLoansGateway {
  @override
  Future<LibraryLoansRead> libraryLoans({int page = 1}) async =>
      const LibraryLoansRead(
        data: LibraryLoanPage(
          items: [
            LibraryLoan(
              id: 'synthetic-loan',
              title: '合成借阅示例',
              author: '示例作者',
              borrowedAt: '2026-10-01',
              dueAt: '2026-11-01',
            ),
          ],
          page: 1,
          total: 1,
          hasMore: false,
        ),
      );
}
