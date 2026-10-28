import 'package:ginkgo_mirror/application/mirror_service.dart';

import 'demo_mirror_service.dart';
import 'native_mirror_service.dart';

/// Default composition for standalone feature pages.
///
/// Only the composition root and the handful of pages that can be built
/// without an injected service may use this. Pages that receive a service must
/// never reach for it: that is what keeps the page layer free of adapters.
MirrorService mirrorServiceFor({required bool demo}) =>
    demo ? const DemoMirrorService() : const NativeMirrorService();
