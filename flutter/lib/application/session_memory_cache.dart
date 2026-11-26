import 'package:ginkgo_mirror/application/contracts.dart'
    show CampusCardBalanceResponse;
import 'package:ginkgo_mirror/application/finance.dart'
    show FinanceIncomeReport;
import 'package:ginkgo_mirror/application/library_loans.dart'
    show LibraryLoanPage;
import 'package:ginkgo_mirror/application/network_account.dart'
    show NetworkAccountReport;

class _TimedEntry<T> {
  const _TimedEntry(this.value, this.savedAt);
  final T value;
  final DateTime savedAt;

  bool isFresh(DateTime now, Duration ttl) => now.difference(savedAt) <= ttl;
}

/// Process-local, memory-only session cache for secondary account views
/// (campus card, network fee/traffic, finance income, library loans).
///
/// Never persists to disk; keyed by gateway instance (`Expando`) and cleared on
/// sign-out, route change, or explicit cache clear so re-entering a page renders
/// immediately without a cold start while preserving strict account isolation.
final class SessionMemoryCache {
  SessionMemoryCache._();

  static final shared = SessionMemoryCache._();
  static const Duration ttl = Duration(minutes: 5);

  Expando<_TimedEntry<CampusCardBalanceResponse>> _campusCard = Expando();
  Expando<_TimedEntry<NetworkAccountReport>> _networkAccount = Expando();
  Expando<_TimedEntry<FinanceIncomeReport>> _finance = Expando();
  Expando<Map<int, _TimedEntry<LibraryLoanPage>>> _libraryLoans = Expando();

  CampusCardBalanceResponse? readCampusCard(Object gateway) =>
      _fresh(_campusCard[gateway]);

  void writeCampusCard(Object gateway, CampusCardBalanceResponse value) {
    _campusCard[gateway] = _TimedEntry(value, DateTime.now());
  }

  NetworkAccountReport? readNetworkAccount(Object gateway) =>
      _fresh(_networkAccount[gateway]);

  void writeNetworkAccount(Object gateway, NetworkAccountReport value) {
    _networkAccount[gateway] = _TimedEntry(value, DateTime.now());
  }

  FinanceIncomeReport? readFinance(Object gateway) => _fresh(_finance[gateway]);

  void writeFinance(Object gateway, FinanceIncomeReport value) {
    _finance[gateway] = _TimedEntry(value, DateTime.now());
  }

  LibraryLoanPage? readLibraryLoans(Object gateway, int page) {
    final pages = _libraryLoans[gateway];
    if (pages == null) return null;
    return _fresh(pages[page]);
  }

  void writeLibraryLoans(Object gateway, int page, LibraryLoanPage value) {
    final pages = _libraryLoans[gateway] ??= {};
    pages[page] = _TimedEntry(value, DateTime.now());
  }

  void clearLibraryLoans(Object gateway) {
    _libraryLoans[gateway]?.clear();
  }

  void clearAll() {
    _campusCard = Expando();
    _networkAccount = Expando();
    _finance = Expando();
    _libraryLoans = Expando();
  }

  T? _fresh<T>(_TimedEntry<T>? entry) {
    if (entry == null) return null;
    return entry.isFresh(DateTime.now(), ttl) ? entry.value : null;
  }
}
