import 'dart:math' as math;

import 'package:ginkgo_mirror/application/contracts.dart';

/// Width of the fixed section axis on the left of the grid.
const double scheduleGridAxisWidth = 38;

/// Height of the weekday + circular-date header row.
const double scheduleGridHeaderHeight = 54;

/// Default minimum teaching sections drawn on the vertical axis.
const int scheduleGridMinSections = 12;

/// Maximum teaching sections supported by BUAA timetables.
const int scheduleGridSectionCount = 14;

/// Height of one section row.
const double scheduleGridCellHeight = 52;

/// Standard BUAA bell-schedule start times used when the upstream portal omits
/// slot metadata on empty sections.
const Map<int, String> defaultBuaaSectionTimes = {
  1: '08:00',
  2: '08:50',
  3: '09:50',
  4: '10:45',
  5: '11:40',
  6: '14:00',
  7: '14:55',
  8: '15:55',
  9: '16:50',
  10: '19:00',
  11: '19:55',
  12: '20:50',
  13: '21:40',
  14: '22:30',
};

/// Where each course sits inside its day column, plus the section times.
///
/// Conflicting sections (the same section number carrying different clock
/// times) keep a neutral axis: each block shows its own time instead.
class ScheduleGridLayout {
  const ScheduleGridLayout({
    required this.placements,
    required this.times,
    required this.sectionCount,
  });

  /// Lane index and lane count per course id.
  final Map<String, ({int lane, int count})> placements;

  /// Start time per section, falling back to standard BUAA bell times unless
  /// conflicting schemes are present on the same section.
  final Map<int, String> times;

  /// Visible section rows (at least 12, expanding to 14 when evening classes
  /// reach section 13/14).
  final int sectionCount;

  /// Lays courses out day by day, using lanes for overlapping courses.
  factory ScheduleGridLayout.of(List<ScheduleCourse> courses) {
    final placements = <String, ({int lane, int count})>{};
    final observed = <int, String>{};
    final conflicts = <int>{};
    var maxEnd = scheduleGridMinSections;
    for (final course in courses) {
      if (course.endSection > maxEnd) {
        maxEnd = math.min(scheduleGridSectionCount, course.endSection);
      }
      final time = course.startTime;
      if (time == null) continue;
      if (observed.containsKey(course.startSection) &&
          observed[course.startSection] != time) {
        conflicts.add(course.startSection);
      }
      observed[course.startSection] = time;
    }
    final times = <int, String>{
      for (var s = 1; s <= maxEnd; s++)
        if (!conflicts.contains(s))
          s: observed[s] ?? defaultBuaaSectionTimes[s] ?? '',
    }..removeWhere((_, v) => v.isEmpty);

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
    return ScheduleGridLayout(
      placements: placements,
      times: times,
      sectionCount: maxEnd,
    );
  }
}
