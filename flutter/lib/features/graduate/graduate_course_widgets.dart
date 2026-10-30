import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/academic_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'package:ginkgo_mirror/application/graduate.dart';

/// The credit and completion badges of one course.
class GraduateCourseBadges extends StatelessWidget {
  const GraduateCourseBadges({super.key, required this.row});
  final GraduateRow row;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      AcademicBadge(
        row.credit == null ? '学分未提供' : '${academicNumber(row.credit)} 学分',
        tint: AppleDesign.resourceBlue,
      ),
      AcademicBadge(
        row.completed == true
            ? '已完成'
            : row.completed == false
            ? '在修中'
            : '待确认',
        tint: row.completed == true
            ? CupertinoColors.systemGreen
            : row.completed == false
            ? AppleDesign.statusPending
            : AppleDesign.statusUncertain,
        icon: row.completed == true
            ? CupertinoIcons.checkmark_circle_fill
            : row.completed == false
            ? CupertinoIcons.clock_fill
            : CupertinoIcons.question_circle,
      ),
    ],
  );
}

/// One course of the cultivation plan. Tapping it opens the school record.
class GraduateCourseCard extends StatelessWidget {
  const GraduateCourseCard({super.key, required this.entry});

  final GraduateCourseEntry entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(16),
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => GraduateCourseDetails(entry: entry),
          ),
        ),
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.row.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: CupertinoListTileChevron(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GraduateCourseBadges(row: entry.row),
              const SizedBox(height: 10),
              Text(
                [
                  entry.section,
                  if (entry.row.semester != null) entry.row.semester!,
                ].join(' · '),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The school record of one cultivation-plan course.
class GraduateCourseDetails extends StatelessWidget {
  const GraduateCourseDetails({super.key, required this.entry});
  final GraduateCourseEntry entry;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: const CupertinoNavigationBar(middle: Text('培养方案课程')),
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.row.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                GraduateCourseBadges(row: entry.row),
              ],
            ),
          ),
          AppleSection(
            header: const Text('课程信息'),
            children: [
              AcademicFactRow(label: '培养类别', value: entry.section),
              AcademicFactRow(
                label: '学期',
                value: entry.row.semester ?? '学校未提供',
              ),
            ],
          ),
          AppleSection(
            header: const Text('学校执行报告'),
            footer: const Text('完成状态以学校执行报告为准，课程池中的课程不代表全部必修。'),
            children: [AcademicFactRow(label: '原始记录', value: entry.row.detail)],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
