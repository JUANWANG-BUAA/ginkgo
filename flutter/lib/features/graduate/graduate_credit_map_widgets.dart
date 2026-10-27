import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/graduate_credit_map.dart';
import 'package:ginkgo_mirror/design/academic_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'graduate_widgets.dart';

class GraduateCreditMapNotice extends StatelessWidget {
  const GraduateCreditMapNotice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Text(
      text,
      style: TextStyle(
        color: warning
            ? AppleDesign.statusUncertain.resolveFrom(context)
            : CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

/// One node of the credit map: its progress and the rows the school listed
/// under it.
class GraduateCreditMapNodeCard extends StatelessWidget {
  const GraduateCreditMapNodeCard({
    super.key,
    required this.node,
    this.summary = false,
  });
  final GraduateCreditNode node;
  final bool summary;
  @override
  Widget build(BuildContext context) => AppleSection(
    key: ValueKey('credit-node-${node.sourceIndex}'),
    header: Text(summary ? '培养方案总览' : node.title),
    children: [
      if (node.progress case final progress?)
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary)
                AcademicMetricGrid(
                  maxColumns: 2,
                  children: [
                    AcademicMetric(
                      label: '要求学分',
                      value: graduateCreditLabel(progress.requiredCredits),
                    ),
                    AcademicMetric(
                      label: '方案已认定',
                      value: graduateCreditLabel(progress.earned),
                      prominent: true,
                    ),
                    AcademicMetric(
                      label: '待考核',
                      value: graduateCreditLabel(progress.pending),
                    ),
                    AcademicMetric(
                      label: '尚需',
                      value: graduateCreditLabel(progress.remaining),
                    ),
                  ],
                ),
              if (!summary)
                GraduateStatRow(
                  [
                    GraduateStat('要求', graduateCreditLabel(progress.requiredCredits)),
                    GraduateStat(
                      '已获',
                      graduateCreditLabel(progress.earned),
                      weight: FontWeight.w600,
                    ),
                    GraduateStat('待考核', graduateCreditLabel(progress.pending)),
                    GraduateStat('尚需', graduateCreditLabel(progress.remaining)),
                  ],
                  spacing: 16,
                  runSpacing: 8,
                ),
              const SizedBox(height: 12),
              Text(
                progress.stateLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              if (progress.ratio case final ratio?) ...[
                const SizedBox(height: 12),
                GraduateCreditBar(
                  value: ratio,
                  valueColor: CupertinoTheme.of(context).primaryColor,
                  height: 6,
                  borderRadius: 4,
                  semanticLabel: '${node.title}，已认定学分占要求比例',
                ),
              ],
            ],
          ),
        ),
      for (final row in node.rows)
        AppleListTile(
          title: Text(row.title),
          subtitle: Text(row.detail),
          trailing: row.isCourse
              ? Text(switch (row.completed) {
                  true => '已完成',
                  false => '未完成',
                  null => '待确认',
                })
              : null,
        ),
    ],
  );
}
