import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/environment.dart';

/// Published shuttle values only: no live seats, no ticketing.

/// One scheduled departure as printed by the school.
class ShuttleRun {
  const ShuttleRun({
    required this.index,
    required this.time,
    required this.capacity,
  });

  /// Published sequence number ("班次").
  final String index;
  final String time, capacity;

  /// Minutes past midnight, or null when the printed time is not `H:mm`.
  int? get minuteOfDay {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }
}

/// One direction pair under a validity label such as "星期一至星期五".
class ShuttleSection {
  const ShuttleSection({
    required this.label,
    required this.left,
    required this.right,
  });

  final String label;
  final List<ShuttleRun> left, right;

  /// Published validity labels name weekdays rather than dates. Only labels
  /// that can be read unambiguously filter the plan; an unfamiliar label keeps
  /// its runs visible instead of claiming they do not apply.
  bool appliesToday(int weekday) {
    final text = label.replaceAll(' ', '');
    if (text.isEmpty) return true;
    if (text.contains('每天') || text.contains('每日') || text.contains('全年')) {
      return true;
    }
    if (text.contains('双休日') || text.contains('周末')) {
      return weekday >= DateTime.saturday;
    }
    if (text.contains('工作日')) return weekday <= DateTime.friday;
    final range = RegExp(r'星期([一二三四五六日天])(?:至|到|-|—|–|~)星期([一二三四五六日天])')
        .firstMatch(text);
    if (range != null) {
      final from = _weekdayIndex(range.group(1)!);
      final to = _weekdayIndex(range.group(2)!);
      if (from != null && to != null) {
        return from <= to
            ? weekday >= from && weekday <= to
            : weekday >= from || weekday <= to;
      }
    }
    final singles = RegExp(r'星期([一二三四五六日天])')
        .allMatches(text)
        .map((match) => _weekdayIndex(match.group(1)!))
        .whereType<int>()
        .toSet();
    if (singles.isNotEmpty) return singles.contains(weekday);
    return true;
  }

  static int? _weekdayIndex(String value) => switch (value) {
    '一' => DateTime.monday,
    '二' => DateTime.tuesday,
    '三' => DateTime.wednesday,
    '四' => DateTime.thursday,
    '五' => DateTime.friday,
    '六' => DateTime.saturday,
    '日' || '天' => DateTime.sunday,
    _ => null,
  };
}

/// One published table: two directions plus their dated sections.
class ShuttleTable {
  const ShuttleTable({
    required this.left,
    required this.right,
    required this.sections,
  });

  final String left, right;
  final List<ShuttleSection> sections;
}

class ShuttleTimetable {
  const ShuttleTimetable({
    required this.tables,
    required this.source,
    required this.liveSource,
  });

  final List<ShuttleTable> tables;
  final String source, liveSource;

  /// Flattens every published run that applies today. Duplicate rows across
  /// tables (same direction and departure) are collapsed, then sorted by the
  /// Beijing wall clock. Pure projection: no requests, no seat inference.
  List<ShuttleDeparture> todayRuns(DateTime clock) {
    final runs = <ShuttleDeparture>[];
    final seen = <String>{};
    for (final table in tables) {
      final directions = [table.left, table.right];
      for (final section in table.sections) {
        if (!section.appliesToday(clock.weekday)) continue;
        for (var side = 0; side < directions.length; side++) {
          final direction = directions[side];
          if (direction.isEmpty) continue;
          for (final run in side == 0 ? section.left : section.right) {
            final minutes = run.minuteOfDay;
            if (minutes == null) continue;
            if (!seen.add('$direction|$minutes')) continue;
            runs.add(
              ShuttleDeparture(
                direction: direction,
                time: run.time,
                minutes: minutes,
                capacity: run.capacity,
              ),
            );
          }
        }
      }
    }
    runs.sort((a, b) {
      final byTime = a.minutes.compareTo(b.minutes);
      if (byTime != 0) return byTime;
      final byDirection = a.direction.compareTo(b.direction);
      return byDirection != 0 ? byDirection : a.time.compareTo(b.time);
    });
    return runs;
  }
}

/// A today-applicable departure with its direction resolved from the table.
class ShuttleDeparture {
  const ShuttleDeparture({
    required this.direction,
    required this.time,
    required this.minutes,
    required this.capacity,
  });

  final String direction;
  final String time;
  final int minutes;
  final String capacity;
}

class ShuttleTimetableRead {
  const ShuttleTimetableRead({this.data, this.failure});
  final ShuttleTimetable? data;
  final FailureCode? failure;
}

abstract interface class ShuttleGateway implements MirrorEnvironment {
  /// Published shuttle timetable (official page). No live seats, no ticketing.
  Future<ShuttleTimetableRead> shuttleTimetable();
}
