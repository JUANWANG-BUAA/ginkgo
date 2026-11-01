import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

import 'schedule_style.dart';

class ScheduleDayStrip extends StatelessWidget {
  const ScheduleDayStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.onSelected,
  });

  final String? weekStart;
  final int selectedDay;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Seven days must all be reachable: a fixed 58dp chip overflowed an
    // ordinary phone and pushed Sunday off screen. At normal type sizes the
    // week is split evenly and never scrolls; enlarged text keeps the
    // horizontal scroller so nothing is clipped.
    final fits =
        MediaQuery.textScalerOf(context).scale(1) <= 1.2 &&
        MediaQuery.sizeOf(context).width < 900;
    return SizedBox(
      key: const Key('schedule-day-strip'),
      height: 68,
      child: fits
          ? Padding(
              // The selected pill must not touch the screen edge.
              padding: const EdgeInsets.symmetric(
                horizontal: GinkgoSpacing.pageInset,
              ),
              child: Row(
                children: [
                  for (var index = 0; index < 7; index++)
                    Expanded(child: _day(context, index, compact: true)),
                ],
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: GinkgoSpacing.pageInset,
              ),
              itemCount: 7,
              itemBuilder: (context, index) =>
                  _day(context, index, compact: false),
            ),
    );
  }

  Widget _day(BuildContext context, int index, {required bool compact}) {
    final day = index + 1;
    final selected = day == selectedDay;
    final start = DateTime.tryParse(weekStart ?? '');
    final date = start?.add(Duration(days: index));
    final today = scheduleTodayColumn(weekStart) == day;
    final primary = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
      child: CupertinoButton(
        key: Key('schedule-day-$day'),
        minimumSize: const Size(0, 60),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        color: selected ? primary.withValues(alpha: 0.13) : null,
        borderRadius: BorderRadius.circular(12),
        onPressed: () => onSelected(day),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayNames[index],
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? primary
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
            Text(
              today
                  ? '今天'
                  : date == null
                  ? ''
                  : '${date.month}/${date.day}',
              style: TextStyle(
                fontSize: 11,
                color: selected || today
                    ? primary
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
