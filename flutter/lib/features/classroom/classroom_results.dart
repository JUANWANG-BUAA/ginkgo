import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/collection_window.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'classroom_detail.dart';
import 'classroom_models.dart';
import 'classroom_widgets.dart';

/// Windowed list of matched rooms. The building name heads the first row of
/// its group; tapping a row opens the room detail. The window is local
/// presentation and never asks the school for another page.
class ClassroomResultList extends StatelessWidget {
  const ClassroomResultList({
    super.key,
    required this.rows,
    required this.window,
  });
  final List<ClassroomRoomRow> rows;
  final CollectionWindow window;

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: window.end - window.start,
    findChildIndexCallback: (key) {
      if (key is! ValueKey<String>) return null;
      final index = rows.indexWhere(
        (row) => 'classroom-room-${row.building}-${row.room.id}' == key.value,
      );
      return index >= window.start && index < window.end
          ? index - window.start
          : null;
    },
    itemBuilder: (context, index) {
      final row = rows[window.start + index];
      return ClassroomResultTile(
        key: ValueKey('classroom-room-${row.building}-${row.room.id}'),
        room: row.room,
        building: row.building,
        heading:
            index == 0 ||
            rows[window.start + index - 1].building != row.building,
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) =>
                ClassroomDetail(room: row.room, building: row.building),
          ),
        ),
      );
    },
  );
}

/// Empty state of a finished query that matched no room.
class ClassroomEmptyResults extends StatelessWidget {
  const ClassroomEmptyResults({super.key});

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: AppleSection(
      animateSize: false,
      children: [
        AppleEmptyState(title: '没有符合条件的空教室', description: '请调整日期、楼栋、节次或筛选条件。'),
      ],
    ),
  );
}
