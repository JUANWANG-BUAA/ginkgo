import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/reservations/reservation_widgets.dart';

import 'package:ginkgo_mirror/application/library_holdings.dart';
import 'package:ginkgo_mirror/application/library_books.dart';

/// The result rows of the library domain. Each row states exactly what the
/// school reported and never turns a status into a local promise.

/// One catalogue hit. The call number and the fact line are shown only when
/// the school returned them.
class LibraryBookCard extends StatelessWidget {
  const LibraryBookCard({super.key, required this.hit, required this.onTap});

  final BookHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppleListTile(
    title: Text(
      hit.displayTitle,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: AppleDesign.bodyCondensedSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hit.factLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              hit.factLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        if (hit.callno.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '索书号 ${hit.callno}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
      ],
    ),
    trailing: const CupertinoListTileChevron(),
    onTap: onTap,
  );
}

/// One physical copy. The status stays the school's own text; it is never
/// converted into a local "available" judgement. A repeated call number is
/// labelled as such so the same call number is not read twice.
class LibraryHoldingCard extends StatelessWidget {
  const LibraryHoldingCard({
    super.key,
    required this.holding,
    required this.repeatedCallNo,
  });

  final BookHolding holding;
  final bool repeatedCallNo;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.tertiaryLabel.resolveFrom(context);
    return AppleListTile(
      title: Text(holding.place.isEmpty ? '馆藏位置待确认' : '馆藏地：${holding.place}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('状态：${holding.status.isEmpty ? '未标注' : holding.status}'),
          Text(
            repeatedCallNo
                ? '同索书号：${holding.callNo}'
                : '索书号：${holding.callNo.isEmpty ? '未标注' : holding.callNo}',
          ),
          Text(
            '册条码：${holding.barCode.isEmpty ? '未标注' : holding.barCode}',
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Venue capacity has three readable states: a quiet thin bar while seats
/// are plentiful, a pending tint when they run low, and no bar at all when
/// the school did not report a capacity. Zero free seats is a measurement; a
/// zero total is not, so the latter never renders as a "0" count.
class LibraryVenueMeter extends StatelessWidget {
  const LibraryVenueMeter({super.key, required this.venue, this.onTap});

  static const _tightRatio = 0.2;

  final LibraryVenue venue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final known = venue.total > 0;
    final ratio = known ? (venue.free / venue.total).clamp(0.0, 1.0) : null;
    final tight = ratio != null && (venue.free <= 0 || ratio < _tightRatio);
    final color = tight ? AppleDesign.statusPending : AppleDesign.resourceTeal;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 3),
                  child: CupertinoListTileChevron(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                known ? '${venue.free}' : '—',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  color: color.resolveFrom(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  known ? '座可用 · 共 ${venue.total} 座' : '余量待确认',
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 10),
            Semantics(
              label: '${venue.name} 空闲比例',
              value: tight ? '余量紧张' : '余量充足',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    key: Key('library-venue-bar-${venue.id}'),
                    height: 3,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: ColoredBox(
                            key: Key('library-venue-fill-${venue.id}'),
                            color: color
                                .resolveFrom(context)
                                .withValues(alpha: tight ? 0.55 : 0.4),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? KeyedSubtree(key: Key('library-venue-${venue.id}'), child: content)
        : CupertinoButton(
            key: Key('library-venue-${venue.id}'),
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              child: content,
            ),
          );
  }
}

/// One seat row inside the seat list. The reserve action is offered only for
/// a free seat and only when no read or write is in flight.
///
/// The rounded group key stays on the clipped rectangle itself so the group
/// can be located by its own id, independent of the surrounding list.
Widget librarySeatRow(
  BuildContext context, {
  required Key groupKey,
  required LibrarySeat seat,
  required bool roundedTop,
  required bool roundedBottom,
  required bool hasSeparator,
  required bool reserveEnabled,
  required bool submitting,
  required VoidCallback onReserve,
}) => ClipRRect(
  key: groupKey,
  borderRadius: BorderRadius.vertical(
    top: roundedTop
        ? const Radius.circular(AppleDesign.groupRadius)
        : Radius.zero,
    bottom: roundedBottom
        ? const Radius.circular(AppleDesign.groupRadius)
        : Radius.zero,
  ),
  child: ColoredBox(
    color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    ),
    child: Column(
      children: [
        AppleListTile(
          key: Key('library-seat-${seat.id}'),
          trailing: seat.available
              ? ReservationActionButton(
                  buttonKey: Key('library-reserve-${seat.id}'),
                  label: '预约',
                  icon: CupertinoIcons.add_circled,
                  compact: true,
                  busy: submitting,
                  onPressed: reserveEnabled ? onReserve : null,
                )
              : null,
          leading: Icon(
            seat.available
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            color:
                (seat.available
                        ? AppleDesign.statusSuccess
                        : CupertinoColors.tertiaryLabel)
                    .resolveFrom(context),
            size: 22,
          ),
          title: Text(
            seat.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            seat.statusName.isEmpty
                ? (seat.available ? '空闲' : '不可用')
                : seat.statusName,
            style: TextStyle(
              color:
                  (seat.available
                          ? AppleDesign.statusSuccess
                          : CupertinoColors.secondaryLabel)
                      .resolveFrom(context),
            ),
          ),
        ),
        if (hasSeparator)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 0.5,
              color: CupertinoColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.16),
            ),
          ),
      ],
    ),
  ),
);
