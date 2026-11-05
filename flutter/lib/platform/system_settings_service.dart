import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class SystemSettingsService {
  bool get isAndroid;
  Future<String> notificationPermission();
  Future<String> requestNotifications();
  Future<bool> openNotifications();
  Future<bool> openAppSettings();
  Future<bool> shareProject();
}

class BackgroundReminderStatus {
  const BackgroundReminderStatus({
    required this.enabled,
    required this.scheduled,
    required this.status,
    this.lastRun,
  });
  final bool enabled, scheduled;
  final String status;
  final DateTime? lastRun;
}

abstract interface class BackgroundReminderStatusService {
  Future<BackgroundReminderStatus> backgroundReminderStatus();
}

class NativeSystemSettingsService
    implements SystemSettingsService, BackgroundReminderStatusService {
  const NativeSystemSettingsService();
  static const channel = MethodChannel('cn.edu.buaa.ginkgo/system');
  @override
  bool get isAndroid => Platform.isAndroid;
  @override
  Future<BackgroundReminderStatus> backgroundReminderStatus() async {
    if (!isAndroid) {
      return const BackgroundReminderStatus(
        enabled: false,
        scheduled: false,
        status: 'unsupported',
      );
    }
    final value = await const MethodChannel('cn.edu.buaa.ginkgo/reminders')
        .invokeMapMethod<String, Object?>('backgroundSummary');
    final millis = value?['lastRun'];
    return BackgroundReminderStatus(
      enabled: value?['enabled'] == true,
      scheduled: value?['scheduled'] == true,
      status: value?['status'] as String? ?? 'pending',
      lastRun: millis is int && millis > 0
          ? DateTime.fromMillisecondsSinceEpoch(millis)
          : null,
    );
  }

  @override
  Future<String> notificationPermission() async => isAndroid
      ? await channel.invokeMethod<String>('notificationPermission') ??
            'unknown'
      : 'unsupported';
  @override
  Future<String> requestNotifications() async => isAndroid
      ? await channel.invokeMethod<String>('requestNotifications') ?? 'unknown'
      : 'unsupported';
  @override
  Future<bool> openNotifications() async => isAndroid
      ? await channel.invokeMethod<bool>('openNotifications') ?? false
      : Platform.isWindows &&
            await launchUrl(Uri.parse('ms-settings:notifications'));
  @override
  Future<bool> openAppSettings() async => isAndroid
      ? await channel.invokeMethod<bool>('openAppSettings') ?? false
      : Platform.isWindows &&
            await launchUrl(Uri.parse('ms-settings:startupapps'));
  @override
  Future<bool> shareProject() async {
    if (isAndroid) {
      return await channel.invokeMethod<bool>('shareProject') ?? false;
    }
    await Clipboard.setData(
      const ClipboardData(text: 'https://juanwang-buaa.github.io/ginkgo/'),
    );
    return true;
  }
}
