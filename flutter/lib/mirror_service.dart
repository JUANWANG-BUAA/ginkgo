// Compatibility barrel for the composition root and device tests.
//
// The page layer must NOT import this file: it re-exports the native and demo
// adapters, which would put `src/rust` in every page's dependency graph. Pages
// take `package:ginkgo_mirror/application/mirror_service.dart` for types and
// receive their gateway from the shell; a page never composes an adapter
// itself, because a fallback locator would give the page its own adapter
// instance and therefore its own account binding.
export 'package:ginkgo_mirror/application/mirror_service.dart';
export 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';
export 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
