import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'loading_widgets.dart';
import 'mirror_service.dart';
import 'application/contracts.dart';

class RulesPage extends StatefulWidget {
  const RulesPage({super.key, required this.service});
  final AcademicGateway service;
  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  late Future<RuleExamples> future;
  @override
  void initState() {
    super.initState();
    future = widget.service.rules();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('rules-scroll'),
      slivers: [
        const ApplePageHeader(
          largeTitle: Text('共享规则示例'),
          previousPageTitle: '空教室',
          border: null,
          section: '学业',
          subtitle: '学校日期与课表周次的只读示例',
          icon: CupertinoIcons.doc_text,
        ),
        FutureBuilder<RuleExamples>(
          future: future,
          builder: (context, state) {
            if (state.connectionState != ConnectionState.done) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: GinkgoLoadingView(label: '正在读取共享规则…'),
              );
            }
            final rules = state.data;
            if (rules == null || rules.failure != null) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: AppleEmptyState(
                  title: failureMessage(rules?.failure),
                  description: '请重试',
                  action: '重试',
                  onAction: () =>
                      setState(() => future = widget.service.rules()),
                  error: true,
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.list(
                children: [
                  AppleSection(
                    header: const Text('学校日期'),
                    children: [
                      const AppleListTile(
                        title: Text('样例时刻'),
                        subtitle: Text('2026-10-18T16:30:00Z'),
                      ),
                      AppleListTile(
                        title: const Text('学校日期'),
                        subtitle: Text(
                          '${rules.localDate} · ${rules.timeZone}',
                        ),
                      ),
                      AppleListTile(
                        title: const Text('距午夜'),
                        additionalInfo: Text(
                          '${rules.minutesSinceMidnight} 分钟',
                        ),
                      ),
                    ],
                  ),
                  AppleSection(
                    header: const Text('课表周次保留'),
                    children: [
                      AppleListTile(
                        title: const Text('已缓存周次'),
                        additionalInfo: Text(rules.cachedWeeks.join('、')),
                      ),
                      AppleListTile(
                        title: const Text('切换至'),
                        additionalInfo: Text('第 ${rules.selectedWeek} 周'),
                      ),
                      for (final name in rules.courseNames)
                        AppleListTile(title: Text(name)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}
