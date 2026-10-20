import 'package:flutter/cupertino.dart';

import 'src/rust/api/mirror.dart';

const weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

Color courseColor(BuildContext context, String? value, [String name = '']) {
  if (value != null) {
    final hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
  }
  const palette = [
    CupertinoColors.systemBlue,
    CupertinoColors.systemTeal,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemOrange,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
    CupertinoColors.systemGreen,
    CupertinoColors.systemRed,
  ];
  var hash = 5381;
  for (final scalar in name.runes) {
    hash = ((hash * 33) + scalar) & 0x7fffffff;
  }
  return palette[hash % palette.length].resolveFrom(context);
}

String courseDetail(ScheduleCourse course) {
  final time = [
    if (course.startTime != null) course.startTime!,
    if (course.endTime != null) course.endTime!,
  ].join('–');
  final sections = '第 ${course.startSection}–${course.endSection} 节';
  final teacher = course.teacher == null ? '' : ' · ${course.teacher}';
  return time.isEmpty ? '$sections$teacher' : '$time · $sections$teacher';
}

String shortDate(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null
      ? date
      : '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}';
}
