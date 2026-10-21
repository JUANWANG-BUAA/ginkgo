import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';

/// A projection of the fetched catalog. Opening it sends no new request.
class BykcDetailPage extends StatelessWidget {
  const BykcDetailPage({super.key, required this.course});
  final Map<String, dynamic> course;
  @override
  Widget build(BuildContext context) {
    final details = course['details'] as Map<String, dynamic>? ?? {};
    String text(String key) => details[key]?.toString() ?? '上游未提供';
    Widget field(String label, String value) =>
        AppleListTile(title: Text(label), subtitle: Text(value));
    final campuses = (details['campuses'] as List? ?? []).cast<String>();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('bykc-detail-scroll'),
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('课程详情'),
            previousPageTitle: '博雅',
            border: null,
          ),
          SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  course['name'] as String,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppleSection(
                header: const Text('课程信息'),
                children: [
                  field('教师', course['teacher'] as String? ?? '上游未提供'),
                  field('地点', course['position'] as String? ?? '上游未提供'),
                  field(
                    '类别',
                    [
                          course['category'],
                          course['subcategory'],
                        ].whereType<String>().join(' · ').isEmpty
                        ? '未分类'
                        : [
                            course['category'],
                            course['subcategory'],
                          ].whereType<String>().join(' · '),
                  ),
                  field('校区', campuses.isEmpty ? '上游未提供' : campuses.join('、')),
                  field('选课状态', switch (details['selected']) {
                    true => '已选',
                    false => '未选',
                    _ => '上游未提供',
                  }),
                  field('签到安排', switch (details['hasSignConfig']) {
                    true => '含签到安排，请在学校系统核对',
                    false => '未返回签到配置',
                    _ => '上游未提供',
                  }),
                ],
              ),
              AppleSection(
                header: const Text('时间与人数'),
                footer: const Text('人数来自上次读取的课程目录，不代表当前可以选课。'),
                children: [
                  field('开始时间', text('start')),
                  field('结束时间', text('end')),
                  field('当前人数', text('enrolled')),
                  field('容量', text('capacity')),
                  field('选课开始', text('selectStart')),
                  field('选课截止', text('selectEnd')),
                  field('退选截止', text('cancelEnd')),
                ],
              ),
              AppleSection(
                header: const Text('课程简介'),
                footer: const Text('本页仅展示已读取的信息。选课、退选和签到仍需前往学校系统。'),
                children: [field('原文', text('summary'))],
              ),
              const SizedBox(height: 96),
            ],
          ),
        ],
      ),
    );
  }
}
