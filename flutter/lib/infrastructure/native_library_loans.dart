import 'dart:convert';

import '../application/contracts.dart';
import '../application/library_loans.dart';
import '../src/rust/api/live.dart' as live;

import 'package:ginkgo_mirror/infrastructure/native_command.dart';

/// Decode the business projection, never the school OPAC envelope.
LibraryLoansRead decodeLibraryLoans(ReadOnlyResponse response) {
  if (response.failure != null) {
    return LibraryLoansRead(failure: response.failure);
  }
  try {
    final j = jsonDecode(response.payload!) as Map<String, dynamic>;
    return LibraryLoansRead(
      data: LibraryLoanPage(
        items: (j['items'] as List)
            .map((value) {
              final row = value as Map<String, dynamic>;
              return LibraryLoan(
                id: row['id'] as String,
                title: row['title'] as String?,
                author: row['author'] as String?,
                callNumber: row['callNumber'] as String?,
                borrowedAt: row['borrowedAt'] as String?,
                dueAt: row['dueAt'] as String?,
              );
            })
            .toList(growable: false),
        page: j['page'] as int,
        total: j['total'] as int,
        hasMore: j['hasMore'] as bool,
      ),
    );
  } catch (_) {
    return const LibraryLoansRead(failure: FailureCode.changedResponse);
  }
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
