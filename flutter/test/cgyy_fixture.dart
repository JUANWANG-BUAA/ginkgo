import 'dart:convert';
import 'dart:io';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';

/// Test fixtures stay map-shaped; production now receives a typed DTO.
CgyyLoadRead cgyyLoadRead(String kind, Object? data, {FailureCode? failure}) {
  if (failure != null) return CgyyLoadRead(failure: failure);
  return switch (kind) {
    'venues' => CgyyLoadRead(
      sites: [
        for (final site in (data as List).cast<Map>())
          CgyySite(
            id: site['id'] as int,
            name: site['name'] as String? ?? '',
            venue: site['venue'] as String? ?? '',
            campus: site['campus'] as String? ?? '',
            seats: site['seats'] as int?,
          ),
      ],
    ),
    'day' => CgyyLoadRead(
      day: CgyyDay(
        date: (data as Map)['date'] as String? ?? '',
        spaces: [
          for (final space in (data['spaces'] as List? ?? const []).cast<Map>())
            CgyySpace(
              name: space['name'] as String? ?? '',
              slots: [
                for (final slot
                    in (space['slots'] as List? ?? const []).cast<Map>())
                  CgyySlot(
                    time: slot['time'] as String? ?? '',
                    status: slot['status'] as String? ?? '',
                  ),
              ],
            ),
        ],
      ),
    ),
    'orders' => CgyyLoadRead(
      orders: [
        for (final order in (data as List).cast<Map>()) cgyyOrderFrom(order),
      ],
    ),
    'order' => CgyyLoadRead(order: cgyyOrderFrom(data as Map)),
    'lockCode' => CgyyLoadRead(lockCode: _lockCode(data! as Map)),
    _ => throw ArgumentError('unknown cgyy kind: $kind'),
  };
}

CgyyOrder cgyyOrderFrom(Map order) => CgyyOrder(
  id: order['id'] as int,
  place: order['place'] as String? ?? '',
  date: order['date'] as String? ?? '',
  time: order['time'] as String? ?? '',
  status: order['status'] as String? ?? '',
  orderStatus: order['order_status'] as int?,
  checkStatus: order['check_status'] as int?,
  canCancel: order['can_cancel'] == true,
);

CgyyLockCode _lockCode(Map data) => CgyyLockCode(
  qrCode: data['qrCode'] as String?,
  dueDate: data['dueDate'] as String?,
  tradeNo: data['tradeNo'] as String?,
  venueName: data['venueName'] as String?,
  siteName: data['siteName'] as String?,
  spaceName: data['spaceName'] as String?,
  orderName: data['orderName'] as String?,
  reservationDate: data['reservationDate'] as String?,
  reservationDateDetail: data['reservationDateDetail'] as String?,
  reservationStartDate: data['reservationStartDate'] as String?,
  reservationEndDate: data['reservationEndDate'] as String?,
);

/// Loads a synthetic contract's `expected` section by file base name.
Object cgyyFixture(String name, {String variant = 'normal'}) => (jsonDecode(
  File('../fixtures/cgyy/$name-$variant-v1.json').readAsStringSync(),
) as Map)['expected'];
