import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/academic_widgets.dart';
import 'package:ginkgo_mirror/features/reservations/reservation_widgets.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'cgyy_models.dart';
import 'cgyy_widgets.dart';

/// The local write protection banner. It stays visible while the last write
/// result is unknown, and it is the only way to reach the fresh review.
class CgyyWriteGuardSection extends StatelessWidget {
  const CgyyWriteGuardSection({
    super.key,
    required this.guardKnown,
    required this.enabled,
    required this.onReview,
  });
  final bool guardKnown, enabled;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: const Text('写入保护'),
    footer: const Text('预约记录出现不代表审批通过。核实前不会再次预约或取消。'),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          guardKnown
              ? '上次操作结果待核实，请先核对最新预约记录。'
              : '尚未确认写入状态，暂不可提交。请刷新或读取最新记录核对。',
        ),
      ),
      CupertinoButton(
        key: const Key('cgyy-open-review'),
        minimumSize: const Size(48, 48),
        onPressed: enabled ? onReview : null,
        child: const Text('读取最新记录并核对'),
      ),
    ],
  );
}

/// The queried venue and the day the slots belong to.
class CgyySiteQuerySection extends StatelessWidget {
  const CgyySiteQuerySection({
    super.key,
    required this.site,
    required this.date,
    required this.enabled,
    required this.onChooseDate,
  });
  final CgyySite site;
  final String date;
  final bool enabled;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) => AppleSection(
    children: [
      cgyySiteContent(site),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '查询日期',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  cgyyDisplayDate(date),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ReservationActionButton(
              buttonKey: const Key('cgyy-choose-date'),
              label: '更改日期',
              icon: CupertinoIcons.calendar,
              onPressed: enabled ? onChooseDate : null,
            ),
          ],
        ),
      ),
    ],
  );
}

/// The entry that opens the booking form. It stays disabled while the write
/// protection is on.
class CgyyBookingEntrySection extends StatelessWidget {
  const CgyyBookingEntrySection({
    super.key,
    required this.enabled,
    required this.onTap,
  });
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppleSection(
    footer: const Text('提交前重新核对空档；实验写入功能，需手动验证并确认。'),
    children: [
      AppleListTile(
        leading: const Icon(CupertinoIcons.calendar_badge_plus),
        title: const Text('预约研讨室'),
        trailing: const CupertinoListTileChevron(),
        key: const Key('cgyy-open-booking'),
        onTap: enabled ? onTap : null,
      ),
    ],
  );
}

/// The heading and one section per space of the queried day. A slot is shown
/// exactly as the school reported it; the page never grades availability.
List<Widget> cgyyDaySlots(BuildContext context, CgyyDay day) => [
  Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '空间时段',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '实际显示 ${cgyyDisplayDate(day.date)}',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 10),
        const AcademicBadge(
          '仅供查询',
          tint: CupertinoColors.systemTeal,
          icon: CupertinoIcons.info_circle,
        ),
      ],
    ),
  ),
  if (day.spaces.isEmpty)
    const CgyyStatusSection(
      title: '当天暂无空间时段',
      description: '可切换其他日期。',
    ),
  for (final space in day.spaces)
    AppleSection(
      header: Text(space.name),
      children: [
        if (space.slots.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('暂无时段'),
          ),
        for (final slot in space.slots)
          CgyySlotRow(time: slot.time, status: slot.status),
      ],
    ),
];

/// The most recent bookings the school returned.
class CgyyOrderListSection extends StatelessWidget {
  const CgyyOrderListSection({super.key, required this.orders});
  final List<CgyyOrder> orders;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: const Text('最近最多 20 条'),
    children: [
      for (final order in orders)
        CgyyTileContent(
          icon: CupertinoIcons.doc_text,
          tint: CupertinoColors.systemIndigo,
          title: order.place.isEmpty ? '预约记录' : order.place,
          detail: '${cgyyDisplayDate(order.date)}\n${order.time}',
          badges: [
            AcademicBadge(
              order.statusLabel,
              tint: CupertinoColors.systemIndigo,
              icon: CupertinoIcons.info_circle,
            ),
          ],
        ),
    ],
  );
}

/// The bookings that may still be cancelled. The school decides which ones
/// qualify; the page only sends a cancel for an order it was given.
class CgyyOrderManageSection extends StatelessWidget {
  const CgyyOrderManageSection({
    super.key,
    required this.orders,
    required this.enabled,
    required this.onCancel,
  });
  final List<CgyyOrder> orders;
  final bool enabled;
  final ValueChanged<CgyyOrder> onCancel;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: const Text('预约管理'),
    footer: const Text('取消前会核对订单状态及开始前 4 小时限制；不符合条件不会发送请求。'),
    children: [
      for (final order in orders)
        if (order.canCancel)
          AppleListTile(
            key: ValueKey('cgyy-cancel-${order.id}'),
            title: Text('取消 · ${order.place}'),
            subtitle: Text(order.summary),
            onTap: enabled ? () => onCancel(order) : null,
          ),
    ],
  );
}

/// The date picker of the day page. Returns the picked date, or null when the
/// user dismisses the sheet.
Future<DateTime?> cgyyPickDate(BuildContext context, DateTime initial) async {
  var draft = initial;
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => Container(
      height: 310,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () {
                    if (ModalRoute.of(context)?.isCurrent ?? false) {
                      Navigator.pop(context, false);
                    }
                  },
                  child: const Text('取消'),
                ),
                CupertinoButton(
                  onPressed: () {
                    if (ModalRoute.of(context)?.isCurrent ?? false) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                onDateTimeChanged: (value) => draft = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed == true ? draft : null;
}

/// The school date plus its weekday, shown wherever a raw date is presented.
String cgyyDisplayDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return schoolDateWeekdayLabel(date);
}
