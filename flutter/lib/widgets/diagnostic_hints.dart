import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:ginkgo_mirror/application/diagnostic_log.dart';

class DiagnosticHintOverlay extends StatelessWidget {
  const DiagnosticHintOverlay({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DiagnosticLog.shared,
    builder: (context, _) {
      final entry = DiagnosticLog.shared.current;
      return Stack(
        children: [
          child,
          if (entry != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 72,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemGroupedBackground
                            .resolveFrom(context),
                        border: Border.all(
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '遇到问题，已记录脱敏诊断',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(48, 48),
                            onPressed: () => _details(context, entry),
                            child: const Text(
                              '查看',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(48, 48),
                            onPressed: DiagnosticLog.shared.dismiss,
                            child: Semantics(
                              label: '关闭错误提示',
                              child: Icon(CupertinoIcons.xmark, size: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
  Future<void> _details(BuildContext context, DiagnosticEntry entry) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('错误诊断'),
          content: Text(
            '${entry.hint}\n\n诊断编号：${entry.code}\n仅保留最近 50 条本次运行记录，不含个人信息。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: DiagnosticLog.shared.entries
                        .map((e) => e.summary)
                        .join('\n'),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('复制脱敏日志'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
}
