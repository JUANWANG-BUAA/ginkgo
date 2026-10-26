/// Rust's execution-report projection. No course/category credit aggregation.
library;

import 'contracts.dart' show FailureCode;

abstract interface class GraduateCreditMapGateway {
  Future<GraduateCreditMapRead> graduateCreditMap({bool forceRefresh = false});
}

class GraduateCreditMapRead {
  const GraduateCreditMapRead({this.data, this.issue, this.stale = false});
  final GraduateCreditMap? data;
  final GraduateCreditReadIssue? issue;
  final bool stale;
}

enum GraduateCreditIssueKind {
  protocolChanged,
  authentication,
  timeout,
  unsupported,
  businessRejected,
  unavailable,
  unknown,
}

/// Classification must be backed by the actual read result, never by missing
/// data or lack of implementation. An untyped transport error stays unknown.
class GraduateCreditReadIssue {
  const GraduateCreditReadIssue(this.kind);
  final GraduateCreditIssueKind kind;

  static GraduateCreditReadIssue? fromFailure(FailureCode? code) =>
      switch (code) {
        null => null,
        FailureCode.changedResponse => const GraduateCreditReadIssue(
          GraduateCreditIssueKind.protocolChanged,
        ),
        FailureCode.sessionExpired ||
        FailureCode.captchaRequired ||
        FailureCode.invalidCredentials ||
        FailureCode.preLoginTip => const GraduateCreditReadIssue(
          GraduateCreditIssueKind.authentication,
        ),
        FailureCode.unsupportedContract || FailureCode.unsupportedPortal =>
          const GraduateCreditReadIssue(GraduateCreditIssueKind.unsupported),
        FailureCode.businessRejected ||
        FailureCode.accessPolicyDenied => const GraduateCreditReadIssue(
          GraduateCreditIssueKind.businessRejected,
        ),
        FailureCode.serviceUnavailable => const GraduateCreditReadIssue(
          GraduateCreditIssueKind.unavailable,
        ),
        _ => const GraduateCreditReadIssue(GraduateCreditIssueKind.unknown),
      };

  String get message => switch (kind) {
    GraduateCreditIssueKind.protocolChanged => '学校执行报告接口返回结构已变化或路径失效，请前往官网核对',
    GraduateCreditIssueKind.authentication => '需要重新登录或完成学校认证后再读取',
    GraduateCreditIssueKind.timeout => '执行报告读取超时，请重试；这不代表接口失效',
    GraduateCreditIssueKind.unsupported => '当前服务不支持学分地图读取，不能据此判断学校接口失效',
    GraduateCreditIssueKind.businessRejected => '学校暂未允许读取执行报告，请前往官网核对',
    GraduateCreditIssueKind.unavailable => '执行报告服务暂不可用，尚不能判断接口是否失效',
    GraduateCreditIssueKind.unknown => '暂未取得可确认的执行报告，失败原因待确认',
  };
}

enum GraduateCreditState { unknown, noMinimum, incomplete, requirementMet }

class GraduateCreditMetrics {
  const GraduateCreditMetrics({
    required this.state,
    this.requiredCredits,
    this.earned,
    this.pending,
    this.remaining,
    this.ratio,
  });
  final GraduateCreditState state;
  final double? requiredCredits, earned, pending, remaining, ratio;

  String get stateLabel => switch (state) {
    GraduateCreditState.unknown => '学分信息不完整',
    GraduateCreditState.noMinimum => '本项无最低学分要求',
    GraduateCreditState.incomplete => '尚有学分缺口',
    GraduateCreditState.requirementMet => '本项学分要求已满足',
  };
}

class GraduateCreditRow {
  const GraduateCreditRow({
    required this.title,
    required this.detail,
    required this.isCourse,
    this.completed,
    this.credit,
    this.semester,
  });
  final String title, detail;
  final bool isCourse;
  final bool? completed;
  final double? credit;
  final String? semester;
}

class GraduateCreditNode {
  GraduateCreditNode({
    required this.sourceIndex,
    required this.title,
    this.progress,
    Iterable<GraduateCreditRow> rows = const [],
  }) : rows = List.unmodifiable(rows);
  final int sourceIndex;
  final String title;
  final GraduateCreditMetrics? progress;
  final List<GraduateCreditRow> rows;
}

class GraduateCreditMap {
  GraduateCreditMap({
    this.summary,
    Iterable<GraduateCreditNode> nodes = const [],
    this.notice,
  }) : nodes = List.unmodifiable(nodes);
  final GraduateCreditNode? summary;
  final List<GraduateCreditNode> nodes;
  final String? notice;
  bool get isEmpty => summary == null && nodes.isEmpty;
}
