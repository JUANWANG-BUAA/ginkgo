import 'package:flutter/cupertino.dart';

import 'application/contracts.dart';
import 'application/collection_window.dart';
import 'apple_widgets.dart';
import 'collection_toolbar.dart';

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
