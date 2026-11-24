import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';

import 'schedule_style.dart';

/// iOS Apple Calendar-style 7-day circular date selector with colored course
/// indicator dots underneath busy weekdays.
class ScheduleDayStrip extends StatelessWidget {
  const ScheduleDayStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.onSelected,
    this.dayCourses = const {},
  });

  final String? weekStart;
  final int selectedDay;
  final ValueChanged<int> onSelected;
  final Map<int, List<ScheduleCourse>> dayCourses;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final height = math.max(
      70.0,
      (scaler.scale(GinkgoTypography.caption2.fontSize!) +
                  scaler.scale(GinkgoTypography.subheadline.fontSize!)) *
              1.25 +
          30,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= 400
            ? GinkgoSpacing.md
            : GinkgoSpacing.sm;
        final fits =
            scaler.scale(1) <= 1.2 &&
            constraints.maxWidth < 900 &&
            (constraints.maxWidth - inset * 2) / 7 >= 48;
        return SizedBox(
          key: const Key('schedule-day-strip'),
          height: height,
          child: fits
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemGroupedBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(GinkgoRadii.group),
                    ),
                    child: Row(
                      children: [
                        for (var index = 0; index < 7; index++)
                          Expanded(child: _day(context, index, compact: true)),
                      ],
                    ),
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
      },
    );
  }

  Widget _day(BuildContext context, int index, {required bool compact}) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final day = index + 1;
    final selected = day == selectedDay;
    final start = DateTime.tryParse(weekStart ?? '');
    final date = start?.add(Duration(days: index));
    final today = scheduleTodayColumn(weekStart) == day;
    final primary = CupertinoTheme.of(context).primaryColor;
    final coursesOnDay = dayCourses[day] ?? const <ScheduleCourse>[];
    final numberText = date == null ? weekdayNames[index] : '${date.day}';
    return Padding(
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: GinkgoSpacing.opticalIconInset,
            ),
      child: CupertinoButton(
        key: Key('schedule-day-$day'),
        minimumSize: const Size(48, 60),
        padding: const EdgeInsets.symmetric(
          horizontal: GinkgoSpacing.opticalIconInset,
          vertical: GinkgoSpacing.xs,
        ),
        onPressed: () => onSelected(day),
        child: Semantics(
          selected: selected,
          label:
              '${weekdayNames[index]}${today ? ' 今天' : ''}${coursesOnDay.isEmpty ? '' : ' ${coursesOnDay.length}节课'}',
          excludeSemantics: true,
          child: SizedBox(
            width: compact ? double.infinity : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortWeekdayLetters[index],
                  maxLines: 1,
                  style: GinkgoTypography.caption2.copyWith(
                    height: 1.1,
                    fontWeight: selected || today
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected || today
                        ? primary
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: GinkgoSpacing.xs),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: selected
                      ? BoxDecoration(
                          color: primary.withValues(alpha: dark ? 0.30 : 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primary.withValues(alpha: 0.55),
                          ),
                        )
                      : today
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primary.withValues(alpha: 0.40),
                          ),
                        )
                      : null,
                  child: Text(
                    numberText,
                    maxLines: 1,
                    style: GinkgoTypography.subheadline.copyWith(
                      height: 1.0,
                      fontWeight: selected || today
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontFeatures: GinkgoTypography.tabularDigits,
                      color: selected || today
                          ? primary
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                const SizedBox(height: GinkgoSpacing.xs),
                SizedBox(
                  height: GinkgoSpacing.compact,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in coursesOnDay.take(3))
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: courseColor(context, c.color, c.name),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
