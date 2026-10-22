/// CGYY approval labels follow API §6B and the existing CgyyModels.swift mapping.
/// Request acceptance is deliberately not presented as final approval.
String cgyyOrderStatus(Map<String, dynamic> order) {
  final status = order['order_status'];
  final check = order['check_status'];
  if (status == 2) return '已取消';
  if (check is int && check < 0) {
    return switch (check) {
      -2 => '辅导员审批驳回',
      -3 => '副书记／副处长审批驳回',
      -4 => '宣传部审批驳回',
      -5 => '国交处备案驳回',
      -6 => '教务处审批驳回',
      _ => '审批未通过（状态 $check）',
    };
  }
  if (status == 1) {
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
  if (status == 3) return '占用';
  return order['status'] as String? ?? '状态待确认';
}

String cgyyOrderSummary(Map<String, dynamic> order) => [
  '订单 ${order['id']}',
  (order['place'] as String?)?.isNotEmpty == true
      ? order['place'] as String
      : '地点未提供',
  order['date'] as String? ?? '日期未提供',
  order['time'] as String? ?? '时段未提供',
  cgyyOrderStatus(order),
].join('\n');
