import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';

/// User classification, isolated by account and upstream system. SPOC and
/// iClass course IDs are never interchangeable. Store digests, not course names.
class CourseVisibility extends ChangeNotifier {
  /// In-memory unless persistence callbacks are injected at the composition root.
  CourseVisibility(this.account, {this.save, this.load});
  final String account;
  final Future<void> Function(Set<String>)? save;
  final Future<Set<String>> Function()? load;
  final Set<String> _hidden = {};
  bool ready = false;

  /// A failed read locks editing until an explicit retry succeeds, so a
  /// partially loaded set can never be written back over the stored one.
  bool loadFailed = false;
  String? error;
  Future<void> _pending = Future.value();
  Future<void>? _restoring;
  bool _disposed = false;
  final Map<String, bool> _changesBeforeRestore = {};
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String _key(String system, String id) =>
      sha256.convert(utf8.encode('$system:$id')).toString();

  bool hidden(String system, String id) => _hidden.contains(_key(system, id));

  Future<void> restore() => _restoring ??= _restore();

  /// Explicit retry after a failed read. Re-opens the restore path and applies
  /// any changes queued while the previous restore was still running.
  Future<void> retryRestore() {
    if (!loadFailed || _disposed) return Future.value();
    loadFailed = false;
    error = null;
    _restoring = null;
    return restore();
  }

  Future<void> _restore() async {
    try {
      if (load != null) {
        final values = await load!();
        if (_disposed) return;
        _hidden.addAll(values);
      }
    } catch (_) {
      // Stay not-ready: switches stay disabled and nothing is saved until a
      // retry reads the stored range successfully.
      loadFailed = true;
      error = '未能读取课程范围；为保护原设置，已暂停编辑。请重试。';
      notifyListeners();
      return;
    }
    for (final change in _changesBeforeRestore.entries) {
      if (change.value) {
        _hidden.add(change.key);
      } else {
        _hidden.remove(change.key);
      }
    }
    _changesBeforeRestore.clear();
    ready = true;
    loadFailed = false;
    error = null;
    notifyListeners();
  }

  Future<void> setHidden(String system, String id, bool hidden) {
    if (loadFailed || _disposed) return Future.value();
    final key = _key(system, id);
    if (!ready) _changesBeforeRestore[key] = hidden;
    if (hidden) {
      _hidden.add(key);
    } else {
      _hidden.remove(key);
    }
    error = null;
    notifyListeners();
    _pending = _pending
        .then((_) async {
          if (_disposed) return;
          await restore();
          if (_disposed || !ready || loadFailed) return;
          final snapshot = Set<String>.of(_hidden);
          if (save != null) {
            try {
              await save!(snapshot);
            } catch (e) {
              error = '课程范围已应用，但未能保存到本机';
              loadFailed = true;
              notifyListeners();
              return;
            }
          }
        })
        .catchError((Object e) {
          if (_disposed) return;
          error = '课程范围已应用，但未能保存到本机';
          loadFailed = true;
          notifyListeners();
        });
    return _pending;
  }
}

class CourseVisibilityScope extends StatefulWidget {
  const CourseVisibilityScope({
    super.key,
    required this.account,
    required this.controllerFactory,
    required this.child,
  });
  final String account;
  final CourseVisibility Function(String account) controllerFactory;
  final Widget child;
  static CourseVisibility? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CourseVisibilityScope>()
      ?.notifier;
  @override
  State<CourseVisibilityScope> createState() => _CourseVisibilityScopeState();
}

class _CourseVisibilityScopeState extends State<CourseVisibilityScope> {
  late final controller = widget.controllerFactory(widget.account);
  @override
  void initState() {
    super.initState();
    controller.restore();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CourseVisibilityScope(notifier: controller, child: widget.child);
}

class _CourseVisibilityScope extends InheritedNotifier<CourseVisibility> {
  const _CourseVisibilityScope({required super.notifier, required super.child});
}
