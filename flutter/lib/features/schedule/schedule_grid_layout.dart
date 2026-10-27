import 'dart:math' as math;

import 'package:ginkgo_mirror/application/contracts.dart';

/// Width of the fixed section axis on the left of the grid.
const double scheduleGridAxisWidth = 60;

/// Height of the weekday header row.
const double scheduleGridHeaderHeight = 58;

/// Number of teaching sections drawn on the vertical axis.
const int scheduleGridSectionCount = 14;

/// Height of one section row.
const double scheduleGridCellHeight = 58;

/// Where each course sits inside its day column, plus the section times.
///
/// Conflicting sections (the same section number carrying different clock
/// times) keep a neutral axis: each block shows its own time instead.
class ScheduleGridLayout {
  const ScheduleGridLayout({required this.placements, required this.times});

  /// Lane index and lane count per course id.
  final Map<String, ({int lane, int count})> placements;

  /// Start time per section, absent where schemes disagree.
  final Map<int, String> times;

  /// Lays courses out day by day, using lanes for overlapping courses.
  factory ScheduleGridLayout.of(List<ScheduleCourse> courses) {
    final placements = <String, ({int lane, int count})>{};
    final times = <int, String>{};
    final conflicts = <int>{};
    for (final course in courses) {
      final time = course.startTime;
      if (time == null) continue;
      if (times.containsKey(course.startSection) &&
          times[course.startSection] != time) {
        conflicts.add(course.startSection);
      }
      times[course.startSection] = time;
    }
    // Different schemes may share section numbers with different clock times.
    // Keep the section axis neutral in that case; each block shows its own time.
    for (final section in conflicts) {
      times.remove(section);
    }
    // Same interval grouping as macOS TimetableLayout: conflicts use lanes.
    for (var day = 1; day <= 7; day++) {
      final ordered = courses.where((c) => c.day == day).toList()
        ..sort((a, b) {
          final n = a.startSection.compareTo(b.startSection);
          return n == 0 ? a.id.compareTo(b.id) : n;
        });
      var group = <ScheduleCourse>[];
      var end = 0;
      void commit() {
        final laneEnds = <int>[];
        final lanes = <String, int>{};
        for (final course in group) {
          var lane = laneEnds.indexWhere((end) => end < course.startSection);
          if (lane < 0) {
            lane = laneEnds.length;
            laneEnds.add(course.endSection);
          } else {
            laneEnds[lane] = course.endSection;
          }
          lanes[course.id] = lane;
        }
        for (final course in group) {
          placements[course.id] = (
            lane: lanes[course.id]!,
            count: laneEnds.length,
          );
        }
      }

      for (final course in ordered) {
        if (group.isNotEmpty && course.startSection > end) {
          commit();
          group = [];
          end = 0;
        }
        group.add(course);
        end = math.max(end, course.endSection);
      }
      commit();
    }
    return ScheduleGridLayout(placements: placements, times: times);
  }
}
