import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'bykc_models.dart';
import 'bykc_widgets.dart';

/// 博雅课程列表项。
///
/// [record] 非空表示这是「已选记录」视图，展示考勤与成绩；为空时展示目录
/// 视图的选课状态与人数。
class BykcCourseTile extends StatelessWidget {
  const BykcCourseTile({
    super.key,
    required this.course,
    required this.onTap,
    this.record,
  });

  final BykcCourse course;
  final BykcChosenRecord? record;
  final VoidCallback onTap;

  /// 类别标签配色：美育、劳动教育、安全健康各有固定色，其余沿用主题色。
  Color _categoryTint(BuildContext context) =>
      switch (course.categoryLabel) {
        '美育' => AppleDesign.resourcePurple.resolveFrom(context),
        '劳动教育' => AppleDesign.resourceTeal.resolveFrom(context),
        '安全健康' => AppleDesign.resourceBlue.resolveFrom(context),
        _ => CupertinoTheme.of(context).primaryColor,
      };

  /// 人数接近或达到上限时用告警色，已有人报名但未满用待定色。
  Color? _capacityTint(BuildContext context, BykcCourseDetails details) {
    final enrolled = details.enrolled;
    final capacity = details.capacity;
    if (enrolled != null && capacity != null && enrolled >= capacity) {
      return AppleDesign.statusDanger.resolveFrom(context);
    }
    if (enrolled != null && enrolled > 0) {
      return AppleDesign.statusPending.resolveFrom(context);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final details = course.details ?? BykcCourseDetails.empty();
    return AppleListTile(
      key: ValueKey(
        record != null ? 'bykc-chosen-${record!.id}' : 'bykc-course-${course.id}',
      ),
      leading: record != null
          ? Icon(
              record!.passed == 1
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.book,
              color: record!.passed == 1
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.activeBlue,
            )
          : null,
      title: Text(
        course.name,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                BykcLabel(text: course.categoryLabel, tint: _categoryTint(context)),
                if (record == null && details.selected == true)
                  const BykcLabel(text: '已选', positive: true),
                if (record == null &&
                    (details.enrolled != null || details.capacity != null))
                  BykcLabel(
                    text:
                        '人数 ${details.enrolled ?? '—'} / ${details.capacity ?? '未提供'}',
                    tint: _capacityTint(context, details),
                  ),
              ],
            ),
            if (details.start != null) ...[
              const SizedBox(height: 9),
              BykcMetadata(
                icon: CupertinoIcons.clock,
                text: schoolTimestampLabel(details.start),
                prominent: true,
              ),
            ],
            if ((course.position ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              BykcMetadata(
                icon: CupertinoIcons.location,
                text: course.position!,
              ),
            ],
            if ((course.teacher ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              BykcMetadata(
                icon: CupertinoIcons.person,
                text: course.teacher!,
                auxiliary: true,
              ),
            ],
            if (record != null) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  BykcLabel(
                    text: record!.attendanceLabel,
                    positive: record!.checkin == 1,
                  ),
                  BykcLabel(
                    text: record!.resultLabel,
                    positive: record!.passed == 1,
                  ),
                  if (record!.score != null)
                    BykcLabel(text: '成绩 ${record!.score}'),
                ],
              ),
            ],
          ],
        ),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}
