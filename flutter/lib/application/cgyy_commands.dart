/// Typed commands for the CGYY write boundary. JSON is produced only by the
/// native adapter after account and storage metadata are added.
sealed class CgyyCommand {
  const CgyyCommand();

  Map<String, Object?> toPayload();
}

final class CgyyStatusCommand extends CgyyCommand {
  const CgyyStatusCommand();

  @override
  Map<String, Object?> toPayload() => {'action': 'status'};
}

final class CgyyOptionsCommand extends CgyyCommand {
  const CgyyOptionsCommand({required this.siteId, required this.date});

  final int siteId;
  final String date;

  @override
  Map<String, Object?> toPayload() => {
    'action': 'options',
    'site_id': siteId,
    'date': date,
  };
}

final class CgyyPrepareCommand extends CgyyCommand {
  const CgyyPrepareCommand(this.draft);

  final CgyyBookingDraft draft;

  @override
  Map<String, Object?> toPayload() => {
    'action': 'prepare',
    'booking': draft.toPayload(),
  };
}

final class CgyySubmitCommand extends CgyyCommand {
  const CgyySubmitCommand({
    required this.challengeId,
    required this.x,
    required this.width,
  });

  final String challengeId;
  final double x, width;

  @override
  Map<String, Object?> toPayload() => {
    'action': 'submit',
    'challenge_id': challengeId,
    'x': x,
    'width': width,
  };
}

final class CgyyCancelCommand extends CgyyCommand {
  const CgyyCancelCommand(this.orderId);

  final int orderId;

  @override
  Map<String, Object?> toPayload() => {'action': 'cancel', 'order_id': orderId};
}

final class CgyyReviewCommand extends CgyyCommand {
  const CgyyReviewCommand();

  @override
  Map<String, Object?> toPayload() => {'action': 'review'};
}

final class CgyyAcknowledgeCommand extends CgyyCommand {
  const CgyyAcknowledgeCommand(this.reviewId);

  final String reviewId;

  @override
  Map<String, Object?> toPayload() => {
    'action': 'acknowledge',
    'review_id': reviewId,
  };
}

/// The booking form values as one snapshot. Missing values stay empty so the
/// page can report incomplete input without sending it to the school.
class CgyyBookingDraft {
  const CgyyBookingDraft({
    required this.siteId,
    required this.siteName,
    required this.date,
    required this.spaceId,
    required this.spaceName,
    required this.timeIds,
    required this.times,
    required this.participantCount,
    required this.purposeId,
    required this.purposeName,
    required this.phone,
    required this.theme,
    required this.content,
    required this.joiners,
    required this.philosophy,
    required this.offSchool,
  });

  final int siteId, spaceId;
  final String siteName, date, spaceName;
  final List<int> timeIds;
  final List<String> times;
  final String participantCount, purposeName, phone, theme, content, joiners;
  final int purposeId;
  final bool philosophy, offSchool;

  bool get isComplete =>
      siteId > 0 &&
      spaceId > 0 &&
      purposeId > 0 &&
      purposeName.isNotEmpty &&
      timeIds.isNotEmpty &&
      timeIds.length <= 12 &&
      timeIds.length == times.length &&
      timeIds.every((id) => id > 0) &&
      RegExp(r'^\d{11}$').hasMatch(phone) &&
      (int.tryParse(participantCount) ?? 0) >= 1 &&
      (int.tryParse(participantCount) ?? 101) <= 100 &&
      [theme, content, joiners].every((value) => value.trim().isNotEmpty);

  String get summary => [
    '场馆：$siteName',
    '日期：$date',
    '空间：$spaceName',
    '时段：${times.join('、')}',
    '人数：$participantCount 人',
    '用途：$purposeName',
    '手机：$phone',
    '主题：$theme',
    '内容：$content',
    '参与人：$joiners',
    '哲学社会科学类：${philosophy ? '是' : '否'}',
    '含校外参与人：${offSchool ? '是' : '否'}',
  ].join('\n');

  Map<String, Object?> toPayload() => {
    'site_id': siteId,
    'date': date,
    'space_id': spaceId,
    'time_ids': timeIds,
    'phone': phone,
    'theme': theme,
    'purpose_type': purposeId,
    'joiner_num': int.parse(participantCount),
    'activity_content': content,
    'joiners': joiners,
    'philosophy': philosophy,
    'off_school': offSchool,
  };
}
