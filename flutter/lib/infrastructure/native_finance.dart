import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/finance.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

FinanceIncomeRead decodeFinanceIncomes(live.FinanceIncomeResponse response) {
  final report = response.data;
  if (report == null) {
    return FinanceIncomeRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return FinanceIncomeRead(
    data: FinanceIncomeReport(
      entries: List.unmodifiable(
        report.entries.map(
          (entry) => FinanceIncomeEntry(
            id: entry.id,
            project: entry.project,
            description: entry.description,
            grossMinor: entry.grossMinor,
            taxMinor: entry.taxMinor,
            netMinor: entry.netMinor,
            taxRate: entry.taxRate,
            recordedDate: entry.recordedDate,
            year: entry.year,
            month: entry.month,
          ),
        ),
      ),
      total: report.total,
      fetchedAt: report.fetchedAt,
    ),
    failure: response.failure,
  );
}

mixin NativeFinance implements FinanceIncomeGateway {
  String? get expectedAccount;

  @override
  Future<FinanceIncomeRead> loadFinanceIncomes() async {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      return const FinanceIncomeRead(failure: FailureCode.sessionExpired);
    }
    return ServiceHealthTracker.shared.observe(
      ServiceEndpointId.finance,
      () async => decodeFinanceIncomes(
        await boundedNativeRead(
          () => live.loadFinanceIncomes(expectedAccount: owner),
        ),
      ),
      failureOf: (r) => r.failure,
    );
  }
}
