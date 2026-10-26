// Compatibility exports for existing callers; implementations live in adapters.
export 'package:ginkgo_mirror/application/mirror_service.dart';
export 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';
export 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';

/// Default composition for standalone feature pages; injected services take precedence.
MirrorService mirrorServiceFor({required bool demo}) =>
    demo ? const DemoMirrorService() : const NativeMirrorService();
