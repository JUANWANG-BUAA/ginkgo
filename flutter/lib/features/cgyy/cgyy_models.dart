import 'package:ginkgo_mirror/application/contracts.dart';

/// Typed CGYY presentation values projected from the bridge DTOs. Pages
/// consume these values only; payload keys and JSON casting never appear in
/// widget code.

class CgyySite {
  const CgyySite({
    required this.id,
    required this.name,
    this.venue = '',
    this.campus = '',
    this.seats,
  });

  final int id;
  final String name, venue, campus;
  final int? seats;
}

class CgyySlot {
  const CgyySlot({required this.time, required this.status});

  final String time, status;
}

class CgyySpace {
  const CgyySpace({required this.name, required this.slots});

  final String name;
  final List<CgyySlot> slots;
}

class CgyyDay {
  const CgyyDay({required this.date, required this.spaces});

  final String date;
  final List<CgyySpace> spaces;
}

/// Approval labels follow API §6B and the existing CgyyModels.swift mapping.
/// Request acceptance is deliberately not presented as final approval.
class CgyyOrder {
  const CgyyOrder({
    required this.id,
    required this.place,
    required this.date,
    required this.time,
    required this.status,
    this.orderStatus,
    this.checkStatus,
    this.canCancel = false,
  });

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
  const CgyyBookingChoice({
    required this.spaceId,
    required this.spaceName,
    required this.timeId,
    required this.time,
  });

  final int spaceId, timeId;
  final String spaceName, time;
}

class CgyyPurpose {
  const CgyyPurpose({required this.id, required this.name});

  final int id;
  final String name;
}

class CgyyBookingOptions {
  const CgyyBookingOptions({
    required this.choices,
    required this.purposes,
    required this.usesFallbackPurposes,
  });

  final List<CgyyBookingChoice> choices;
  final List<CgyyPurpose> purposes;
  final bool usesFallbackPurposes;
}

/// Jigsaw challenge images stay raw data URLs; decoding happens in the widget
/// that displays them, never in models.
class CgyyChallenge {
  const CgyyChallenge({
    required this.id,
    required this.background,
    required this.jigsaw,
  });

  final String id, background, jigsaw;
}

class CgyyReviewSnapshot {
  const CgyyReviewSnapshot({required this.id, required this.orders});

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

  /// The decoder's entry point; an absent message keeps the house wording.
  factory CgyyActionResult.of({
    required String state,
    String? message,
    CgyyBookingOptions? options,
    CgyyChallenge? challenge,
    CgyyReviewSnapshot? review,
  }) => CgyyActionResult._(
    state,
    message ?? '请核对我的预约',
    options,
    challenge,
    review,
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

  /// A state outside ready/uncertain keeps the protection on.
  factory CgyyWriteStatus.fromState(String state) => switch (state) {
    'ready' => const CgyyWriteStatus.known(false),
    'uncertain' => const CgyyWriteStatus.known(true),
    _ => const CgyyWriteStatus.unknown(),
  };

  final bool known;
  final bool reviewRequired;
}

class CgyyLockCode {
  const CgyyLockCode({
    this.qrCode,
    this.dueDate,
    this.tradeNo,
    this.venueName,
    this.siteName,
    this.spaceName,
    this.orderName,
    this.reservationDate,
    this.reservationDateDetail,
    this.reservationStartDate,
    this.reservationEndDate,
  });

  final String? qrCode, dueDate, tradeNo;
  final String? venueName, siteName, spaceName, orderName;
  final String? reservationDate,
      reservationDateDetail,
      reservationStartDate,
      reservationEndDate;

  bool get hasPassword =>
      qrCode != null && qrCode!.isNotEmpty && qrCode != 'null';
  bool get hasUpcomingReservation => [
    tradeNo,
    reservationDate,
    reservationStartDate,
  ].any((value) => value != null && value.isNotEmpty && value != 'null');

  String get location => [
    venueName,
    siteName,
    spaceName,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}

/// One CGYY read: exactly one shape is non-null, mirroring the Rust union.
class CgyyLoadRead {
  const CgyyLoadRead({
    this.sites,
    this.day,
    this.orders,
    this.order,
    this.lockCode,
    this.failure,
  });

  final List<CgyySite>? sites;
  final CgyyDay? day;
  final List<CgyyOrder>? orders;
  final CgyyOrder? order;
  final CgyyLockCode? lockCode;
  final FailureCode? failure;
}
