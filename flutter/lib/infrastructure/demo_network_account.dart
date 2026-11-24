import 'package:ginkgo_mirror/application/network_account.dart';

mixin DemoNetworkAccount implements NetworkAccountGateway {
  @override
  Future<NetworkAccountRead> loadNetworkAccount() async =>
      const NetworkAccountRead(
        data: NetworkAccountReport(
          netFeeMinor: 3560,
          unreturnedBooks: PortalMetric(value: '1'),
          unreadMail: PortalMetric(value: '3'),
          cloudDriveFree: PortalMetric(value: '96.4', unit: 'G'),
          trafficProducts: [
            NetworkTrafficProduct(
              productName: '学生校园网示例',
              usedText: '14.2G',
              freeRemainingText: '25.8G',
              paidRemainingText: '0G',
              packageCount: 1,
            ),
          ],
          fetchedAt: '2026-11-23T12:00:00+08:00',
        ),
      );
}
