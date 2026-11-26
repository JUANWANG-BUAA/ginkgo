import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:ginkgo_mirror/application/contracts.dart';

const _widgetChannel = MethodChannel('cn.edu.buaa.ginkgo/widget');

/// Pushes the active account's today courses to the Android home-screen widget.
/// Best-effort no-op on non-Android platforms or when no widget is pinned.
Future<void> syncTodayScheduleWidget(TodayResponse value) async {
  if (!Platform.isAndroid || value.failure != null || value.date.isEmpty) {
    return;
  }
  try {
    final payload = jsonEncode({
      'date': value.date,
      'courses': [
        for (final c in value.courses)
          {
            'name': c.name,
            'time': c.time ?? '',
            'place': c.place ?? '',
          },
      ],
    });
    await _widgetChannel.invokeMethod<void>('syncToday', payload);
  } catch (_) {}
}

Future<void> clearScheduleWidget() async {
  if (!Platform.isAndroid) return;
  try {
    await _widgetChannel.invokeMethod<void>('clear');
  } catch (_) {}
}
