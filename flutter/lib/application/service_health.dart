import 'package:flutter/foundation.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show FailureCode;

enum ServiceEndpointId {
  today('今日课表', 'BYXT / GSMIS'),
  schedule('周课表与考试', 'BYXT / GSMIS'),
  grades('成绩查询', 'buaascore'),
  homework('SPOC 作业', 'SPOC'),
  learning('SPOC 学习', 'SPOC'),
  checkin('iClass 签到', 'iClass'),
  bykc('博雅课程', 'BYKC'),
  graduate('研究生教务', 'GSMIS'),
  libraryVenues('图书馆选座', 'booking.lib'),
  libraryLoans('本人借阅', 'OPAC'),
  classroom('空教室查询', '空教室系统'),
  cgyy('教学楼研讨室', 'CGYY'),
  campusCard('校园卡余额', '航财通'),
  finance('财务收入查询', '财务查询系统'),
  networkAccount('网费与门户指标', '门户 / 网络自助'),
  teachingEvaluation('课程评教状态', 'SPOC 评教'),
  notices('校园通知', '北航新闻网', isPublic: true),
  libraryStats('图书馆实时人数', '图书馆官网', isPublic: true),
  libraryBooks('公开书目检索', 'OPAC 公开', isPublic: true),
  careerEvents('就业宣讲月历', '北航就业网', isPublic: true),
  campusActivities('学术文化活动', '北航官网', isPublic: true),
  shuttle('校车时刻表', '北航官网', isPublic: true);

  const ServiceEndpointId(this.title, this.system, {this.isPublic = false});

  final String title;
  final String system;
  final bool isPublic;
}

enum EndpointHealthState {
  idle,
  loading,
  healthy,
  cached,
  stale,
  authRequired,
  unavailable,
}

class EndpointHealthSnapshot {
  const EndpointHealthSnapshot({
    required this.endpoint,
    this.state = EndpointHealthState.idle,
    this.latencyMs,
    this.failure,
    this.updatedAt,
    this.inFlight = 0,
  });

  final ServiceEndpointId endpoint;
  final EndpointHealthState state;
  final int? latencyMs;
  final FailureCode? failure;
  final DateTime? updatedAt;
  final int inFlight;

  bool get isHealthy =>
      state == EndpointHealthState.healthy ||
      state == EndpointHealthState.cached;

  bool get hasIssue =>
      state == EndpointHealthState.stale ||
      state == EndpointHealthState.authRequired ||
      state == EndpointHealthState.unavailable;
}

/// Passive, privacy-preserving in-memory telemetry of upstream endpoint status.
///
/// Records only coarse stage, latency, cache hit and [FailureCode]. Never
/// retains response bodies, URLs or account identifiers, and resets on sign-out.
class ServiceHealthTracker extends ChangeNotifier {
  ServiceHealthTracker({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final shared = ServiceHealthTracker();

  final DateTime Function() _clock;
  int _epoch = 0;
  final Map<ServiceEndpointId, EndpointHealthSnapshot> _entries = {
    for (final id in ServiceEndpointId.values)
      id: EndpointHealthSnapshot(endpoint: id),
  };

  EndpointHealthSnapshot snapshotOf(ServiceEndpointId id) =>
      _entries[id] ?? EndpointHealthSnapshot(endpoint: id);

  List<EndpointHealthSnapshot> get snapshots => [
    for (final id in ServiceEndpointId.values) snapshotOf(id),
  ];

  List<EndpointHealthSnapshot> get loadingSnapshots => [
    for (final entry in snapshots)
      if (entry.inFlight > 0 || entry.state == EndpointHealthState.loading)
        entry,
  ];

  int get loadingCount => loadingSnapshots.length;

  int get healthyCount => snapshots.where((entry) => entry.isHealthy).length;

  int get degradedCount => snapshots.where((entry) => entry.hasIssue).length;

  bool get hasSessionExpired =>
      snapshots.any((entry) => entry.failure == FailureCode.sessionExpired);

  int get observedCount => snapshots
      .where((entry) => entry.state != EndpointHealthState.idle)
      .length;

  DateTime? get lastUpdatedAt {
    DateTime? latest;
    for (final entry in snapshots) {
      final at = entry.updatedAt;
      if (at != null && (latest == null || at.isAfter(latest))) {
        latest = at;
      }
    }
    return latest;
  }

  void clear() {
    _epoch++;
    for (final id in ServiceEndpointId.values) {
      _entries[id] = EndpointHealthSnapshot(endpoint: id);
    }
    notifyListeners();
  }

  Future<T> observe<T>(
    ServiceEndpointId id,
    Future<T> Function() action, {
    FailureCode? Function(T)? failureOf,
    bool Function(T)? staleOf,
    bool Function(T)? cachedOf,
  }) async {
    final epoch = _epoch;
    final previous = snapshotOf(id);
    _entries[id] = EndpointHealthSnapshot(
      endpoint: id,
      state: previous.state == EndpointHealthState.idle
          ? EndpointHealthState.loading
          : previous.state,
      latencyMs: previous.latencyMs,
      failure: previous.failure,
      updatedAt: previous.updatedAt,
      inFlight: previous.inFlight + 1,
    );
    notifyListeners();
    final watch = Stopwatch()..start();
    try {
      final result = await action();
      watch.stop();
      if (epoch == _epoch) {
        final current = snapshotOf(id);
        final nextInFlight = current.inFlight > 0 ? current.inFlight - 1 : 0;
        final failure = failureOf?.call(result);
        final stale = staleOf?.call(result) ?? false;
        final cached = cachedOf?.call(result) ?? false;
        final state = _classify(failure: failure, stale: stale, cached: cached);
        _entries[id] = EndpointHealthSnapshot(
          endpoint: id,
          state: state,
          latencyMs: watch.elapsedMilliseconds,
          failure: failure,
          updatedAt: _clock(),
          inFlight: nextInFlight,
        );
        notifyListeners();
      }
      return result;
    } catch (_) {
      watch.stop();
      if (epoch == _epoch) {
        final current = snapshotOf(id);
        final nextInFlight = current.inFlight > 0 ? current.inFlight - 1 : 0;
        _entries[id] = EndpointHealthSnapshot(
          endpoint: id,
          state: EndpointHealthState.unavailable,
          latencyMs: watch.elapsedMilliseconds,
          failure: FailureCode.serviceUnavailable,
          updatedAt: _clock(),
          inFlight: nextInFlight,
        );
        notifyListeners();
      }
      rethrow;
    }
  }

  static EndpointHealthState _classify({
    required FailureCode? failure,
    required bool stale,
    required bool cached,
  }) {
    if (failure == null) {
      return cached ? EndpointHealthState.cached : EndpointHealthState.healthy;
    }
    if (stale) return EndpointHealthState.stale;
    return switch (failure) {
      FailureCode.sessionExpired ||
      FailureCode.moduleAuthRequired ||
      FailureCode.captchaRequired ||
      FailureCode.invalidCredentials ||
      FailureCode.preLoginTip => EndpointHealthState.authRequired,
      _ => EndpointHealthState.unavailable,
    };
  }
}
