import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'schedule_style.dart';
import 'schedule_week_strip.dart';
import 'schedule_widgets.dart';

/// Term and week pickers shown above the schedule content.
///
/// The controls always describe the snapshot that is currently on screen, so
/// a failed load never relabels the visible courses.
class ScheduleControls extends StatelessWidget {
  const ScheduleControls({
    super.key,
    required this.snapshot,
    required this.terms,
    required this.weeks,
    required this.selectedTerm,
    required this.selectedWeek,
    required this.onSelectTerm,
    required this.onSelectWeek,
  });
  final ScheduleResponse snapshot;
  final Map<String, ScheduleTerm> terms;
  final Map<int, ScheduleWeek> weeks;
  final String? selectedTerm;
  final int selectedWeek;
  final Future<void> Function(String termId) onSelectTerm;
  final void Function(int week) onSelectWeek;

  @override
  Widget build(BuildContext context) {
    final termPicker = Builder(
      builder: (anchor) => ScheduleChevronRow(
        key: const Key('schedule-term-picker'),
        onTap: () async {
          final id = await choose<String>(
            anchor,
            '学期',
            terms.keys.toList(),
            (id) => terms[id]?.name ?? id,
            selected: selectedTerm,
          );
          if (!context.mounted || id == null || id == selectedTerm) return;
          await onSelectTerm(id);
        },
        child: Text(
          terms[selectedTerm]?.name ?? snapshot.termId,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: AppleDesign.calloutSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
    if (snapshot.weeks.isEmpty) return termPicker;
    final weekPicker = Builder(
      builder: (anchor) => CupertinoButton(
        key: const Key('schedule-week-picker'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        minimumSize: const Size(48, 64),
        alignment: Alignment.centerLeft,
        onPressed: () async {
          final value = await choose<int>(
            anchor,
            '选择周次',
            snapshot.weeks.map((week) => week.number).toList(),
            (week) => '第 $week 周',
            selected: selectedWeek,
          );
          if (!context.mounted || value == null || value == selectedWeek) {
            return;
          }
          onSelectWeek(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '第 $selectedWeek 周',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_down, size: 14),
              ],
            ),
            if (weeks[selectedWeek] case final ScheduleWeek range)
              Text(
                '${shortDate(range.startDate)} – ${shortDate(range.endDate)}',
                style: scheduleSecondary(context),
              ),
          ],
        ),
      ),
    );
    final currentWeek = snapshot.weeks.any((item) => item.current)
        ? CupertinoButton(
            key: const Key('schedule-current-week'),
            minimumSize: const Size(48, 48),
            onPressed: () => onSelectWeek(
              snapshot.weeks.firstWhere((item) => item.current).number,
            ),
            child: const Text('本周'),
          )
        : const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth >= 360 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              Row(
                children: [
                  Expanded(flex: 6, child: termPicker),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: weekPicker,
                    ),
                  ),
                ],
              )
            else ...[
              termPicker,
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(child: weekPicker),
                    currentWeek,
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: ScheduleWeekStrip(
                    weeks: snapshot.weeks,
                    selectedWeek: selectedWeek,
                    onSelected: onSelectWeek,
                  ),
                ),
                if (compact) currentWeek,
              ],
            ),
          ],
        );
      },
    );
  }
}
