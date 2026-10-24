import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';

/// Polls local progress only; never sends another authentication/read request.
class CheckInLoading extends StatefulWidget {
  const CheckInLoading({
    super.key,
    required this.isDemo,
    required this.service,
  });
  final bool isDemo;
  final CheckInGateway service;
  @override
  State<CheckInLoading> createState() => _CheckInLoadingState();
}

class _CheckInLoadingState extends State<CheckInLoading> {
  Timer? timer;
  bool reading = false;
  String label = '正在读取 iClass 课程…';
  int seconds = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.isDemo) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) => read());
    }
  }

  Future<void> read() async {
    if (reading) return;
    reading = true;
    try {
      final response = await widget.service.checkinProgress();
      if (!mounted || response.payload == null) return;
      final json = jsonDecode(response.payload!) as Map<String, dynamic>;
      setState(() {
        label = switch (json['phase']) {
          'authenticating' => '正在连接学校认证…',
          'appLogin' => '正在建立 iClass 会话…',
          'courses' => '正在读取当天课程…',
          _ => '正在读取 iClass 课程…',
        };
        seconds = ((json['elapsedMs'] as num? ?? 0) / 1000).floor();
      });
    } catch (_) {
      // Optional local telemetry must not interrupt the actual request.
    } finally {
      reading = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppleSection(
    footer: const Text('首次连接需要建立学校和 iClass 会话，后续读取会复用有效会话。'),
    children: [
      GinkgoLoadingView(
        label: label,
        detail: seconds > 0 ? '已等待 $seconds 秒' : null,
        compact: true,
      ),
    ],
  );
}
