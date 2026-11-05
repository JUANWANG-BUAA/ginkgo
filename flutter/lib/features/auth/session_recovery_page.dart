import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';

class SessionRecoveryPage extends StatelessWidget {
  const SessionRecoveryPage({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onLogin,
  });

  final String? message;
  final VoidCallback onRetry, onLogin;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('Ginkgo')),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GinkgoSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle, size: 40),
              const SizedBox(height: GinkgoSpacing.base),
              const Text('暂未恢复登录状态', textAlign: TextAlign.center),
              const SizedBox(height: GinkgoSpacing.md),
              Text(message ?? '恢复暂时失败，请稍后重试', textAlign: TextAlign.center),
              const SizedBox(height: GinkgoSpacing.base),
              CupertinoButton.filled(
                onPressed: onRetry,
                child: const Text('重试恢复'),
              ),
              CupertinoButton(onPressed: onLogin, child: const Text('手动登录')),
            ],
          ),
        ),
      ),
    ),
  );
}
