import 'dart:convert';

/// Typed projection of the CGYY payloads serialized by
/// `ginkgo_domain::features::{cgyy, cgyy_booking}`. Pages consume these values
/// only; payload keys and JSON casting never appear in widget code.

class CgyySite {
  CgyySite.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      // The school always sends a venue, but presentation degrades to the
      // name when absent; keep that tolerance here.
      venue = json['venue'] as String? ?? '',
      campus = json['campus'] as String? ?? '',
      seats = json['seats'] as int?;

  final int id;
  final String name, venue, campus;
  final int? seats;
}

class CgyySlot {
  CgyySlot.fromJson(Map<String, dynamic> json)
    : time = json['time'] as String,
      status = json['status'] as String;

  final String time, status;
}

class CgyySpace {
  CgyySpace.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      slots = (json['slots'] as List)
          .cast<Map<String, dynamic>>()
          .map(CgyySlot.fromJson)
          .toList(growable: false);

  final String name;
  final List<CgyySlot> slots;
}

class CgyyDay {
  CgyyDay.fromJson(Map<String, dynamic> json)
    : date = json['date'] as String,
      spaces = (json['spaces'] as List)
          .cast<Map<String, dynamic>>()
          .map(CgyySpace.fromJson)
          .toList(growable: false);

  final String date;
  final List<CgyySpace> spaces;
}

/// Approval labels follow API §6B and the existing CgyyModels.swift mapping.
/// Request acceptance is deliberately not presented as final approval.
class CgyyOrder {
  CgyyOrder.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      place = json['place'] as String,
      date = json['date'] as String,
      time = json['time'] as String,
      status = json['status'] as String,
      orderStatus = json['order_status'] as int?,
      checkStatus = json['check_status'] as int?,
      canCancel = json['can_cancel'] == true;

  final int id;
  final String place, date, time, status;
  // Absent keys mean the school did not disclose them; null is not zero.
  final int? orderStatus, checkStatus;
  final bool canCancel;

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

class CgyyBookingChoice {
  CgyyBookingChoice.fromJson(Map<String, dynamic> json)
    : spaceId = json['space_id'] as int,
      spaceName = json['space_name'] as String,
      timeId = json['time_id'] as int,
      time = json['time'] as String;

  final int spaceId, timeId;
  final String spaceName, time;
}

class CgyyPurpose {
  CgyyPurpose.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String;

  final int id;
  final String name;
}

class CgyyBookingOptions {
  CgyyBookingOptions.fromJson(Map<String, dynamic> json)
    : choices = (json['choices'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CgyyBookingChoice.fromJson)
          .toList(growable: false),
      purposes = (json['purposes'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CgyyPurpose.fromJson)
          .toList(growable: false);

  final List<CgyyBookingChoice> choices;
  final List<CgyyPurpose> purposes;
}

/// Jigsaw challenge images stay raw data URLs; decoding happens in the widget
/// that displays them, never in models.
class CgyyChallenge {
  CgyyChallenge.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      background = json['background'] as String,
      jigsaw = json['jigsaw'] as String;

  final String id, background, jigsaw;
}

class CgyyReviewSnapshot {
  CgyyReviewSnapshot.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      orders = (json['orders'] as List)
          .cast<Map<String, dynamic>>()
          .map(CgyyOrder.fromJson)
          .toList(growable: false);

  final String id;
  final List<CgyyOrder> orders;
}

/// One write-flow result envelope. An unrecognized state stays `unknown`
/// instead of being read as success or failure.
class CgyyActionResult {
  CgyyActionResult._(
    this.state,
    this.message,
    this.options,
    this.challenge,
    this.review,
  );

  CgyyActionResult.fromJson(Map<String, dynamic> json)
    : this._(
        json['state'] as String,
        json['message'] as String? ?? '请核对我的预约',
        json['options'] == null
            ? null
            : CgyyBookingOptions.fromJson(
                json['options'] as Map<String, dynamic>,
              ),
        json['challenge'] == null
            ? null
            : CgyyChallenge.fromJson(json['challenge'] as Map<String, dynamic>),
        json['review'] == null
            ? null
            : CgyyReviewSnapshot.fromJson(
                json['review'] as Map<String, dynamic>,
              ),
      );

  static const knownStates = {
    'accepted',
    'uncertain',
    'rejected',
    'not_submitted',
    'notSubmitted',
  };

  /// A response outside the known vocabulary is preserved as an explicit
  /// uncertain outcome so callers never treat it as success.
  factory CgyyActionResult.fromState(String state, String message) =>
      CgyyActionResult._(state, message, null, null, null);

  final String state, message;
  final CgyyBookingOptions? options;
  final CgyyChallenge? challenge;
  final CgyyReviewSnapshot? review;

  bool get isKnown => knownStates.contains(state);
  bool get requiresReview => state == 'uncertain' || state == 'accepted';
  bool get isChallenge => state == 'challenge';
  bool get isReady => state == 'ready';
  bool get isReviewRequired => state == 'reviewRequired';
}

/// The guard status of the last local write; anything but ready/uncertain
/// keeps the protection on.
class CgyyWriteStatus {
  const CgyyWriteStatus.known(this.reviewRequired) : known = true;
  const CgyyWriteStatus.unknown() : known = false, reviewRequired = true;

  final bool known;
  final bool reviewRequired;
}

CgyyActionResult cgyyActionResult(String payload) =>
    CgyyActionResult.fromJson(jsonDecode(payload) as Map<String, dynamic>);

CgyyWriteStatus cgyyWriteStatus(String payload) {
  final state = (jsonDecode(payload) as Map<String, dynamic>)['state'];
  return switch (state) {
    'ready' => const CgyyWriteStatus.known(false),
    'uncertain' => const CgyyWriteStatus.known(true),
    _ => const CgyyWriteStatus.unknown(),
  };
}

List<CgyySite> cgyySites(String payload) => (jsonDecode(payload) as List)
    .cast<Map<String, dynamic>>()
    .map(CgyySite.fromJson)
    .toList(growable: false);

CgyyDay cgyyDay(String payload) =>
    CgyyDay.fromJson(jsonDecode(payload) as Map<String, dynamic>);

List<CgyyOrder> cgyyOrders(String payload) => (jsonDecode(payload) as List)
    .cast<Map<String, dynamic>>()
    .map(CgyyOrder.fromJson)
    .toList(growable: false);
