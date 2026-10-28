import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/academic_widgets.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'graduate_models.dart';
import 'graduate_widgets.dart';

/// The three lenses on the graduate page: credit map, course list and the
/// student record.
class GraduateViewSwitcher extends StatelessWidget {
  const GraduateViewSwitcher({
    super.key,
    required this.view,
    required this.onChanged,
  });

  final GraduateView view;
  final ValueChanged<GraduateView> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: CupertinoSlidingSegmentedControl<GraduateView>(
            groupValue: view,
            children: const {
              GraduateView.credits: Padding(
                padding: EdgeInsets.all(8),
                child: Text('学分地图'),
              ),
              GraduateView.courses: Padding(
                padding: EdgeInsets.all(8),
                child: Text('课程'),
              ),
              GraduateView.profile: Padding(
                padding: EdgeInsets.all(8),
                child: Text('学籍'),
              ),
            },
            onValueChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    ),
  );
}

/// Loading, error and notice lines for one academic part. The student record
/// and the execution report share the same shape.
class GraduatePartNotices extends StatelessWidget {
  const GraduatePartNotices({
    super.key,
    required this.title,
    required this.loading,
    required this.hasSections,
    required this.error,
    required this.notice,
    required this.onRetry,
  });

  final String title;
  final bool loading, hasSections;
  final String? error, notice;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loading || error != null)
        AppleSection(
          header: Text(title),
          children: [
            SectionFeedback(
              loading: loading,
              label: hasSections ? '正在更新$title…' : '正在加载$title…',
              hasData: hasSections,
              error: error,
              onRetry: onRetry,
            ),
          ],
        ),
      if (notice != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            notice!,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 14,
            ),
          ),
        ),
    ],
  );
}

/// Credit progress and the category groups of the school execution report.
class GraduateOverview extends StatelessWidget {
  const GraduateOverview({
    super.key,
    required this.sections,
    required this.expandedSections,
    required this.onExpanded,
    required this.onOpenCategory,
    required this.reportDataExpanded,
    required this.onReportDataExpanded,
  });

  final List<GraduateSection> sections;

  /// Titles of the categories the user unfolded.
  final Set<String> expandedSections;
  final void Function(String title, bool expanded) onExpanded;
  final ValueChanged<GraduateSection> onOpenCategory;
  final bool reportDataExpanded;
  final ValueChanged<bool> onReportDataExpanded;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final summary = sections.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleSection(
          header: const Text('学分进度'),
          footer: const Text('仅统计学校已认定的方案学分，待考核学分单独列出。'),
          children: [
            if (summary.progress != null)
              GraduateCreditProgress(progress: summary.progress!),
            GraduateDisclosure(
              title: '报告原始数据',
              subtitle: summary.title,
              initiallyExpanded: reportDataExpanded,
              onExpanded: onReportDataExpanded,
              children: [
                for (final row in summary.rows)
                  AcademicFactRow(label: row.title, value: row.detail),
              ],
            ),
          ],
        ),
        if (sections.length > 1)
          AppleSection(
            header: const Text('类别与课组'),
            footer: const Text('各类可能包含同一课程，学分不可直接相加。展开查看学校要求和课程。'),
            children: [
              for (final section in sections.skip(1))
                GraduateCategoryRow(
                  section: section,
                  expanded: expandedSections.contains(section.title),
                  onExpanded: (value) => onExpanded(section.title, value),
                  onCourses: () => onOpenCategory(section),
                ),
            ],
          ),
      ],
    );
  }
}

/// The student record fields the school returned.
class GraduateProfileSection extends StatelessWidget {
  const GraduateProfileSection({super.key, required this.section});

  final GraduateSection section;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: Text(section.title),
    children: [
      for (final row in section.rows)
        AcademicFactRow(label: row.title, value: row.detail),
    ],
  );
}

/// The student record lens: the notices, the fields the school returned and
/// the empty state when it returned none.
class GraduateProfileView extends StatelessWidget {
  const GraduateProfileView({
    super.key,
    required this.sections,
    required this.loading,
    required this.hasSections,
    required this.error,
    required this.notice,
    required this.onRetry,
  });

  final List<GraduateSection>? sections;
  final bool loading, hasSections;
  final String? error, notice;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GraduatePartNotices(
        title: '学籍信息',
        loading: loading,
        hasSections: hasSections,
        error: error,
        notice: notice,
        onRetry: onRetry,
      ),
      for (final section in sections ?? <GraduateSection>[])
        GraduateProfileSection(section: section),
      if (sections?.isEmpty == true)
        const AppleSection(
          children: [
            AppleEmptyState(title: '暂无学籍信息', description: '学校未返回可展示的学籍字段。'),
          ],
        ),
    ],
  );
}
