import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'schedule_style.dart';

/// Compact iOS Calendar-style top header replacing stacked title & control cards.
class ScheduleControls extends StatelessWidget {
  const ScheduleControls({
    super.key,
    required this.snapshot,
    required this.terms,
    required this.weeks,
    required this.selectedTerm,
    required this.selectedWeek,
    required this.busy,
    required this.searchActive,
    required this.onSelectTerm,
    required this.onSelectWeek,
    required this.onToggleSearch,
    required this.onRefresh,
    this.onExportIcs,
  });
  final ScheduleResponse snapshot;
  final Map<String, ScheduleTerm> terms;
  final Map<int, ScheduleWeek> weeks;
  final String? selectedTerm;
  final int selectedWeek;
  final bool busy;
  final bool searchActive;
  final Future<void> Function(String termId) onSelectTerm;
  final void Function(int week) onSelectWeek;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefresh;
  final VoidCallback? onExportIcs;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final fillColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final termName = terms[selectedTerm]?.name ?? snapshot.termId;
    final range = weeks[selectedWeek];
    final currentWeekEntry = snapshot.weeks.cast<ScheduleWeek?>().firstWhere(
      (item) => item!.current,
      orElse: () => null,
    );
    final isOnCurrentWeek =
        currentWeekEntry != null && currentWeekEntry.number == selectedWeek;

    final weekButton = snapshot.weeks.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: GinkgoSpacing.xs),
            child: Text(
              '课表',
              style: GinkgoTypography.title.copyWith(
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          )
        : Builder(
            builder: (anchor) => CupertinoButton(
              key: const Key('schedule-week-picker'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
              alignment: Alignment.centerLeft,
              onPressed: () async {
                final value = await chooseWheel<int>(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GinkgoTypography.title.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            fontFeatures: GinkgoTypography.tabularDigits,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: GinkgoSpacing.xs),
                      Icon(
                        CupertinoIcons.chevron_down_circle_fill,
                        size: 18,
                        color: primary.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                  if (range != null)
                    Text(
                      '${shortDate(range.startDate)} – ${shortDate(range.endDate)}',
                      maxLines: 1,
                      style: GinkgoTypography.caption.copyWith(
                        fontFeatures: GinkgoTypography.tabularDigits,
                        color: secondaryColor,
                      ),
                    ),
                ],
              ),
            ),
          );

    final termButton = Builder(
      builder: (anchor) => CupertinoButton(
        key: const Key('schedule-term-picker'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        alignment: Alignment.centerLeft,
        onPressed: () async {
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GinkgoSpacing.sm,
            vertical: GinkgoSpacing.compact,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(GinkgoRadii.panel),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  termName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GinkgoTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(width: GinkgoSpacing.xs),
              Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 11,
                color: secondaryColor,
              ),
            ],
          ),
        ),
      ),
    );

    final currentWeekButton = currentWeekEntry == null
        ? const SizedBox.shrink()
        : CupertinoButton(
            key: const Key('schedule-current-week'),
            padding: const EdgeInsets.symmetric(horizontal: GinkgoSpacing.xs),
            minimumSize: GinkgoButtonTokens.minTarget,
            onPressed: () => onSelectWeek(currentWeekEntry.number),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: GinkgoSpacing.sm,
                vertical: GinkgoSpacing.compact,
              ),
              decoration: BoxDecoration(
                color: isOnCurrentWeek
                    ? fillColor
                    : primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(GinkgoRadii.pill),
              ),
              child: Text(
                isOnCurrentWeek ? '本周' : '回本周',
                style: GinkgoTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isOnCurrentWeek ? secondaryColor : primary,
                ),
              ),
            ),
          );

    Widget circleToolButton({
      Key? key,
      required String label,
      required VoidCallback? onPressed,
      required Widget icon,
      bool active = false,
    }) => CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 48),
      onPressed: onPressed,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? primary.withValues(alpha: 0.16) : fillColor,
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
        GinkgoSpacing.sm,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: weekButton),
              currentWeekButton,
              circleToolButton(
                key: const Key('schedule-search-toggle'),
                label: searchActive ? '收起搜索' : '搜索课程',
                active: searchActive,
                onPressed: onToggleSearch,
                icon: Icon(
                  CupertinoIcons.search,
                  size: 18,
                  color: searchActive
                      ? primary
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
              if (onExportIcs != null && snapshot.courses.isNotEmpty)
                circleToolButton(
                  key: const Key('schedule-export-ics'),
                  label: '导出日历',
                  onPressed: busy ? null : onExportIcs,
                  icon: Icon(
                    CupertinoIcons.share,
                    size: 18,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              circleToolButton(
                key: const Key('schedule-refresh-button'),
                label: '刷新课表',
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const GinkgoActivity(size: 17)
                    : Icon(
                        CupertinoIcons.refresh,
                        size: 18,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
              ),
            ],
          ),
          termButton,
        ],
      ),
    );
  }
}
