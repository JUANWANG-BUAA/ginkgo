import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// A single, quiet entrance while restoration runs; never delays navigation.
class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final brand = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.leaf_arrow_circlepath,
          size: 56,
          color: AppleDesign.accent.resolveFrom(context),
        ),
        const SizedBox(height: 18),
        const Text(
          'Ginkgo 银杏',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        ),
      ],
    );
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reducedMotion)
                  brand
                else
                  TweenAnimationBuilder<double>(
                    key: const Key('startup-entrance'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: brand,
                    builder: (context, progress, child) => Opacity(
                      opacity: 0.6 + progress * 0.4,
                      child: Transform.scale(
                        scale: 0.98 + progress * 0.02,
                        child: child,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                Semantics(
                  liveRegion: true,
                  label: '正在恢复本地会话',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      const GinkgoActivity(size: 20),
                      const SizedBox(height: 12),
                      Text(
                        '正在恢复本地会话…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
