import 'package:ginkgo_mirror/application/contracts.dart';

/// One matched room together with the building it belongs to.
typedef ClassroomRoomRow = ({String building, ClassroomRow room});

/// Filter and sort selection of one classroom query. The page owns the
/// instance; every change reissues the query instead of being cached.
class ClassroomFilters {
  ClassroomFilters({
    this.section = 0,
    this.minimumFree = 0,
    this.minimumConsecutive = 0,
    this.sort = ClassroomSort.name,
  });
  int section;
  int minimumFree;
  int minimumConsecutive;
  ClassroomSort sort;

  /// Whether the current selection narrows the published result.
  bool get isActive =>
      section != 0 ||
      minimumFree != 0 ||
      minimumConsecutive != 0 ||
      sort != ClassroomSort.name;

  void reset() {
    section = 0;
    minimumFree = 0;
    minimumConsecutive = 0;
    sort = ClassroomSort.name;
  }
}
