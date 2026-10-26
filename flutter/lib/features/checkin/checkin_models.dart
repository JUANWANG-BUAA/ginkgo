import 'dart:convert';

/// Optional iClass progress telemetry attached to a check-in read. Local hint
/// only; it never represents school state.
class CheckinProgressTelemetry {
  CheckinProgressTelemetry.fromJson(Map<String, dynamic> json)
    : phase = json['phase'] as String?,
      elapsedSeconds = (((json['elapsedMs'] as num?) ?? 0) / 1000).floor();

  final String? phase;
  final int elapsedSeconds;
}

CheckinProgressTelemetry? checkinProgress(String payload) {
  try {
    return CheckinProgressTelemetry.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  } catch (_) {
    return null;
  }
}
