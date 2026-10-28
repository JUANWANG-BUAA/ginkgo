import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:ginkgo_mirror/application/reminder_platform.dart';

class NativeReminderPlatform implements ReminderPlatform {
  const NativeReminderPlatform();

  static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');

  @override
  Future<void> replace(List<Map<String, Object>> plans) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持系统提醒，应用内提示仍可用');
    }
    await channel.invokeMethod<void>('replace', plans);
  }
}
