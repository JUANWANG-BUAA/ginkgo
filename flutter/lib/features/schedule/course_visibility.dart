import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'schedule_widgets.dart';

/// User classification, isolated by account and upstream system. SPOC and
/// iClass course IDs are never interchangeable. Store digests, not course names.
class CourseVisibility extends ChangeNotifier {
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

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    final digest = sha256.convert(utf8.encode(account));
    return File('${directory.path}/course-visibility-$digest.json');
  }

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
        _hidden.addAll(await load!());
      } else if (save == null) {
        final file = await _file();
        await file.parent.create(recursive: true);
        if (await file.exists()) {
          final values = jsonDecode(await file.readAsString()) as List;
          _hidden.addAll(
            values.whereType<String>().where(
              (value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value),
            ),
          );
        }
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
          await restore();
          final snapshot = Set<String>.of(_hidden);
          if (save != null) {
            await save!(snapshot);
          } else {
            final file = await _file();
            await file.parent.create(recursive: true);
            final temporary = File('${file.path}.tmp');
            await temporary.writeAsString(
              jsonEncode(snapshot.toList()),
              flush: true,
            );
            await temporary.rename(file.path);
          }
        })
        .catchError((Object _) {
          error = '课程范围已应用，但未能保存到本机';
          notifyListeners();
        });
    return _pending;
  }
}

class CourseVisibilityScope extends StatefulWidget {
  const CourseVisibilityScope({
    super.key,
    required this.account,
    required this.child,
  });
  final String account;
  final Widget child;
  static CourseVisibility? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CourseVisibilityScope>()
      ?.notifier;
  @override
  State<CourseVisibilityScope> createState() => _CourseVisibilityScopeState();
}

class _CourseVisibilityScopeState extends State<CourseVisibilityScope> {
  late final controller = CourseVisibility(widget.account);
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

class CourseRangePage extends StatelessWidget {
  const CourseRangePage({
    super.key,
    required this.preferences,
    required this.system,
    required this.courses,
  });
  final CourseVisibility preferences;
  final String system;
  final Map<String, String> courses;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) => CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('我的课程范围')),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        child: ListView(
          children: [
            ScheduleSection(
              title: '作为我的学生课程',
              footer: const Text(
                '关闭你担任助教或教师的课程后，主列表和个人统计会将其收起；可随时重新开启。此设置只影响本机当前账号，不修改学校选课或身份。不同系统分别设置。',
              ),
              children: [
                for (final course in courses.entries)
                  AppleListTile(
                    title: Text(course.value),
                    trailing: CupertinoSwitch(
                      key: ValueKey('course-range-${course.key}'),
                      value: !preferences.hidden(system, course.key),
                      onChanged: preferences.loadFailed
                          ? null
                          : (value) => preferences.setHidden(
                              system,
                              course.key,
                              !value,
                            ),
                    ),
                  ),
              ],
            ),
            if (preferences.error != null)
              ScheduleEmptySection(
                title: preferences.error!,
                description: '重试成功后即可继续调整；已保存的原设置不会被覆盖。',
                action: '重试读取',
                onAction: preferences.retryRestore,
                error: true,
              ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    ),
  );
}
