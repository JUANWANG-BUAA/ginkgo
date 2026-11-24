import 'package:ginkgo_mirror/application/failure_code.dart';

/// Whitelisted student finance income entry. Never retains ID-card or bank numbers.
class FinanceIncomeEntry {
  const FinanceIncomeEntry({
    required this.id,
    this.project,
    this.description,
    this.grossMinor,
    this.taxMinor,
    this.netMinor,
    this.taxRate,
    this.recordedDate,
    this.year,
    this.month,
  });

  final String id;
  final String? project;
  final String? description;
  final int? grossMinor;
  final int? taxMinor;
  final int? netMinor;
  final String? taxRate;
  final String? recordedDate;
  final String? year;
  final String? month;
}

class FinanceIncomeReport {
  const FinanceIncomeReport({
    required this.entries,
    required this.total,
    required this.fetchedAt,
  });

  final List<FinanceIncomeEntry> entries;
  final int total;
  final String fetchedAt;
}

class FinanceIncomeRead {
  const FinanceIncomeRead({this.data, this.failure});

  final FinanceIncomeReport? data;
  final FailureCode? failure;
}

abstract interface class FinanceIncomeGateway {
  Future<FinanceIncomeRead> loadFinanceIncomes();
}
