import 'package:ginkgo_mirror/application/cgyy_models.dart';

export 'package:ginkgo_mirror/application/cgyy_models.dart';

/// Approval labels follow API §6B. Acceptance is not final approval.
extension CgyyOrderPresentation on CgyyOrder {
  String get statusLabel {
    final check = checkStatus;
    if (orderStatus == 2) return '已取消';
    if (check != null && check < 0) {
      return switch (check) {
        -2 => '辅导员审批驳回',
        -3 => '副书记／副处长审批驳回',
        -4 => '宣传部审批驳回',
        -5 => '国交处备案驳回',
        -6 => '教务处审批驳回',
        _ => '审批未通过（状态 $check）',
      };
    }
    if (orderStatus == 1) {
      return switch (check) {
        1 => '审批通过',
        2 => '待辅导员审批',
        3 => '待副书记／副处长审批',
        4 => '待宣传部审批',
        5 => '待国交处备案',
        6 => '待教务处审批',
        0 => '预约已受理',
        null => '预约已受理 · 审批状态未提供',
        _ => '审批状态待确认（$check）',
      };
    }
    if (orderStatus == 3) return '占用';
    return status;
  }

  String get summary => [
    '订单 $id',
    place.isNotEmpty ? place : '地点未提供',
    date,
    time,
    statusLabel,
  ].join('\n');
}

extension CgyyLockCodePresentation on CgyyLockCode {
  String get location => [
    venueName,
    siteName,
    spaceName,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}
