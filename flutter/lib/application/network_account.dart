import 'package:ginkgo_mirror/application/failure_code.dart';

class PortalMetric {
  const PortalMetric({required this.value, this.unit});

  final String value;
  final String? unit;

  String get displayText =>
      unit == null || unit!.isEmpty ? value : '$value $unit';
}

class NetworkTrafficProduct {
  const NetworkTrafficProduct({
    this.productName,
    required this.usedText,
    required this.freeRemainingText,
    required this.paidRemainingText,
    required this.packageCount,
  });

  final String? productName;
  final String usedText;
  final String freeRemainingText;
  final String paidRemainingText;
  final int packageCount;
}

class NetworkAccountReport {
  const NetworkAccountReport({
    this.netFeeMinor,
    this.netFeeFailure,
    this.unreturnedBooks,
    this.unreadMail,
    this.cloudDriveFree,
    this.portalFailure,
    required this.trafficProducts,
    this.trafficFailure,
    required this.fetchedAt,
  });

  final int? netFeeMinor;
  final FailureCode? netFeeFailure;
  final PortalMetric? unreturnedBooks;
  final PortalMetric? unreadMail;
  final PortalMetric? cloudDriveFree;
  final FailureCode? portalFailure;
  final List<NetworkTrafficProduct> trafficProducts;
  final FailureCode? trafficFailure;
  final String fetchedAt;
}

class NetworkAccountRead {
  const NetworkAccountRead({this.data, this.failure});

  final NetworkAccountReport? data;
  final FailureCode? failure;
}

abstract interface class NetworkAccountGateway {
  Future<NetworkAccountRead> loadNetworkAccount();
}
