import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'school_timestamp.dart';

String bykcAttendanceLabel(Map<String, dynamic> record) =>
    switch (record['checkin']) {
      1 => '已签到',
      null => '签到待确认',
      final value => '考勤 $value',
    };
String bykcResultLabel(Map<String, dynamic> record) =>
    switch (record['passed']) {
      1 => '已通过',
      0 => '未通过',
      null => '通过待确认',
      final value => '通过状态 $value',
    };
String bykcRecordStatus(Map<String, dynamic> record) => [
  bykcAttendanceLabel(record),
  bykcResultLabel(record),
  if (record['score'] != null) '成绩 ${record['score']}',
].join(' · ');

/// A projection of the fetched snapshot. Opening it sends no new request.
class BykcDetailPage extends StatelessWidget {
  const BykcDetailPage({super.key, required this.course, this.chosenRecord});
  final Map<String, dynamic> course;
  final Map<String, dynamic>? chosenRecord;
  @override
  Widget build(BuildContext context) {
    final details = course['details'] as Map<String, dynamic>? ?? {};
    String text(String key) => details[key]?.toString() ?? '上游未提供';
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
        child: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
    final campuses = (details['campuses'] as List? ?? []).cast<String>();
    final categories = [
      course['category'],
      course['subcategory'],
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
                      course['name'] as String,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      course['teacher'] as String? ?? '教师信息未提供',
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
                  field(
                    '开始时间',
                    schoolTimestampLabel(details['start'] as String?),
                  ),
                  field(
                    '结束时间',
                    schoolTimestampLabel(details['end'] as String?),
                  ),
                  field('上课地点', course['position'] as String? ?? '上游未提供'),
                  if (campuses.isNotEmpty) field('校区', campuses.join('、')),
                ],
              ),
              if (chosenRecord != null)
                AppleSection(
                  header: const Text('学习记录'),
                  children: [
                    _LearningResult(record: chosenRecord!),
                    field(
                      '选课时间',
                      schoolTimestampLabel(
                        chosenRecord!['selectedAt'] as String?,
                      ),
                    ),
                  ],
                ),
              AppleSection(
                header: const Text('选课与人数'),
                footer: const Text('人数为上次读取结果，不代表当前可以选课；请以学校系统为准。'),
                children: [
                  field('选课状态', switch (chosenRecord != null
                      ? true
                      : details['selected']) {
                    true => '已选',
                    false => '未选',
                    _ => '上游未提供',
                  }),
                  field('当前人数', text('enrolled')),
                  field('容量', text('capacity')),
                  field('签到安排', switch (details['hasSignConfig']) {
                    true => '含签到安排，请在学校系统核对',
                    false => '未返回签到配置',
                    _ => '上游未提供',
                  }),
                ],
              ),
              AppleSection(
                header: const Text('选退课时间'),
                children: [
                  field(
                    '选课开始',
                    schoolTimestampLabel(details['selectStart'] as String?),
                  ),
                  field(
                    '选课截止',
                    schoolTimestampLabel(details['selectEnd'] as String?),
                  ),
                  field(
                    '退选截止',
                    schoolTimestampLabel(details['cancelEnd'] as String?),
                  ),
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
                        text('summary'),
                        style: const TextStyle(fontSize: 16, height: 1.5),
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
  final Map<String, dynamic> record;
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
            value: bykcAttendanceLabel(record),
            positive: record['checkin'] == 1,
          ),
          (
            label: '考核结果',
            value: bykcResultLabel(record),
            positive: record['passed'] == 1,
          ),
          (
            label: '成绩',
            value: record['score']?.toString() ?? '上游未提供',
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
