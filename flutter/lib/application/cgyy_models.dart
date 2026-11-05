import 'package:ginkgo_mirror/application/contracts.dart';

/// CGYY application values shared by gateways, adapters and pages.
/// Presentation labels live in the feature layer.

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

/// Order values preserve absent approval fields as unknown.
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
