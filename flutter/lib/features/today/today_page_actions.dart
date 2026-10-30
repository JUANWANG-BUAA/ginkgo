import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';

/// Opens the pages the today dashboard links to. Only one route may be
/// pushed at a time: a second tap while a page is still opening is ignored
/// instead of stacking routes on top of each other.
class TodayNavigator {
  bool _opening = false;

  /// True while a linked page is being opened.
  bool get opening => _opening;

  Future<void> openTasks(
    BuildContext context, {
    required MirrorService service,
    required PlatformActions fileActions,
    required String? storageRoot,
    required String? taskId,
    required bool Function() isCurrent,
    required Future<void> Function() reload,
    required void Function(String message) onFailure,
  }) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!context.mounted || !isCurrent()) return;
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => TasksPage(
            storageRoot: storageRoot,
            service: service,
            fileActions: fileActions,
            academicService: service,
            initialTaskId: taskId,
          ),
        ),
      );
      if (context.mounted && isCurrent()) await reload();
    } catch (_) {
      if (context.mounted && isCurrent()) {
        onFailure('无法打开个人待办，请重试。');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> openHomework(
    BuildContext context, {
    required MirrorService service,
    required PlatformActions fileActions,
    required String? storageRoot,
    required HomeworkItem item,
    required bool Function() isCurrent,
    required Future<void> Function() reload,
    required void Function(String message) onFailure,
  }) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => HomeworkDetailPage(
            item: item,
            fileActions: fileActions,
            service: service,
            taskService: service,
            storageRoot: storageRoot,
          ),
        ),
      );
      if (context.mounted && isCurrent()) await reload();
    } catch (_) {
      if (context.mounted && isCurrent()) {
        onFailure('无法打开个人待办，请重试。');
      }
    } finally {
      _opening = false;
    }
  }
}

/// Ask what to do with the current account. Returns true when the user asked
/// to leave it; a demo account only returns to the sign-in screen.
Future<bool> showTodayAccountDialog(
  BuildContext context, {
  required String? accountName,
  required bool demo,
}) async {
  final action = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(accountName ?? (demo ? '离线演示' : '账号')),
      content: Text(demo ? '当前为离线合成样例，不连接学校账号。' : '当前已登录真实学校账号。'),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, 'exit'),
          child: Text(demo ? '返回登录' : '退出登录'),
        ),
      ],
    ),
  );
  return action == 'exit';
}
