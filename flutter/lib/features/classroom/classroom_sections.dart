import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'classroom_models.dart';
import 'classroom_widgets.dart';

/// Campus, day and the query entry point. The school date is read once by
/// the page; this section only reports the current scope and owns the day
/// picker.
class ClassroomScopeSection extends StatelessWidget {
  const ClassroomScopeSection({
    super.key,
    required this.campus,
    required this.date,
    required this.today,
    required this.tomorrow,
    required this.busy,
    required this.initializing,
    required this.isDemo,
    required this.onCampusChanged,
    required this.onDateChanged,
    required this.onShortcutDate,
    required this.onQuery,
  });
  final int campus;
  final String date, today, tomorrow;
  final bool busy, initializing, isDemo;
  final ValueChanged<int> onCampusChanged;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onShortcutDate;
  final VoidCallback onQuery;

  Future<void> pickDate(BuildContext context) async {
    final selected = await showClassroomDatePicker(
      context,
      DateTime.parse(date),
    );
    if (!context.mounted || selected == null) return;
    onDateChanged(schoolDateString(selected));
  }

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    header: const Text('查询范围'),
    footer: Text(
      isDemo ? '结果在 5 分钟内优先复用本机样例缓存。' : '结果在 5 分钟内复用本机缓存；刷新失败时保留上次结果。',
    ),
    children: [
      ApplePickerTile<int>(
        title: '校区',
        value: campus,
        values: const [1, 2, 3],
        label: (n) => const {1: '学院路', 2: '沙河', 3: '杭州'}[n]!,
        enabled: !busy,
        onSelected: (value) {
          if (value != campus) {
            onCampusChanged(value);
          }
        },
      ),
      AppleListTile(
        title: const Text('日期'),
        minimumHeight: 56,
        additionalInfo: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            date.isEmpty ? '正在读取…' : _classroomDateLabel(date),
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 17,
            ),
          ),
        ),
        onTap: busy || date.isEmpty ? null : () => pickDate(context),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClassroomShortcutButton(
              title: '今天',
              value: today,
              enabled: !busy,
              onSelected: onShortcutDate,
            ),
            const SizedBox(width: 12),
            ClassroomShortcutButton(
              title: '明天',
              value: tomorrow,
              enabled: !busy,
              onSelected: onShortcutDate,
            ),
          ],
        ),
      ),
      AppleListTile(
        title: Text(
          '查询空教室',
          style: TextStyle(
            color: busy || initializing
                ? CupertinoColors.inactiveGray
                : CupertinoTheme.of(context).primaryColor,
          ),
        ),
        leading: Icon(
          CupertinoIcons.search,
          color: CupertinoTheme.of(context).primaryColor,
          size: 20,
        ),
        onTap: busy || initializing ? null : onQuery,
      ),
    ],
  );
}

/// Collapsible filter and sort panel. The page owns the applied selection and
/// reissues the query once per change.
class ClassroomFilterSection extends StatelessWidget {
  const ClassroomFilterSection({
    super.key,
    required this.filters,
    required this.expanded,
    required this.hasFilters,
    required this.queried,
    required this.roomCount,
    required this.onToggle,
    required this.onChanged,
  });
  final ClassroomFilters filters;
  final bool expanded;
  final bool hasFilters, queried;
  final int roomCount;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    footer: hasFilters && queried ? Text('筛选后共 $roomCount 间教室。') : null,
    children: [
      AppleListTile(
        title: const Text('筛选与排序'),
        trailing: Icon(
          expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
          size: 16,
          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
        ),
        onTap: onToggle,
      ),
      if (expanded) ...[
        ClassroomFilterPicker<int>(
          title: '空闲节次',
          value: filters.section,
          values: [for (var n = 0; n <= 14; n++) n],
          label: (n) => n == 0 ? '任意节次' : '第 $n 节',
          onSelected: (value) {
            filters.section = value;
            onChanged();
          },
        ),
        ClassroomFilterPicker<int>(
          title: '最少空闲',
          value: filters.minimumFree,
          values: const [0, 3, 5, 8],
          label: (n) => n == 0 ? '不限制' : '至少 $n 节',
          onSelected: (value) {
            filters.minimumFree = value;
            onChanged();
          },
        ),
        ClassroomFilterPicker<int>(
          title: '连续空闲',
          value: filters.minimumConsecutive,
          values: const [0, 2, 4],
          label: (n) => n == 0 ? '不限制' : '至少 $n 节',
          onSelected: (value) {
            filters.minimumConsecutive = value;
            onChanged();
          },
        ),
        ClassroomFilterPicker<ClassroomSort>(
          title: '排序',
          value: filters.sort,
          values: ClassroomSort.values,
          label: (value) => switch (value) {
            ClassroomSort.name => '教室名称',
            ClassroomSort.availability => '空闲节数优先',
            ClassroomSort.consecutive => '连续空闲优先',
          },
          onSelected: (value) {
            filters.sort = value;
            onChanged();
          },
        ),
      ],
    ],
  );
}

/// Provenance of the shown results: when they were read, how many rooms they
/// cover and whether they come from the local cache.
class ClassroomResultSummarySection extends StatelessWidget {
  const ClassroomResultSummarySection({
    super.key,
    required this.result,
    required this.isDemo,
    required this.hasFilters,
    required this.onClearFilters,
  });
  final ClassroomResponse result;
  final bool isDemo, hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => AppleSection(
    animateSize: false,
    children: [
      if (result.fetchedAt != null)
        AppleListTile(
          title: const Text('查询时间'),
          additionalInfo: Text(
            result.fetchedAt!.substring(0, 16).replaceFirst('T', ' '),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      AppleListTile(
        title: const Text('结果'),
        additionalInfo: Semantics(
          liveRegion: true,
          child: Text(
            '${result.roomCount} 间 · ${result.buildingCount} 栋',
            key: const Key('classroom-summary'),
          ),
        ),
      ),
      AppleListTile(
        title: const Text('数据来源'),
        additionalInfo: Text(
          isDemo
              ? (result.fromCache ? '本机样例缓存' : '合成样例')
              : (result.fromCache ? '本机缓存' : '学校实时数据'),
        ),
      ),
      if (hasFilters)
        AppleListTile(
          title: Text(
            '清除筛选',
            style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
          ),
          onTap: onClearFilters,
        ),
    ],
  );
}

/// Closing note of the page: the data source boundary and the shared rule
/// examples.
class ClassroomFooterNote extends StatelessWidget {
  const ClassroomFooterNote({
    super.key,
    required this.isDemo,
    required this.onOpenRules,
  });
  final bool isDemo;
  final VoidCallback onOpenRules;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
        child: Text(
          isDemo ? '离线合成样例，不连接学校账号；日期与校区用于演示查询流程。' : '真实账号只读数据；刷新失败时保留上次查询结果。',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
      CupertinoButton(
        onPressed: onOpenRules,
        child: const Text('查看共享规则示例', style: TextStyle(fontSize: 13)),
      ),
      const SizedBox(height: 24),
      const SizedBox(height: 96),
    ],
  );
}

/// Picks one day inside the supported range. The picked day is reported to
/// the caller, which decides whether the query scope changes.
Future<DateTime?> showClassroomDatePicker(
  BuildContext context,
  DateTime initial,
) async {
  var selected = initial;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => Container(
      height: 310,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                minimumYear: 2020,
                maximumYear: 2100,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return selected;
}

/// Renders a school day as a readable Chinese date.
String _classroomDateLabel(String date) =>
    '${date.substring(0, 4)}年${int.parse(date.substring(5, 7))}月${int.parse(date.substring(8, 10))}日';
