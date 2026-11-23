import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show FailureCode;

/// Allowlisted diagnostics only: no exception text, URLs, account or payloads.
class DiagnosticEntry {
  const DiagnosticEntry(this.code, this.at);
  final String code;
  final DateTime at;
  String get hint => switch (code) {
    'sessionExpired' ||
    'invalidCredentials' => '若学校要求重新登录，请在账号页完成；请勿分享密码、验证码或 Cookie。',
    'captchaRequired' => '按页面提示完成验证。已登录时，网关验证码可在设置中的「WebVPN 验证」处理。',
    'changedResponse' ||
    'unsupportedContract' => '先保留当前结果并更新应用；反馈时附下方诊断编号，无需上传学校原始响应。',
    'accessPolicyDenied' => '检查校园网 / 北航 VPN 和上游连接路线后再刷新。',
    'businessRejected' => '只刷新查询状态；预约和签到结果未确认时不要再次提交。',
    'moduleAuthRequired' => '先重试当前功能；若仍失败，可在设置查看最近确认的路线。不必先退出账号。',
    _ => '检查网络后重试只读查询；写操作超时请先回查，勿重复提交。',
  };
  String get summary => '${at.toUtc().toIso8601String()} code=$code';
}

class DiagnosticLog extends ChangeNotifier {
  static final shared = DiagnosticLog();
  final List<DiagnosticEntry> entries = [];
  DiagnosticEntry? current;
  void record(FailureCode? failure, {bool showHint = true}) {
    final code = failure?.name ?? 'localService';
    final now = DateTime.now();
    if (entries.isNotEmpty &&
        entries.last.code == code &&
        now.difference(entries.last.at).inSeconds < 60) {
      if (showHint) {
        current = entries.last;
        scheduleMicrotask(notifyListeners);
      }
      return;
    }
    final entry = DiagnosticEntry(code, now);
    entries.add(entry);
    if (entries.length > 50) entries.removeAt(0);
    if (showHint) {
      current = entry;
      // Callers can map failures while building; never notify mid-build.
      scheduleMicrotask(notifyListeners);
    }
  }

  void dismiss() {
    current = null;
    notifyListeners();
  }
}
