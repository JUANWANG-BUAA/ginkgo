import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/today/today_presentation.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'package:ginkgo_mirror/application/shuttle.dart';

/// The capacity the school printed for a run. A missing number stays
/// "未公布" instead of reading as an empty bus.
String shuttleCapacityLabel(String capacity) =>
    capacity.isEmpty ? '计划容量未公布' : '计划 $capacity 座';

/// Next departure and at most two follow-ups, derived only from the
/// published runs and Beijing wall time. No request is issued and no seat
/// availability is inferred.
class ShuttlePlanSection extends StatelessWidget {
  const ShuttlePlanSection({
    super.key,
    required this.runs,
    required this.clock,
  });

  final List<ShuttleDeparture> runs;
  final DateTime clock;

  @override
  Widget build(BuildContext context) {
    final nowMinute = clock.hour * 60 + clock.minute;
    final upcoming = runs
        .where((run) => run.minutes >= nowMinute)
        .take(3)
        .toList();
    return TodayVisualSection(
      key: const Key('shuttle-plan'),
      header: const TodaySectionHeader(
        icon: CupertinoIcons.bus,
        title: '下一班计划',
        badge: '静态时刻表',
      ),
      footer: const Text(
        '按北京时间从公开静态时刻表推算；计划容量是公布的可乘人数，不代表实时空位。节假日与临时调整以官方页面为准。',
      ),
      children: [
        if (upcoming.isEmpty)
          AppleListTile(
            key: Key(runs.isEmpty ? 'shuttle-plan-none' : 'shuttle-plan-ended'),
            title: Text(runs.isEmpty ? '今日无计划班次' : '今日计划班次已结束'),
            subtitle: Text(
              runs.isEmpty
                  ? '公开时刻表没有今天适用的班次，完整时刻表见下方。'
                  : '按北京时间，今天适用的班次已全部发出；后续安排见完整时刻表或官方页面。',
            ),
            leading: Icon(
              CupertinoIcons.clock,
              color: AppleDesign.statusInactive,
            ),
          )
        else ...[
          ShuttlePlanNext(run: upcoming.first),
          for (var i = 1; i < upcoming.length; i++) ...[
            const TodayVisualDivider(),
            ShuttlePlanFollowing(run: upcoming[i], index: i - 1),
          ],
        ],
      ],
    );
  }
}

/// The next departure, shown large because it is the one to catch.
class ShuttlePlanNext extends StatelessWidget {
  const ShuttlePlanNext({super.key, required this.run});

  final ShuttleDeparture run;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      width: double.infinity,
      key: const Key('shuttle-plan-next'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            run.direction,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                run.time,
                key: const Key('shuttle-plan-next-time'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                shuttleCapacityLabel(run.capacity),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// A departure after the next one.
class ShuttlePlanFollowing extends StatelessWidget {
  const ShuttlePlanFollowing({
    super.key,
    required this.run,
    required this.index,
  });

  final ShuttleDeparture run;
  final int index;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      width: double.infinity,
      key: Key('shuttle-plan-following-$index'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '随后',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
              Text(
                run.time,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                shuttleCapacityLabel(run.capacity),
                style: TextStyle(
                  fontSize: 13,
                  color: AppleDesign.statusInactive.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            run.direction,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    ),
  );
}

/// One dated section of a published table: both directions and their runs.
class ShuttleTableSection extends StatelessWidget {
  const ShuttleTableSection({
    super.key,
    required this.section,
    required this.leftName,
    required this.rightName,
    required this.nowMinute,
  });

  final ShuttleSection section;
  final String leftName, rightName;
  final int nowMinute;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: Text(section.label.isEmpty ? '公开时刻表' : section.label),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final directions = [
              ShuttleDirectionRuns(
                name: leftName,
                runs: section.left,
                nowMinute: nowMinute,
              ),
              ShuttleDirectionRuns(
                name: rightName,
                runs: section.right,
                nowMinute: nowMinute,
              ),
            ];
            // Do not shrink accessible text to preserve a two-column table.
            // Keep each direction and its runs together at large scales.
            final scaledFont = MediaQuery.textScalerOf(context).scale(13);
            final stacked =
                constraints.maxWidth < 300 ||
                (constraints.maxWidth - 12) / 2 < scaledFont * 9;
            if (stacked) {
              return Column(
                key: const Key('shuttle-directions-stacked'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  directions[0],
                  const SizedBox(height: 20),
                  directions[1],
                ],
              );
            }
            return Row(
              key: const Key('shuttle-directions-columns'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: directions[0]),
                const SizedBox(width: 12),
                Expanded(child: directions[1]),
              ],
            );
          },
        ),
      ),
    ],
  );
}

/// One direction of a published table and the runs printed under it.
class ShuttleDirectionRuns extends StatelessWidget {
  const ShuttleDirectionRuns({
    super.key,
    required this.name,
    required this.runs,
    required this.nowMinute,
  });

  final String name;
  final List<ShuttleRun> runs;
  final int nowMinute;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final run in runs)
            ShuttleRunChip(
              run: run,
              departed: run.minuteOfDay != null && run.minuteOfDay! < nowMinute,
            ),
        ],
      ),
    ],
  );
}

/// One published run. Departed runs fall back to a quiet fill so the
/// remaining schedule reads at a glance.
class ShuttleRunChip extends StatelessWidget {
  const ShuttleRunChip({super.key, required this.run, required this.departed});

  final ShuttleRun run;
  final bool departed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: departed
          ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
          : CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      run.capacity.isEmpty ? run.time : '${run.time} · ${run.capacity}座',
      style: TextStyle(
        fontSize: 13,
        color: departed
            ? CupertinoColors.secondaryLabel.resolveFrom(context)
            : CupertinoColors.label.resolveFrom(context),
      ),
    ),
  );
}
