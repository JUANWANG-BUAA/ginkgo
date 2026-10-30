import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/application/bykc.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';

/// A projection of the fetched snapshot. Opening it sends no new request.
class BykcDetailPage extends StatelessWidget {
  const BykcDetailPage({super.key, required this.course, this.chosenRecord});
  final BykcCourse course;
  final BykcChosenRecord? chosenRecord;
  @override
  Widget build(BuildContext context) {
    final details = course.details;
    Widget field(String label, String value) => AppleListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: SafeArea(
          child: Text(
          value,
          style: TextStyle(
            fontSize: AppleDesign.bodyCondensedSize,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        )
        ),
      ),
    );
    final categories = [
      course.category,
      course.subcategory,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toSet();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('bykc-detail-scroll'),
        slivers: [
          const ApplePageHeader(
            largeTitle: Text('课程详情'),
            previousPageTitle: '博雅',
            border: null,
            section: '学业',
            subtitle: '查看活动课程与个人记录',
            icon: CupertinoIcons.book_solid,
          ),
          SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categories.isEmpty ? '未分类' : categories.join(' / '),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      course.teacher ?? '教师信息未提供',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppleSection(
                header: const Text('上课安排'),
                children: [
                  field('开始时间', schoolTimestampLabel(details?.start)),
                  field('结束时间', schoolTimestampLabel(details?.end)),
                  field('上课地点', course.position ?? '上游未提供'),
                  if (details != null && details.campuses.isNotEmpty)
                    field('校区', details.campuses.join('、')),
                ],
              ),
              if (chosenRecord != null)
                AppleSection(
                  header: const Text('学习记录'),
                  children: [
                    _LearningResult(record: chosenRecord!),
                    field(
                      '选课时间',
                      schoolTimestampLabel(chosenRecord!.selectedAt),
                    ),
                  ],
                ),
              AppleSection(
                header: const Text('选课与人数'),
                footer: const Text('人数为上次读取结果，不代表当前可以选课；请以学校系统为准。'),
                children: [
                  field('选课状态', switch (chosenRecord != null
                      ? true
                      : details?.selected) {
                    true => '已选',
                    false => '未选',
                    _ => '上游未提供',
                  }),
                  field('当前人数', details?.enrolled?.toString() ?? '上游未提供'),
                  field('容量', details?.capacity?.toString() ?? '上游未提供'),
                  field('签到安排', switch (details?.hasSignConfig) {
                    true => '含签到安排，请在学校系统核对',
                    false => '未返回签到配置',
                    _ => '上游未提供',
                  }),
                ],
              ),
              AppleSection(
                header: const Text('选退课时间'),
                children: [
                  field('选课开始', schoolTimestampLabel(details?.selectStart)),
                  field('选课截止', schoolTimestampLabel(details?.selectEnd)),
                  field('退选截止', schoolTimestampLabel(details?.cancelEnd)),
                ],
              ),
              AppleSection(
                header: const Text('课程简介'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        details?.summary ?? '上游未提供',
                        style: const TextStyle(
                          fontSize: AppleDesign.bodyCondensedSize,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 96),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearningResult extends StatelessWidget {
  const _LearningResult({required this.record});
  final BykcChosenRecord record;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        for (final result in [
          (
            label: '考勤',
            value: record.attendanceLabel,
            positive: record.checkin == 1,
          ),
          (
            label: '考核结果',
            value: record.resultLabel,
            positive: record.passed == 1,
          ),
          (
            label: '成绩',
            value: record.score?.toString() ?? '上游未提供',
            positive: false,
          ),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.label,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: result.positive
                      ? CupertinoColors.systemGreen.resolveFrom(context)
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
