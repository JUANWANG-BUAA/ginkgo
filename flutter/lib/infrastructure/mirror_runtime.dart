import '../src/rust/frb_generated.dart';

/// Load FFI without eagerly constructing the network session.
Future<void> initializeMirrorRuntime() => RustLib.init();
