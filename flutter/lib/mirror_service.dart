// Compatibility exports for existing callers; implementations live in adapters.
export 'application/mirror_service.dart';
export 'infrastructure/native_mirror_service.dart';
export 'infrastructure/demo_mirror_service.dart';

import 'application/mirror_service.dart';
import 'infrastructure/native_mirror_service.dart';
import 'infrastructure/demo_mirror_service.dart';

/// Default composition for standalone feature pages; injected services take precedence.
MirrorService mirrorServiceFor({required bool demo}) =>
    demo ? const DemoMirrorService() : const NativeMirrorService();
