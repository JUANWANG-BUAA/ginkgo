import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.description,
    this.symbol = CupertinoIcons.time,
    this.details = const [],
  });
  final String title;
  final String description;
  final IconData symbol;
  final List<String> details;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      slivers: [
        ApplePageHeader(largeTitle: Text(title), border: null),
        SliverList.list(
          children: [
            AppleSection(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        symbol,
                        size: 52,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty)
              AppleSection(
                header: const Text('待补齐'),
                children: [
                  for (final detail in details)
                    AppleListTile(
                      leading: const Icon(
                        CupertinoIcons.circle,
                        size: 8,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                      title: Text(detail, maxLines: 2),
                    ),
                ],
              ),
            const AppleSection(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '该页面已按 iOS 的信息层级放入导航；Rust/Flutter 后端尚未迁移，不展示伪造数据。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
