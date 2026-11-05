import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/application/external_links.dart';
import 'package:ginkgo_mirror/shared/school_links.dart' as links;

export 'package:ginkgo_mirror/shared/school_links.dart' show schoolLinkError;

/// The application root provides the platform capability to every route.
class ExternalLinkScope extends InheritedWidget {
  const ExternalLinkScope({
    super.key,
    required this.launcher,
    required super.child,
  });

  final ExternalLinkLauncher launcher;

  static ExternalLinkLauncher? maybeLauncherOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExternalLinkScope>()?.launcher;

  @override
  bool updateShouldNotify(ExternalLinkScope oldWidget) =>
      launcher != oldWidget.launcher;
}

Future<bool> openSchoolLink(BuildContext context, String value) async {
  final launcher = ExternalLinkScope.maybeLauncherOf(context);
  if (launcher == null) return false;
  return links.openSchoolLink(value, launcher: launcher);
}

Future<void> showSchoolLinkError(BuildContext context) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('无法打开官网'),
        content: const Text('请稍后重试。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
