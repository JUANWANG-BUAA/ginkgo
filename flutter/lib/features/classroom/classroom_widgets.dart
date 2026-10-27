import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/collection_window.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/collection_toolbar.dart';

/// Pinned controls above the classroom results: search, building filter,
/// local pagination and the stale-result notice. Pagination is presentation
/// only and never triggers an upstream write.
class ClassroomResultsHeader extends StatelessWidget {
  const ClassroomResultsHeader({
    super.key,
    required this.search,
    required this.buildings,
    required this.window,
    required this.busy,
    required this.onSearch,
    required this.onClear,
    required this.onBuilding,
    required this.onFilters,
    required this.onPage,
    this.selectedBuilding,
    this.error,
    this.onRetry,
  });
  final TextEditingController search;
  final List<ClassroomBuilding> buildings;
  final CollectionWindow window;
  final bool busy;
  final String? selectedBuilding, error;
  final VoidCallback? onRetry;
  final VoidCallback onSearch, onClear, onFilters;
  final ValueChanged<String?> onBuilding;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => CollectionQuerySurface(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CupertinoSearchTextField(
            key: const Key('classroom-search'),
            controller: search,
            placeholder: '搜索楼栋或教室',
            onChanged: (_) => onSearch(),
            onSuffixTap: onClear,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (anchor) => CupertinoButton(
                  key: const Key('classroom-building-picker'),
                  onPressed: busy
                      ? null
                      : () async {
                          final value = await choose<int>(
                            anchor,
                            '选择楼栋',
                            List.generate(
                              buildings.length + 1,
                              (index) => index,
                            ),
                            (index) =>
                                index == 0 ? '全部楼栋' : buildings[index - 1].name,
                            selected: selectedBuilding == null
                                ? 0
                                : buildings.indexWhere(
                                        (item) => item.name == selectedBuilding,
                                      ) +
                                      1,
                          );
                          if (!anchor.mounted || value == null) return;
                          onBuilding(
                            value == 0 ? null : buildings[value - 1].name,
                          );
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.building_2_fill, size: 17),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          selectedBuilding ?? '全部楼栋',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_down, size: 11),
                    ],
                  ),
                ),
              ),
            ),
            CupertinoButton(
              key: const Key('classroom-open-filters'),
              onPressed: onFilters,
              child: const Row(
                children: [
                  Icon(CupertinoIcons.slider_horizontal_3, size: 17),
                  SizedBox(width: 6),
                  Text('筛选'),
                ],
              ),
            ),
          ],
        ),
        CollectionToolbar(
          window: window,
          unit: '间教室',
          statusKey: const Key('classroom-stale-notice'),
          error: error,
          onRetry: onRetry,
          busy: busy,
          onPageChanged: onPage,
        ),
      ],
    ),
  );
}

/// One room in the result list. The building name is only rendered as a
/// heading for the first row of its group.
class ClassroomResultTile extends StatelessWidget {
  const ClassroomResultTile({
    super.key,
    required this.room,
    required this.building,
    required this.heading,
    required this.onTap,
  });
  final ClassroomRow room;
  final String building;
  final bool heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              building,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator
                    .resolveFrom(context)
                    .withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: AppleListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right, size: 22),
            title: Text(
              room.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${room.sections.length} 节空闲 · 最长连续 ${room.longestRun} 节',
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: onTap,
          ),
        ),
      ],
    ),
  );
}

/// Availability of every section of one room. The grid mirrors what the
/// school published; an unmarked section is never treated as confirmed busy.
class ClassroomSectionStates extends StatelessWidget {
  const ClassroomSectionStates({super.key, required this.states});
  final List<SectionState> states;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
        final columns = (constraints.maxWidth / (90 * textScale)).floor().clamp(
          1,
          6,
        );
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final section in states)
              Semantics(
                label:
                    '第 ${section.number} 节，${section.available ? '空闲' : '未标为空闲'}',
                excludeSemantics: true,
                child: Container(
                  width: width,
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color:
                        (section.available
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemGrey)
                            .resolveFrom(context)
                            .withValues(alpha: 0.10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        section.available
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.minus_circle,
                        size: 14,
                        color: section.available
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '第 ${section.number} 节',
                        style: TextStyle(
                          fontSize: 13,
                          color: section.available
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.secondaryLabel.resolveFrom(
                                  context,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Shortcut to today or tomorrow. Disabled until the school date is known.
class ClassroomShortcutButton extends StatelessWidget {
  const ClassroomShortcutButton({
    super.key,
    required this.title,
    required this.value,
    required this.onSelected,
    this.enabled = true,
  });
  final String title;
  final String value;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => CupertinoButton.tinted(
    key: Key('classroom-shortcut-$title'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    minimumSize: const Size(44, 36),
    borderRadius: BorderRadius.circular(24),
    onPressed: !enabled || value.isEmpty ? null : () => onSelected(value),
    child: Text(title, style: const TextStyle(fontSize: 17)),
  );
}

/// One filter row backed by a picker sheet. The page applies the value and
/// reissues the query, so the filter never owns transport state.
class ClassroomFilterPicker<T> extends StatelessWidget {
  const ClassroomFilterPicker({
    super.key,
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onSelected,
  });
  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => ApplePickerTile<T>(
    title: title,
    value: value,
    values: values,
    label: label,
    onSelected: onSelected,
  );
}
