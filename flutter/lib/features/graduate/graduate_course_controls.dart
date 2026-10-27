import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'graduate_models.dart';

/// Search, filters and the result count of the course list. The page owns
/// the filter state; this section only reports it back.
class GraduateCourseControls extends StatelessWidget {
  const GraduateCourseControls({
    super.key,
    required this.search,
    required this.category,
    required this.categories,
    required this.filter,
    required this.resultCount,
    required this.hasCourses,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onFilterChanged,
    required this.onClearFilters,
  });

  final TextEditingController search;
  final String category;
  final List<String> categories;
  final GraduateCourseFilter filter;
  final int resultCount;

  /// Whether the school report returned any course at all.
  final bool hasCourses;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<GraduateCourseFilter> onFilterChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: CupertinoSearchTextField(
          key: const Key('graduate-search'),
          controller: search,
          placeholder: '搜索培养方案课程',
          onChanged: onSearchChanged,
        ),
      ),
      AppleSection(
        children: [
          ApplePickerTile<String>(
            title: '课程类别',
            value: category,
            values: categories,
            label: (value) => value,
            onSelected: onCategoryChanged,
          ),
          ApplePickerTile<GraduateCourseFilter>(
            title: '完成状态',
            value: filter,
            values: GraduateCourseFilter.values,
            label: (value) => value.label,
            onSelected: onFilterChanged,
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        child: Text(
          '$resultCount 条课程记录',
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
      if (resultCount == 0)
        AppleSection(
          children: [
            AppleEmptyState(
              title: hasCourses ? '没有匹配的课程' : '暂无课程记录',
              description: hasCourses ? '调整类别、完成状态或搜索关键词。' : '学校报告未提供可展示的课程。',
              action: hasCourses ? '清除筛选' : null,
              onAction: onClearFilters,
            ),
          ],
        ),
    ],
  );
}
