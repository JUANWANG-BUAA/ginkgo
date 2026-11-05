import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/library_stats.dart';
import 'package:ginkgo_mirror/infrastructure/maintenance_service.dart';

// Deliberately implements only the capability the probe consumes.
class StatisticsOnly implements LibraryStatsGateway {
  StatisticsOnly(this.response, {this.isDemo = false});
  final LibraryStatsRead response;
  @override
  final bool isDemo;
  int calls = 0;
  bool? forced;

  @override
  Future<LibraryStatsRead> libraryStats({bool forceRefresh = false}) async {
    calls++;
    forced = forceRefresh;
    return response;
  }
}

void main() {
  const probe = NativeMaintenanceService();
  const fresh = LibraryStatsSnapshot(
    campuses: [],
    fetchedAt: null,
    fromCache: false,
  );

  test('demo never issues the public statistics request', () async {
    final gateway = StatisticsOnly(
      const LibraryStatsRead(data: fresh),
      isDemo: true,
    );
    expect(await probe.checkPublicService(gateway), isFalse);
    expect(gateway.calls, 0);
  });

  test(
    'probe forces a read and accepts a successful empty live snapshot',
    () async {
      final gateway = StatisticsOnly(const LibraryStatsRead(data: fresh));
      expect(await probe.checkPublicService(gateway), isTrue);
      expect(gateway.calls, 1);
      expect(gateway.forced, isTrue);
    },
  );

  test('cached, missing and failed results never prove connectivity', () async {
    for (final response in [
      const LibraryStatsRead(),
      const LibraryStatsRead(
        data: LibraryStatsSnapshot(
          campuses: [],
          fetchedAt: null,
          fromCache: true,
        ),
      ),
      const LibraryStatsRead(
        data: fresh,
        failure: FailureCode.serviceUnavailable,
      ),
    ]) {
      final gateway = StatisticsOnly(response);
      expect(await probe.checkPublicService(gateway), isFalse);
      expect(gateway.calls, 1);
      expect(gateway.forced, isTrue);
    }
  });
}
