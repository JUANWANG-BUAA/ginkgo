import 'package:path_provider/path_provider.dart';

/// Platform-specific location for the Rust local task store.
Future<String> localTasksStorageRoot() async =>
    '${(await getApplicationSupportDirectory()).path}/tasks';
