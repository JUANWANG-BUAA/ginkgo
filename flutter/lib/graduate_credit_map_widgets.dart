import 'package:flutter/cupertino.dart';

import 'academic_widgets.dart';
import 'application/graduate_credit_map.dart';
import 'apple_design.dart';
import 'apple_widgets.dart';

String _credit(double? value) => value == null ? '未确认' : academicNumber(value);

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
                      value: _credit(progress.requiredCredits),
                    ),
                    AcademicMetric(
                      label: '方案已认定',
                      value: _credit(progress.earned),
                      prominent: true,
                    ),
                    AcademicMetric(
                      label: '待考核',
                      value: _credit(progress.pending),
                    ),
                    AcademicMetric(
                      label: '尚需',
                      value: _credit(progress.remaining),
                    ),
                  ],
                ),
              if (!summary)
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('要求 ${_credit(progress.requiredCredits)}'),
                    Text(
                      '已获 ${_credit(progress.earned)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('待考核 ${_credit(progress.pending)}'),
                    Text('尚需 ${_credit(progress.remaining)}'),
                  ],
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
                Semantics(
                  label: '${node.title}，已认定学分占要求比例',
                  value: '${(ratio * 100).round()}%',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      width: double.infinity,
                      child: ColoredBox(
                        color: CupertinoColors.tertiarySystemFill.resolveFrom(
                          context,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            child: ColoredBox(
                              color: CupertinoTheme.of(context).primaryColor,
                              child: const SizedBox.expand(),
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
