import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges Android App Shortcuts, home-screen widget taps, and notification
/// intents (`ginkgo_destination`) into the workspace navigation shell.
class NativeNavigationLinks {
  NativeNavigationLinks._() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'openDestination' && call.arguments is String) {
          final target = (call.arguments as String).trim();
          if (target.isNotEmpty) _controller.add(target);
        }
      });
    }
  }

  static final shared = NativeNavigationLinks._();
  static const _channel = MethodChannel('cn.edu.buaa.ginkgo/navigation');
  final _controller = StreamController<String>.broadcast();

  Stream<String> get destinations => _controller.stream;

  Future<String?> takeInitialDestination() async {
    if (!Platform.isAndroid) return null;
    try {
      final value = await _channel.invokeMethod<String>(
        'takePendingDestination',
      );
      return value != null && value.trim().isNotEmpty ? value.trim() : null;
    } catch (_) {
      return null;
    }
  }
}
