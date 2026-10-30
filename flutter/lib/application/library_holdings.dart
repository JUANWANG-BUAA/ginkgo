import 'package:ginkgo_mirror/application/contracts.dart';

/// One physical copy. Status stays the school's own text; it is never turned
/// into a local "available" boolean.
class BookHolding {
  const BookHolding({
    required this.callNo,
    required this.barCode,
    required this.library,
    required this.location,
    required this.status,
  });

  final String callNo, barCode, library, location, status;

  String get place =>
      [library, location].where((part) => part.isNotEmpty).join(' · ');
}

class BookHoldingsRead {
  const BookHoldingsRead({this.data, this.failure});
  final List<BookHolding>? data;
  final FailureCode? failure;
}
