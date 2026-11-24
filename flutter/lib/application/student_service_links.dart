/// Public official destinations only; does not read or transmit account data.
abstract interface class StudentServiceLinksGateway {
  String? studentServiceUrl(String id);
}
