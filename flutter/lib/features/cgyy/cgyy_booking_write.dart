/// Write-flow primitives of the CGYY booking draft.
///
/// A booking write has two observable outcomes: the draft request failed
/// before the school created anything, or the school accepted a draft that
/// still needs a manual jigsaw check. Both are modelled here so the page
/// never has to invent its own envelope.
library;

/// The booking command failed before a draft existed.
///
/// Both failure paths of the booking page handle every failure the same way,
/// so the type only marks that the school never received a draft. The typed
/// school failure is recorded in the diagnostic log at the throw site.
class CgyyBookingFailure implements Exception {
  const CgyyBookingFailure();
}

/// The booking form values as one snapshot.
///
/// The page owns the form state; this snapshot is what the school receives
/// and what the confirmation shows. Building it never fails: values that are
/// still missing stay empty so the page can report what is incomplete.
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

  /// Whether the draft carries everything the school requires: one venue,
  /// one to twelve slots, a known purpose, and every text field filled.
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

  /// The confirmation text shared by the dialog and the captcha page.
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

  /// The draft request the school receives.
  Map<String, Object?> get payload => {
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
