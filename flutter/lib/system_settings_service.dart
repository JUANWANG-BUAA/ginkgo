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

class NativeSystemSettingsService implements SystemSettingsService {
  const NativeSystemSettingsService();
  static const channel = MethodChannel('cn.edu.buaa.ginkgo/system');
  @override
  bool get isAndroid => Platform.isAndroid;
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
