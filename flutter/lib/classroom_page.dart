import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'long_page_scroll.dart';
import 'application/collection_window.dart';
import 'collection_toolbar.dart';
import 'classroom_results.dart';
import 'classroom_detail.dart';
import 'mirror_service.dart';
import 'rules_page.dart';
import 'application/contracts.dart';

class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key, required this.service});
  final AcademicGateway service;
  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  Timer? searchDebounce;
  final search = TextEditingController();
  final scrollController = ScrollController();
  final window = CollectionWindow();
  final resultsAnchor = CollectionAnchor();
  String? selectedBuilding;
  List<({String building, ClassroomRow room})> rows = [];
  void prepare({bool reset = false}) {
    rows = [
      for (final building in response?.buildings ?? <ClassroomBuilding>[])
        if (selectedBuilding == null || building.name == selectedBuilding)
          for (final room in building.rooms)
            (building: building.name, room: room),
    ];
    window.reconcile(
      rows.map((row) => '${row.building}/${row.room.id}'),
      reset: reset,
    );
  }

  void selectPage(int page) {
    setState(() => window.select(page));
    resultsAnchor.reveal(scrollController);
  }

  int campus = 1,
      section = 0,
      minimumFree = 0,
      minimumConsecutive = 0,
      generation = 0;
  ClassroomSort sort = ClassroomSort.name;
  String date = '', today = '', tomorrow = '';
  bool filtersExpanded = false,
      busy = false,
      queried = false,
      initializing = true;
  ClassroomResponse? response;
  String? error;
  String? notice;
  bool get hasFilters =>
      search.text.isNotEmpty ||
      section != 0 ||
      minimumFree != 0 ||
      minimumConsecutive != 0 ||
      sort != ClassroomSort.name;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    scrollController.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      final dates = await widget.service.dates(
        DateTime.now().toUtc().toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        initializing = false;
        if (dates.failure != null) {
          error = failureMessage(dates.failure);
          return;
        }
        date = dates.today;
        today = dates.today;
        tomorrow = dates.tomorrow;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          initializing = false;
          error = failureMessage(null);
        });
      }
    }
  }

  Future<void> query({bool force = false}) async {
    if (date.isEmpty) {
      await initialize();
      return;
    }
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.service.classrooms(
        DemoScope(campus: campus, date: date, forceRefresh: force),
        ClassroomQuery(
          search: search.text,
          section: section,
          minimumFreeSections: minimumFree,
          minimumConsecutiveSections: minimumConsecutive,
          sort: sort,
        ),
      );
      if (!mounted || ticket != generation) return;
      setState(() {
        busy = false;
        if (result.failure != null && result.buildings.isEmpty) {
          error = failureMessage(result.failure);
          return;
        }
        response = result;
        if (!result.buildings.any(
          (building) => building.name == selectedBuilding,
        )) {
          selectedBuilding = null;
        }
        prepare(reset: !force);
        if (!force) resultsAnchor.reveal(scrollController);
        queried = true;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
        if (result.roomCount == 0 && hasFilters) {
          filtersExpanded = true;
        }
      });
    } catch (_) {
      if (!mounted || ticket != generation) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    }
  }

  void searchChanged() {
    searchDebounce?.cancel();
    generation++; // Do not publish a result for the previous search text.
    searchDebounce = Timer(const Duration(milliseconds: 250), filterChanged);
  }

  void filterChanged() {
    if (queried || busy) {
      query();
    } else {
      setState(() {});
    }
  }

  void resetFilters() {
    search.clear();
    section = 0;
    minimumFree = 0;
    minimumConsecutive = 0;
    sort = ClassroomSort.name;
    filterChanged();
  }

  void changeScope({int? newCampus, String? newDate}) {
    searchDebounce?.cancel();
    generation++;
    setState(() {
      campus = newCampus ?? campus;
      date = newDate ?? date;
      queried = false;
      busy = false;
      response = null;
      selectedBuilding = null;
      rows = [];
      window.reconcile([], reset: true);
      error = null;
      search.clear();
      section = 0;
      minimumFree = 0;
      minimumConsecutive = 0;
      sort = ClassroomSort.name;
    });
  }

  Future<void> pickDate() async {
    var selected = DateTime.parse(date);
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
    if (!mounted) return;
    final value =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    if (date != value) {
      changeScope(newDate: value);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: LongPageScroll(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        key: const Key('classroom-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('空教室'),
            border: null,
            trailing: AppleGlassButton(
              label: '刷新空教室',
              onPressed: busy || initializing ? null : () => query(force: true),
              child: busy
                  ? const CupertinoActivityIndicator()
                  : const Icon(CupertinoIcons.refresh, size: 24),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => query(force: true)),
          SliverToBoxAdapter(
            child: Column(
              children: [
                AppleSection(
                  animateSize: false,
                  header: const Text('查询范围'),
                  footer: Text(
                    widget.service.isDemo
                        ? '结果在 5 分钟内优先复用本机样例缓存。'
                        : '结果在 5 分钟内复用本机缓存；刷新失败时保留上次结果。',
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
                          changeScope(newCampus: value);
                        }
                      },
                    ),
                    AppleListTile(
                      title: const Text('日期'),
                      minimumHeight: 56,
                      additionalInfo: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill.resolveFrom(
                            context,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          date.isEmpty
                              ? '正在读取…'
                              : '${date.substring(0, 4)}年${int.parse(date.substring(5, 7))}月${int.parse(date.substring(8, 10))}日',
                          style: TextStyle(
                            color: CupertinoColors.label.resolveFrom(context),
                            fontSize: 17,
                          ),
                        ),
                      ),
                      onTap: busy || date.isEmpty ? null : pickDate,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          shortcut('今天', today),
                          const SizedBox(width: 12),
                          shortcut('明天', tomorrow),
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
                      onTap: busy || initializing ? null : () => query(),
                    ),
                  ],
                ),
                AppleSection(
                  animateSize: false,
                  footer: hasFilters && queried
                      ? Text('筛选后共 ${response?.roomCount ?? 0} 间教室。')
                      : null,
                  children: [
                    AppleListTile(
                      title: const Text('筛选与排序'),
                      trailing: Icon(
                        filtersExpanded
                            ? CupertinoIcons.chevron_down
                            : CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                      onTap: () =>
                          setState(() => filtersExpanded = !filtersExpanded),
                    ),
                    if (filtersExpanded) ...[
                      picker<int>(
                        '空闲节次',
                        section,
                        [for (var n = 0; n <= 14; n++) n],
                        (n) => n == 0 ? '任意节次' : '第 $n 节',
                        (n) {
                          section = n;
                        },
                      ),
                      picker<int>(
                        '最少空闲',
                        minimumFree,
                        [0, 3, 5, 8],
                        (n) => n == 0 ? '不限制' : '至少 $n 节',
                        (n) {
                          minimumFree = n;
                        },
                      ),
                      picker<int>(
                        '连续空闲',
                        minimumConsecutive,
                        [0, 2, 4],
                        (n) => n == 0 ? '不限制' : '至少 $n 节',
                        (n) {
                          minimumConsecutive = n;
                        },
                      ),
                      picker<ClassroomSort>(
                        '排序',
                        sort,
                        ClassroomSort.values,
                        (value) => switch (value) {
                          ClassroomSort.name => '教室名称',
                          ClassroomSort.availability => '空闲节数优先',
                          ClassroomSort.consecutive => '连续空闲优先',
                        },
                        (value) {
                          sort = value;
                        },
                      ),
                    ],
                  ],
                ),
                if (notice != null && response == null)
                  AppleSection(
                    animateSize: false,
                    children: [
                      AppleListTile(
                        key: const Key('classroom-stale-notice'),
                        leading: const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: CupertinoColors.systemOrange,
                          size: 20,
                        ),
                        title: Text(notice!),
                      ),
                    ],
                  ),
                if (error != null && response == null)
                  AppleSection(
                    animateSize: false,
                    children: [
                      AppleEmptyState(
                        title: error!,
                        description: response == null
                            ? '请调整条件或重新查询。'
                            : '保留上次查询结果。',
                        error: true,
                        action: '重试',
                        onAction: () => query(),
                      ),
                    ],
                  ),
                if (busy || initializing)
                  AppleSection(
                    animateSize: false,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CupertinoActivityIndicator(),
                            const SizedBox(width: 10),
                            Text(initializing ? '正在读取学校日期…' : '正在查询空教室…'),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (!queried && error == null)
                  AppleSection(
                    animateSize: false,
                    children: [
                      AppleEmptyState(
                        title: '选择范围后查询',
                        description: '查询结果来自学校当天公布的空闲安排，不会占用或预订教室。',
                      ),
                    ],
                  )
                else if (response case final result? when queried) ...[
                  AppleSection(
                    animateSize: false,
                    children: [
                      if (result.fetchedAt != null)
                        AppleListTile(
                          title: const Text('查询时间'),
                          additionalInfo: Text(
                            result.fetchedAt!
                                .substring(0, 16)
                                .replaceFirst('T', ' '),
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
                          widget.service.isDemo
                              ? (result.fromCache ? '本机样例缓存' : '合成样例')
                              : (result.fromCache ? '本机缓存' : '学校实时数据'),
                        ),
                      ),
                      if (hasFilters)
                        AppleListTile(
                          title: Text(
                            '清除筛选',
                            style: TextStyle(
                              color: CupertinoTheme.of(context).primaryColor,
                            ),
                          ),
                          onTap: resetFilters,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          resultsAnchor.sliver,
          if (response != null)
            PinnedHeaderSliver(
              child: ClassroomResultsHeader(
                search: search,
                buildings: response!.buildings,
                window: window,
                busy: busy,
                error: error ?? notice,
                onRetry: () => query(force: true),
                selectedBuilding: selectedBuilding,
                onSearch: searchChanged,
                onClear: () {
                  searchDebounce?.cancel();
                  search.clear();
                  filterChanged();
                },
                onBuilding: (value) {
                  setState(() {
                    selectedBuilding = value;
                    prepare(reset: true);
                  });
                  resultsAnchor.reveal(scrollController);
                },
                onFilters: () {
                  setState(() => filtersExpanded = true);
                  scrollController.jumpTo(0);
                },
                onPage: selectPage,
              ),
            ),
          if (response != null && rows.isEmpty)
            const SliverToBoxAdapter(
              child: AppleSection(
                animateSize: false,
                children: [
                  AppleEmptyState(
                    title: '没有符合条件的空教室',
                    description: '请调整日期、楼栋、节次或筛选条件。',
                  ),
                ],
              ),
            ),
          SliverList.builder(
            itemCount: window.end - window.start,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              final index = rows.indexWhere(
                (row) =>
                    'classroom-room-${row.building}-${row.room.id}' ==
                    key.value,
              );
              return index >= window.start && index < window.end
                  ? index - window.start
                  : null;
            },
            itemBuilder: (context, index) {
              final row = rows[window.start + index];
              return ClassroomResultTile(
                key: ValueKey('classroom-room-${row.building}-${row.room.id}'),
                room: row.room,
                building: row.building,
                heading:
                    index == 0 ||
                    rows[window.start + index - 1].building != row.building,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) =>
                        ClassroomDetail(room: row.room, building: row.building),
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                  child: Text(
                    widget.service.isDemo
                        ? '离线合成样例，不连接学校账号；日期与校区用于演示查询流程。'
                        : '真实账号只读数据；刷新失败时保留上次查询结果。',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => RulesPage(service: widget.service),
                    ),
                  ),
                  child: const Text('查看共享规则示例', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget shortcut(String title, String value) => CupertinoButton.tinted(
    key: Key('classroom-shortcut-$title'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    minimumSize: const Size(44, 36),
    borderRadius: BorderRadius.circular(24),
    onPressed: busy || value.isEmpty
        ? null
        : () {
            if (date != value) {
              changeScope(newDate: value);
            }
          },
    child: Text(title, style: const TextStyle(fontSize: 17)),
  );

  Widget picker<T>(
    String title,
    T value,
    List<T> values,
    String Function(T) label,
    void Function(T) update,
  ) => ApplePickerTile<T>(
    title: title,
    value: value,
    values: values,
    label: label,
    onSelected: (selected) {
      update(selected);
      filterChanged();
    },
  );
}
