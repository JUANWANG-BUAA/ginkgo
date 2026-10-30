import 'package:ginkgo_mirror/application/platform_actions.dart';

/// The unit tests run without the platform bindings, so the pages get no
/// platform actions. The device tests bind the real ones.
const platformActions = PlatformActions();
