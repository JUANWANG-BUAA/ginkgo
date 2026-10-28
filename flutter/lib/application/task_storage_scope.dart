import 'package:flutter/widgets.dart';

/// Resolves the local task directory without exposing a platform plugin to pages.
typedef TaskStorageRoot = Future<String> Function();

class TaskStorageScope extends InheritedWidget {
  const TaskStorageScope({
    super.key,
    required this.resolve,
    required super.child,
  });

  final TaskStorageRoot resolve;

  static TaskStorageRoot read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<TaskStorageScope>();
    if (scope == null) throw StateError('TaskStorageScope is missing');
    return scope.resolve;
  }

  @override
  bool updateShouldNotify(TaskStorageScope oldWidget) =>
      resolve != oldWidget.resolve;
}
