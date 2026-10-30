/// Which backing environment a gateway is running against.
///
/// Kept apart from the gateway declarations so a contract file can name its
/// environment without importing every other gateway.
abstract interface class MirrorEnvironment {
  bool get isDemo;
}
