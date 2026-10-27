import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'classroom_widgets.dart';

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
            children: [ClassroomSectionStates(states: room.sectionStates)],
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
