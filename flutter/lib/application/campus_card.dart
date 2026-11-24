import 'package:ginkgo_mirror/application/contracts.dart'
    show CampusCardBalanceResponse, MirrorEnvironment;

abstract interface class CampusCardGateway implements MirrorEnvironment {
  Future<CampusCardBalanceResponse> campusCardBalance();
}
