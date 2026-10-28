import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/learning_ports.dart';
import 'package:ginkgo_mirror/infrastructure/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'learning_course_page.dart';
import 'learning_widgets.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({
    super.key,
    required this.service,
    this.accountId,
    this.saveFile = saveLearningFile,
  });
  final Object service;
  final String? accountId;
  final LearningFileSaver? saveFile;
  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  late RefreshSection<LearningRead<List<LearningCourse>>> courses;
  String query = '';
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    courses = RefreshSection()..addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool force = false}) {
    final gateway = LearningPorts.resolve(widget.service).courses;
    if (gateway == null) return Future.value();
    return learningRefresh(
      courses,
      () => gateway.learningCourses(forceRefresh: force),
      force,
    );
  }

  @override
  void didUpdateWidget(covariant LearningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.accountId != widget.accountId) {
      epoch++;
      query = '';
      courses.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    epoch++;
    courses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        courses.value?.data
            .where(
              (c) => '${c.name} ${c.teacher ?? ''} ${c.term ?? ''}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList() ??
        [];
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('learning-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('SPOC 学习'),
            section: '学业',
            subtitle: '只读查看课程公告、资料与测验信息',
            icon: CupertinoIcons.book_circle,
            trailing: AppleGlassButton(
              label: '刷新课程',
              onPressed:
                  LearningPorts.resolve(widget.service).courses != null &&
                      !courses.loading
                  ? () => _load(force: true)
                  : null,
              child: const Icon(CupertinoIcons.refresh),
            ),
          ),
          if (courses.value?.data.isNotEmpty == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoSearchTextField(
                  key: ValueKey('learning-search-$epoch'),
                  placeholder: '搜索已加载课程、教师或学期',
                  onChanged: (v) => setState(() => query = v.trim()),
                ),
              ),
            ),
          if (widget.service is! LearningCourseGateway)
            const SliverToBoxAdapter(child: LearningText('当前服务暂不支持课程'))
          else
            SliverToBoxAdapter(
              child: SectionFeedback(
                loading: courses.loading,
                label: '正在读取课程…',
                hasData: courses.value != null,
                error: courses.error,
                onRetry: () => _load(force: true),
              ),
            ),
          if (courses.value != null && rows.isEmpty)
            SliverToBoxAdapter(
              child: LearningText(query.isEmpty ? '暂无课程' : '没有匹配的已加载课程'),
            ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final course = rows[i], e = epoch;
              return AppleSection(
                children: [
                  AppleListTile(
                    key: ValueKey('learning-course-${course.id}'),
                    title: Text(course.name),
                    subtitle: Text(
                      [
                        if (presentText(course.teacher)) course.teacher!,
                        if (presentText(course.term)) course.term!,
                      ].join(' · '),
                    ),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                    ),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => LearningCoursePage(
                          course: course,
                          service: widget.service,
                          accountId: widget.accountId,
                          saveFile: widget.saveFile,
                          isOwnerCurrent: () => mounted && e == epoch,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
