import 'package:flutter/cupertino.dart';

Future<bool> confirmMutation(
  BuildContext context, {
  required String title,
  required String detail,
  required String action,
  bool destructive = false,
  String cancelLabel = '返回',
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                Navigator.pop(context, false);
              }
            },
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            isDefaultAction: !destructive,
            onPressed: () {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
