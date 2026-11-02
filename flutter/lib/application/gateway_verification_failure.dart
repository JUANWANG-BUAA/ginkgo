import 'package:ginkgo_mirror/application/contracts.dart' show FailureCode;

/// Typed failure preserves school rejection, expiry and transport distinctions.
class GatewayVerificationException implements Exception {
  const GatewayVerificationException(this.failure);
  final FailureCode? failure;
}
