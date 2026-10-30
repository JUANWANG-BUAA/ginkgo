import 'package:ginkgo_mirror/application/contracts.dart';

/// Optional iClass progress telemetry attached to a check-in read. Local hint
/// only; it never represents school state.
class CheckinProgressTelemetry {
  const CheckinProgressTelemetry({
    required this.phase,
    required this.elapsedSeconds,
  });

  final String phase;
  final int elapsedSeconds;
}

class CheckinProgressRead {
  const CheckinProgressRead({this.data, this.failure});
  final CheckinProgressTelemetry? data;
  final FailureCode? failure;
}
