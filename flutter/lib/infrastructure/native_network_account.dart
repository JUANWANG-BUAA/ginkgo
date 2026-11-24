import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/network_account.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

PortalMetric? _decodeMetric(live.PortalMetricDto? dto) =>
    dto == null ? null : PortalMetric(value: dto.value, unit: dto.unit);

NetworkAccountRead decodeNetworkAccount(live.NetworkAccountResponse response) {
  final report = response.data;
  if (report == null) {
    return NetworkAccountRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return NetworkAccountRead(
    data: NetworkAccountReport(
      netFeeMinor: report.netFeeMinor,
      netFeeFailure: report.netFeeFailure,
      unreturnedBooks: _decodeMetric(report.unreturnedBooks),
      unreadMail: _decodeMetric(report.unreadMail),
      cloudDriveFree: _decodeMetric(report.cloudDriveFree),
      portalFailure: report.portalFailure,
      trafficProducts: List.unmodifiable(
        report.trafficProducts.map(
          (item) => NetworkTrafficProduct(
            productName: item.productName,
            usedText: item.usedText,
            freeRemainingText: item.freeRemainingText,
            paidRemainingText: item.paidRemainingText,
            packageCount: item.packageCount,
          ),
        ),
      ),
      trafficFailure: report.trafficFailure,
      fetchedAt: report.fetchedAt,
    ),
    failure: response.failure,
  );
}

mixin NativeNetworkAccount implements NetworkAccountGateway {
  String? get expectedAccount;

  @override
  Future<NetworkAccountRead> loadNetworkAccount() async {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      return const NetworkAccountRead(failure: FailureCode.sessionExpired);
    }
    return ServiceHealthTracker.shared.observe(
      ServiceEndpointId.networkAccount,
      () async => decodeNetworkAccount(
        await boundedNativeRead(
          () => live.loadNetworkAccount(expectedAccount: owner),
        ),
      ),
      failureOf: (r) =>
          r.failure ?? r.data?.portalFailure ?? r.data?.trafficFailure,
      staleOf: (r) =>
          r.data != null &&
          (r.data!.portalFailure != null || r.data!.trafficFailure != null),
    );
  }
}
