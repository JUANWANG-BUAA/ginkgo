import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

import 'cgyy_models.dart';

/// Loader signature shared by the CGYY hub and the day/orders page.
typedef CgyyLoader = Future<CgyyLoadRead> Function({
  required String kind,
  required int siteId,
  required String date,
  required bool forceRefresh,
});

/// Reads CGYY data through the injected loader or the injected campus gateway.
///
/// The page never constructs a service: the shell already resolved one, and a
/// fallback locator here would quietly give a page its own adapter instance
/// (and therefore its own account binding) instead of the workspace's.
Future<CgyyLoadRead> cgyyRead({
  required CgyyLoader? loader,
  required CgyyGateway? service,
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
  final gateway = service;
  if (gateway == null) throw StateError('当前页面没有可用的研讨室服务');
  return gateway.cgyy(
    kind: kind,
    siteId: siteId,
    date: date,
    forceRefresh: forceRefresh,
  );
}

Future<CgyyLoadRead> cgyyOrderDetail({
  required int orderId,
  CgyyLoader? loader,
  CgyyGateway? service,
  bool forceRefresh = false,
}) => cgyyRead(
  loader: loader,
  service: service,
  kind: 'order',
  siteId: orderId,
  date: '',
  forceRefresh: forceRefresh,
);

Future<CgyyLoadRead> cgyyLockCode({
  CgyyLoader? loader,
  CgyyGateway? service,
  bool forceRefresh = false,
}) => cgyyRead(
  loader: loader,
  service: service,
  kind: 'lockCode',
  siteId: 0,
  date: '',
  forceRefresh: forceRefresh,
);

/// Reads the local write-protection state of the last CGYY write. A failed or
/// unknown read keeps the protection on; it never clears it silently.
Future<CgyyWriteStatus> cgyyReadWriteStatus(CgyyBookingGateway gateway) async {
  try {
    final result = await gateway.executeCgyy(const CgyyStatusCommand());
    final status = CgyyWriteStatus.fromState(result.state);
    if (!status.known) {
      throw const FormatException('Unknown write status');
    }
    return status;
  } catch (_) {
    return const CgyyWriteStatus.unknown();
  }
}
