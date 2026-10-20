import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';

import 'src/rust/api/mirror.dart';

class ClassroomDetail extends StatelessWidget {
  const ClassroomDetail({
    super.key,
    required this.room,
    required this.building,
  });
  final ClassroomRow room;
  final String building;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: CupertinoNavigationBar(
      middle: Text(room.name),
      previousPageTitle: '空教室',
    ),
    child: SafeArea(
      child: ListView(
        children: [
          AppleSection(
            header: Text(room.name),
            children: [
              AppleListTile(
                title: const Text('楼栋'),
                additionalInfo: Text(building),
              ),
              AppleListTile(
                title: const Text('空闲节次'),
                additionalInfo: Text('${room.sections.length} 节'),
              ),
              AppleListTile(
                title: const Text('最长连续空闲'),
                additionalInfo: Text('${room.longestRun} 节'),
              ),
            ],
          ),
          AppleSection(
            header: const Text('节次状态'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(13) / 13;
                    final columns = (constraints.maxWidth / (90 * textScale))
                        .floor()
                        .clamp(1, 6);
                    final width =
                        (constraints.maxWidth - (columns - 1) * 8) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final section in room.sectionStates)
                          Semantics(
                            label:
                                '第 ${section.number} 节，${section.available ? '空闲' : '未标为空闲'}',
                            excludeSemantics: true,
                            child: Container(
                              width: width,
                              constraints: const BoxConstraints(minHeight: 36),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                color:
                                    (section.available
                                            ? CupertinoColors.systemGreen
                                            : CupertinoColors.systemGrey)
                                        .resolveFrom(context)
                                        .withValues(alpha: 0.10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    section.available
                                        ? CupertinoIcons
                                              .check_mark_circled_solid
                                        : CupertinoIcons.minus_circle,
                                    size: 14,
                                    color: section.available
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.secondaryLabel
                                              .resolveFrom(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '第 ${section.number} 节',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: section.available
                                          ? CupertinoColors.systemGreen
                                          : CupertinoColors.secondaryLabel
                                                .resolveFrom(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          AppleSection(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '✓ 表示学校标为空闲；— 表示未标为空闲，不代表已确认占用。实际使用前请以现场和学校安排为准。',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
