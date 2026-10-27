import 'package:flutter/cupertino.dart';

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
  Widget build(BuildContext context) => SizedBox(
    key: const Key('schedule-day-strip'),
    height: 68,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = index + 1;
        final selected = day == selectedDay;
        final start = DateTime.tryParse(weekStart ?? '');
        final date = start?.add(Duration(days: index));
        final today = scheduleTodayColumn(weekStart) == day;
        final primary = CupertinoTheme.of(context).primaryColor;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: CupertinoButton(
            key: Key('schedule-day-$day'),
            minimumSize: const Size(58, 60),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
      },
    ),
  );
}
