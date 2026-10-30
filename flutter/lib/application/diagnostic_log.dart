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
    'invalidCredentials' ||
    'captchaRequired' => '回到账号页重新登录；请勿分享密码、验证码或 Cookie。',
    'changedResponse' ||
    'unsupportedContract' => '先保留当前结果并更新应用；反馈时附下方诊断编号，无需上传学校原始响应。',
    'accessPolicyDenied' => '检查校园网 / 北航 VPN 和上游连接路线后再刷新。',
    'businessRejected' => '只刷新查询状态；预约和签到结果未确认时不要再次提交。',
    'moduleAuthRequired' => '只重试该功能；账号会话仍然有效，不需要重新登录。',
    _ => '检查网络后重试只读查询；写操作超时请先回查，勿重复提交。',
  };
  String get summary => '${at.toUtc().toIso8601String()} code=$code';
}

class DiagnosticLog extends ChangeNotifier {
  static final shared = DiagnosticLog();
  final List<DiagnosticEntry> entries = [];
  DiagnosticEntry? current;
  void record(FailureCode? failure) {
    final code = failure?.name ?? 'localService';
    final now = DateTime.now();
    if (entries.isNotEmpty &&
        entries.last.code == code &&
        now.difference(entries.last.at).inSeconds < 60) {
      return;
    }
    final entry = DiagnosticEntry(code, now);
    entries.add(entry);
    if (entries.length > 50) entries.removeAt(0);
    current = entry;
    // Callers can map failures while building; never notify mid-build.
    scheduleMicrotask(notifyListeners);
  }

  void dismiss() {
    current = null;
    notifyListeners();
  }
}
