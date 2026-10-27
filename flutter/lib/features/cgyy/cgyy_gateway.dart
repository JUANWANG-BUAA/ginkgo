import 'package:ginkgo_mirror/application/contracts.dart' as live;
import 'package:ginkgo_mirror/mirror_service.dart';

import 'cgyy_models.dart';

/// Loader signature shared by the CGYY hub and the day/orders page.
typedef CgyyLoader = Future<live.ReadOnlyResponse> Function({
  required String kind,
  required int siteId,
  required String date,
  required bool forceRefresh,
});

/// Reads CGYY data through the injected loader, or through the campus
/// gateway when the page was built without a loader.
Future<live.ReadOnlyResponse> cgyyRead({
  required bool demo,
  required CgyyLoader? loader,
  required CampusGateway? service,
  required String kind,
  required int siteId,
  required String date,
  required bool forceRefresh,
}) async {
  final injected = loader;
  if (injected != null) {
    return injected(
      kind: kind,
      siteId: siteId,
      date: date,
      forceRefresh: forceRefresh,
    );
  }
  return (service ?? mirrorServiceFor(demo: demo)).cgyy(
    kind: kind,
    siteId: siteId,
    date: date,
    forceRefresh: forceRefresh,
  );
}

/// Reads the local write-protection state of the last CGYY write. A failed or
/// unknown read keeps the protection on; it never clears it silently.
Future<CgyyWriteStatus> cgyyReadWriteStatus(CgyyBookingGateway gateway) async {
  try {
    final response = await gateway.executeCgyy({'action': 'status'});
    if (response.failure != null ||
        response.stale ||
        response.payload == null) {
      throw const FormatException('Missing write status');
    }
    final status = cgyyWriteStatus(response.payload!);
    if (!status.known) {
      throw const FormatException('Unknown write status');
    }
    return status;
  } catch (_) {
    return const CgyyWriteStatus.unknown();
  }
}
