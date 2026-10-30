import 'package:ginkgo_mirror/application/contracts.dart';

/// One matched room together with the building it belongs to.
typedef ClassroomRoomRow = ({String building, ClassroomRow room});

String classroomSectionRanges(List<int> sections) {
  if (sections.isEmpty) return '';
  final ordered = sections.toSet().toList()..sort();
  final ranges = <String>[];
  var start = ordered.first;
  var previous = start;
  for (final section in ordered.skip(1)) {
    if (section != previous + 1) {
      ranges.add(start == previous ? '$start' : '$start–$previous');
      start = section;
    }
    previous = section;
  }
  ranges.add(start == previous ? '$start' : '$start–$previous');
  return ranges.join('、');
}

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
