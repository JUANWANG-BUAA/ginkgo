import '../application/contracts.dart';
import '../application/library_holdings.dart';
import '../src/rust/api/live.dart' as live;

BookHoldingsRead decodeBookHoldings(live.BookHoldingsResponse response) {
  final rows = response.data;
  if (rows == null) {
    return BookHoldingsRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return BookHoldingsRead(
    data: List.unmodifiable(
      rows.map(
        (row) => BookHolding(
          callNo: row.callNo,
          barCode: row.barCode,
          library: row.library_,
          location: row.location,
          status: row.status,
        ),
      ),
    ),
    failure: response.failure,
  );
}
