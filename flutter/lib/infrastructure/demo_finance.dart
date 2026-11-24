import 'package:ginkgo_mirror/application/finance.dart';

mixin DemoFinance implements FinanceIncomeGateway {
  @override
  Future<FinanceIncomeRead> loadFinanceIncomes() async =>
      const FinanceIncomeRead(
        data: FinanceIncomeReport(
          entries: [
            FinanceIncomeEntry(
              id: 'synthetic-income-1',
              project: '助研津贴',
              description: '合成助研发放示例',
              grossMinor: 80000,
              taxMinor: 0,
              netMinor: 80000,
              taxRate: '0%',
              recordedDate: '2026-11-15',
              year: '2026',
              month: '11',
            ),
            FinanceIncomeEntry(
              id: 'synthetic-income-2',
              project: '国家助学金',
              description: '秋季学期助学金示例',
              grossMinor: 100000,
              taxMinor: 0,
              netMinor: 100000,
              taxRate: '0%',
              recordedDate: '2026-10-20',
              year: '2026',
              month: '10',
            ),
          ],
          total: 2,
          fetchedAt: '2026-11-23T12:00:00+08:00',
        ),
      );
}
