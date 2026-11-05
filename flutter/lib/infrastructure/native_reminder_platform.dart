import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:ginkgo_mirror/application/reminder_platform.dart';

class NativeReminderPlatform
    implements ReminderPlatform, ScopedReminderPlatform {
  const NativeReminderPlatform();

  static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');

  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持系统提醒，应用内提示仍可用');
    }
    await channel.invokeMethod<void>('replace', plans);
  }

  @override
  Future<void> synchronize({
    required String owner,
    required bool checkin,
    required bool homework,
    required Set<String> groups,
    required List<Map<String, Object>> plans,
  }) async {
    if (!Platform.isAndroid) return;
    await channel.invokeMethod<void>('synchronize', {
      'owner': owner,
      'checkin': checkin,
      'homework': homework,
      'groups': groups.toList()..sort(),
      'plans': plans,
    });
  }

  @override
  Future<void> clearOwner(String owner) async {
    if (!Platform.isAndroid) return;
    await channel.invokeMethod<void>('clearOwner', owner);
  }
}
