import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

class IndependentGateways extends Fake
    implements
        LibrarySeatingGateway,
        LibraryCatalogGateway,
        ShuttleGateway,
        BykcGateway,
        GraduateGateway,
        NoticeGateway,
        CgyyGateway,
        LocalTaskGateway {}

void main() {
  test('school systems and local tasks have independent gateway contracts', () {
    final gateway = IndependentGateways();
    expect(gateway, isA<LibrarySeatingGateway>());
    expect(gateway, isA<LibraryCatalogGateway>());
    expect(gateway, isA<ShuttleGateway>());
    expect(gateway, isA<LocalTaskGateway>());
  });
}
