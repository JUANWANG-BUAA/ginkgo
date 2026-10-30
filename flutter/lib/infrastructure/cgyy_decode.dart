import '../features/cgyy/cgyy_models.dart';
import '../src/rust/api/live.dart' as live;

CgyySite _site(live.CgyySiteDto dto) => CgyySite(
  id: dto.id,
  name: dto.name,
  // The school always sends a venue, but presentation degrades to the name
  // when absent; keep that tolerance here.
  venue: dto.venue,
  campus: dto.campus,
  seats: dto.seats,
);

CgyyOrder _order(live.CgyyOrderDto dto) => CgyyOrder(
  id: dto.id,
  place: dto.place,
  date: dto.date,
  time: dto.time,
  status: dto.status,
  orderStatus: dto.orderStatus,
  checkStatus: dto.checkStatus,
  canCancel: dto.canCancel,
);

CgyyDay _day(live.CgyyDayDto dto) => CgyyDay(
  date: dto.date,
  spaces: List.unmodifiable(
    dto.spaces.map(
      (space) => CgyySpace(
        name: space.name,
        slots: List.unmodifiable(
          space.slots.map(
            (slot) => CgyySlot(time: slot.time, status: slot.status),
          ),
        ),
      ),
    ),
  ),
);

CgyyLockCode _lockCode(live.CgyyLockCodeDto dto) => CgyyLockCode(
  qrCode: dto.qrCode,
  dueDate: dto.dueDate,
  tradeNo: dto.tradeNo,
  venueName: dto.venueName,
  siteName: dto.siteName,
  spaceName: dto.spaceName,
  orderName: dto.orderName,
  reservationDate: dto.reservationDate,
  reservationDateDetail: dto.reservationDateDetail,
  reservationStartDate: dto.reservationStartDate,
  reservationEndDate: dto.reservationEndDate,
);

/// Projects the five-shape read. Exactly one shape field is non-null.
CgyyLoadRead decodeCgyyLoad(live.CgyyLoadResponse response) {
  return CgyyLoadRead(
    sites: response.venues?.map(_site).toList(growable: false),
    day: response.day == null ? null : _day(response.day!),
    orders: response.orders?.map(_order).toList(growable: false),
    order: response.order == null ? null : _order(response.order!),
    lockCode: response.lockCode == null ? null : _lockCode(response.lockCode!),
    failure: response.failure,
  );
}

/// Projects the write result. Options/challenge/review stay optional exactly
/// as the Rust action result produced them.
CgyyActionResult decodeCgyyAction(live.CgyyActionResultResponse response) {
  final d = response.data;
  if (d == null) {
    // A hard failure carries no action result; the state vocabulary stays
    // with Rust, so the presentation falls back to its unknown outcome.
    return CgyyActionResult.fromState('uncertain', '请核对我的预约');
  }
  return CgyyActionResult.of(
    state: d.state,
    message: d.message,
    options: d.options == null
        ? null
        : CgyyBookingOptions(
            choices: List.unmodifiable(
              d.options!.choices.map(
                (choice) => CgyyBookingChoice(
                  spaceId: choice.spaceId,
                  spaceName: choice.spaceName,
                  timeId: choice.timeId,
                  time: choice.time,
                ),
              ),
            ),
            purposes: List.unmodifiable(
              d.options!.purposes.map(
                (purpose) => CgyyPurpose(id: purpose.id, name: purpose.name),
              ),
            ),
            usesFallbackPurposes: d.options!.usesFallbackPurposes,
          ),
    challenge: d.challenge == null
        ? null
        : CgyyChallenge(
            id: d.challenge!.id,
            background: d.challenge!.background,
            jigsaw: d.challenge!.jigsaw,
          ),
    review: d.review == null
        ? null
        : CgyyReviewSnapshot(
            id: d.review!.id,
            orders: List.unmodifiable(d.review!.orders.map(_order)),
          ),
  );
}
