import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/collection_window.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/tasks/rules_page.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/collection_toolbar.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'classroom_models.dart';
import 'classroom_results.dart';
import 'classroom_sections.dart';
import 'classroom_status.dart';
import 'classroom_widgets.dart';

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
  final filters = ClassroomFilters();
  String? selectedBuilding;
  List<ClassroomRoomRow> rows = [];
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

  int campus = 1, generation = 0;
  String date = '', today = '', tomorrow = '';
  bool filtersExpanded = false,
      busy = false,
      queried = false,
      initializing = true;
  ClassroomResponse? response;
  String? error;
  String? notice;
  bool get hasFilters => search.text.isNotEmpty || filters.isActive;

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
          section: filters.section,
          minimumFreeSections: filters.minimumFree,
          minimumConsecutiveSections: filters.minimumConsecutive,
          sort: filters.sort,
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
    filters.reset();
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
      filters.reset();
    });
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
            section: '空间资源',
            subtitle: '按校区、日期与节次查询空闲教室',
            icon: CupertinoIcons.building_2_fill,
            border: null,
            trailing: AppleGlassButton(
              label: '刷新空教室',
              onPressed: busy || initializing ? null : () => query(force: true),
              child: busy
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh, size: 24),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => query(force: true)),
          SliverToBoxAdapter(
            child: Column(
              children: [
                ClassroomScopeSection(
                  campus: campus,
                  date: date,
                  today: today,
                  tomorrow: tomorrow,
                  busy: busy,
                  initializing: initializing,
                  isDemo: widget.service.isDemo,
                  onCampusChanged: (value) => changeScope(newCampus: value),
                  onDateChanged: (value) {
                    if (date != value) {
                      changeScope(newDate: value);
                    }
                  },
                  onShortcutDate: (value) {
                    if (date != value) {
                      changeScope(newDate: value);
                    }
                  },
                  onQuery: () => query(),
                ),
                ClassroomFilterSection(
                  filters: filters,
                  expanded: filtersExpanded,
                  hasFilters: hasFilters,
                  queried: queried,
                  roomCount: response?.roomCount ?? 0,
                  onToggle: () =>
                      setState(() => filtersExpanded = !filtersExpanded),
                  onChanged: filterChanged,
                ),
                if (notice != null && response == null)
                  ClassroomNoticeTile(notice: notice!),
                if (error != null && response == null)
                  ClassroomMessageState(
                    title: error!,
                    description: '请调整条件或重新查询。',
                    error: true,
                    action: '重试',
                    onAction: () => query(),
                  ),
                if (response == null && (busy || initializing))
                  ClassroomLoadingState(initializing: initializing)
                else if (busy)
                  const ClassroomRefreshingState()
                else if (!queried && error == null)
                  const ClassroomMessageState(
                    title: '选择范围后查询',
                    description: '查询结果来自学校当天公布的空闲安排，不会占用或预订教室。',
                  )
                else if (response case final result? when queried)
                  ClassroomResultSummarySection(
                    result: result,
                    isDemo: widget.service.isDemo,
                    hasFilters: hasFilters,
                    onClearFilters: resetFilters,
                  ),
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
          if (response != null && rows.isEmpty) const ClassroomEmptyResults(),
          ClassroomResultList(rows: rows, window: window),
          SliverToBoxAdapter(
            child: ClassroomFooterNote(
              isDemo: widget.service.isDemo,
              onOpenRules: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => RulesPage(service: widget.service),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
