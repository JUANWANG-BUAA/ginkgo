import 'dart:convert';
import 'dart:typed_data';

import 'package:ginkgo_mirror/application/contracts.dart';

/// Exports the currently loaded week schedule as a standard RFC 5545 `.ics`
/// calendar file (Asia/Shanghai) for one-tap import into system calendars.
Uint8List buildScheduleIcsBytes(ScheduleResponse data) =>
    Uint8List.fromList(utf8.encode(buildScheduleIcs(data)));

String scheduleIcsFileName(ScheduleResponse data) {
  final term = data.termId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  final prefix = term.isEmpty ? 'ginkgo' : 'ginkgo-$term';
  return '$prefix-week${data.weekNumber}.ics';
}

String buildScheduleIcs(ScheduleResponse data) {
  final week = data.weeks.cast<ScheduleWeek?>().firstWhere(
    (w) => w!.number == data.weekNumber,
    orElse: () => null,
  );
  final weekStart = DateTime.tryParse(week?.startDate ?? '');
  final buf = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\n')
    ..write('VERSION:2.0\r\n')
    ..write('PRODID:-//Ginkgo//BUAA Schedule//ZH\r\n')
    ..write('CALSCALE:GREGORIAN\r\n')
    ..write('X-WR-CALNAME:Ginkgo 第${data.weekNumber}周课表\r\n')
    ..write('X-WR-TIMEZONE:Asia/Shanghai\r\n');

  if (weekStart != null) {
    for (final course in data.courses) {
      final dayOffset = (course.day - 1).clamp(0, 6);
      final date = weekStart.add(Duration(days: dayOffset));
      final start = _parseClock(course.startTime) ?? _sectionStart(course.startSection);
      final end = _parseClock(course.endTime) ?? _sectionEnd(course.endSection);
      final dtStart = _formatIcsLocal(date, start.$1, start.$2);
      final dtEnd = _formatIcsLocal(date, end.$1, end.$2);
      final uid = 'ginkgo-${data.termId}-w${data.weekNumber}-${course.id}@buaa';
      final descParts = [
        if (course.teacher?.trim().isNotEmpty == true) '教师：${course.teacher!.trim()}',
        '第 ${course.startSection}–${course.endSection} 节 · 第 ${data.weekNumber} 周',
      ];
      buf
        ..write('BEGIN:VEVENT\r\n')
        ..write('UID:${_escapeIcs(uid)}\r\n')
        ..write('DTSTART;TZID=Asia/Shanghai:$dtStart\r\n')
        ..write('DTEND;TZID=Asia/Shanghai:$dtEnd\r\n')
        ..write('SUMMARY:${_escapeIcs(course.name)}\r\n');
      if (course.place?.trim().isNotEmpty == true) {
        buf.write('LOCATION:${_escapeIcs(course.place!.trim())}\r\n');
      }
      buf
        ..write('DESCRIPTION:${_escapeIcs(descParts.join(' | '))}\r\n')
        ..write('END:VEVENT\r\n');
    }
  }
  buf.write('END:VCALENDAR\r\n');
  return buf.toString();
}

(int, int)? _parseClock(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return null;
  final h = int.tryParse(match.group(1)!);
  final m = int.tryParse(match.group(2)!);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return (h, m);
}

(int, int) _sectionStart(int section) => switch (section) {
  1 => (8, 0),
  2 => (8, 50),
  3 => (9, 50),
  4 => (10, 40),
  5 => (11, 30),
  6 => (14, 0),
  7 => (14, 50),
  8 => (15, 50),
  9 => (16, 40),
  10 => (17, 30),
  11 => (19, 0),
  12 => (19, 50),
  13 => (20, 40),
  _ => (21, 30),
};

(int, int) _sectionEnd(int section) {
  final (h, m) = _sectionStart(section);
  final total = h * 60 + m + 45;
  return (total ~/ 60, total % 60);
}

String _formatIcsLocal(DateTime date, int hour, int minute) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}'
    'T${hour.toString().padLeft(2, '0')}'
    '${minute.toString().padLeft(2, '0')}00';

String _escapeIcs(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r', '')
    .replaceAll('\n', r'\n');
