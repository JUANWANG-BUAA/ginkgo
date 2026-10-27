import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' as live;
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'graduate_course_controls.dart';
import 'graduate_course_widgets.dart';
import 'graduate_models.dart';
import 'graduate_sections.dart';

export 'graduate_widgets.dart' show GraduateCreditProgress;

typedef GraduateLoader = Future<live.ReadOnlyResponse> Function({
  required bool report,
  required bool forceRefresh,
});

class GraduatePage extends StatefulWidget {
  const GraduatePage({super.key, this.demo = false, this.loader, this.service});
  final bool demo;
  final GraduateLoader? loader;
  final CampusGateway? service;
  @override
  State<GraduatePage> createState() => _GraduatePageState();
}

class _AcademicPart {
  List<GraduateSection>? sections;
  String? error, notice;
  Future<void>? task;
  bool loading = false;
}

class _GraduatePageState extends State<GraduatePage> {
  var status = _AcademicPart(), report = _AcademicPart();
  int generation = 0;
  final search = TextEditingController();
  final scrollController = ScrollController();
  final viewOffsets = <GraduateView, double>{};
  final expandedReportSections = <String>{};
  bool reportDataExpanded = false;
  GraduateView view = GraduateView.credits;
  GraduateCourseFilter courseFilter = GraduateCourseFilter.all;
  String category = '全部类别';
  List<String> categories = ['全部类别'];
  List<GraduateCourseEntry> courses = [], visibleCourses = [];
  bool get busy => status.loading || report.loading;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(GraduatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.loader != widget.loader ||
        oldWidget.demo != widget.demo) {
      generation++;
      status = _AcademicPart();
      report = _AcademicPart();
      courses = [];
      visibleCourses = [];
      categories = ['全部类别'];
      category = '全部类别';
      expandedReportSections.clear();
      reportDataExpanded = false;
      viewOffsets.clear();
      search.clear();
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void filterCourses() {
    final query = search.text.trim().toLowerCase();
    visibleCourses = courses
        .where(
          (entry) =>
              (category == '全部类别' || entry.section == category) &&
              courseFilter.accepts(entry.row) &&
              '${entry.row.title} ${entry.row.detail}'.toLowerCase().contains(
                query,
              ),
        )
        .toList(growable: false);
  }

  void selectView(GraduateView value, {bool fromTop = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (scrollController.hasClients) {
      viewOffsets[view] = scrollController.offset;
    }
    if (fromTop) viewOffsets[value] = 0;
    setState(() => view = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || view != value || !scrollController.hasClients) return;
      final position = scrollController.position;
      scrollController.jumpTo(
        (viewOffsets[value] ?? 0).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  Future<void> load({bool force = false}) => Future.wait([
    _loadPart(status, force: force),
    _loadPart(report, force: force),
  ]);

  Future<void> _loadPart(_AcademicPart part, {bool force = false}) =>
      part.task ??= _fetchPart(
        part,
        force: force,
      ).whenComplete(() => part.task = null);

  Future<void> _fetchPart(_AcademicPart part, {required bool force}) async {
    final requestGeneration = generation;
    setState(() {
      part.loading = true;
      part.error = null;
    });
    try {
      final isReport = identical(part, report);
      final service = widget.service ?? mirrorServiceFor(demo: widget.demo);
      final result = widget.loader != null
          ? await widget.loader!(report: isReport, forceRefresh: force)
          : await service.graduatePart(report: isReport, forceRefresh: force);
      // Decode once on data change, never sort or parse inside build.
      final decoded = graduateReport(result.payload);
      final sections = decoded?.sections;
      if (!mounted || generation != requestGeneration) return;
      setState(() {
        part.error = result.failure == null
            ? null
            : failureMessage(result.failure);
        if (sections != null) {
          part.sections = sections;
          part.notice = decoded?.notice;
          if (isReport) {
            courses = [
              for (final section in sections)
                for (final row in section.rows.where((row) => row.isCourse))
                  GraduateCourseEntry(section.title, row),
            ];
            categories = [
              '全部类别',
              ...courses.map((entry) => entry.section).toSet(),
            ];
            if (!categories.contains(category)) category = '全部类别';
            filterCourses();
          }
        }
      });
    } catch (_) {
      if (mounted && generation == requestGeneration) {
        setState(() => part.error = failureMessage(null));
      }
    } finally {
      if (mounted && generation == requestGeneration) {
        setState(() => part.loading = false);
      }
    }
  }

  void _openCategory(GraduateSection section) {
    setState(() {
      category = section.title;
      courseFilter = GraduateCourseFilter.all;
      search.clear();
      filterCourses();
    });
    selectView(GraduateView.courses, fromTop: true);
  }

  void _clearFilters() => setState(() {
    search.clear();
    category = '全部类别';
    courseFilter = GraduateCourseFilter.all;
    filterCourses();
  });

  @override
  Widget build(BuildContext context) => PageRefreshShortcut(
    onRefresh: busy ? null : () => load(force: true),
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: LongPageScroll(
        controller: scrollController,
        child: CustomScrollView(
          key: const Key('graduate-scroll'),
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            ApplePageHeader(
              largeTitle: const Text('研究生教务'),
              previousPageTitle: '工作台',
              border: null,
              section: '学业',
              subtitle: '学籍、培养方案与研究生学业查询',
              icon: CupertinoIcons.briefcase_fill,
              trailing: AppleGlassButton(
                label: '刷新研究生教务',
                onPressed: busy ? null : () => load(force: true),
                child: busy
                    ? const GinkgoActivity()
                    : const Icon(CupertinoIcons.refresh),
              ),
            ),
            CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
            SliverLayoutBuilder(
              builder: (context, constraints) => SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: ((constraints.crossAxisExtent - 900) / 2).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                sliver: SliverList.list(
                  children: [
                    GraduateViewSwitcher(
                      view: view,
                      onChanged: selectView,
                    ),
                    if (view != GraduateView.profile)
                      GraduatePartNotices(
                        title: '培养方案执行报告',
                        loading: report.loading,
                        hasSections: report.sections != null,
                        error: report.error,
                        notice: report.notice,
                        onRetry: () => _loadPart(report, force: true),
                      ),
                    if (view == GraduateView.profile)
                      GraduateProfileView(
                        sections: status.sections,
                        loading: status.loading,
                        hasSections: status.sections != null,
                        error: status.error,
                        notice: status.notice,
                        onRetry: () => _loadPart(status, force: true),
                      ),
                    if (view == GraduateView.credits) ...[
                      GraduatePartNotices(
                        title: '学籍信息',
                        loading: status.loading,
                        hasSections: status.sections != null,
                        error: status.error,
                        notice: status.notice,
                        onRetry: () => _loadPart(status, force: true),
                      ),
                      if (status.sections
                              ?.expand((section) => section.rows)
                              .firstOrNull
                          case final row?)
                        AppleSection(
                          children: [
                            AppleListTile(
                              title: const Text('学籍信息'),
                              subtitle: Text(row.detail),
                              trailing: const CupertinoListTileChevron(),
                              onTap: () => selectView(GraduateView.profile),
                            ),
                          ],
                        ),
                      if (report.sections != null)
                        SectionReveal(
                          key: const Key('graduate-report-content'),
                          child: GraduateOverview(
                            sections: report.sections!,
                            expandedSections: expandedReportSections,
                            onExpanded: (title, expanded) => setState(() {
                              if (expanded) {
                                expandedReportSections.add(title);
                              } else {
                                expandedReportSections.remove(title);
                              }
                            }),
                            onOpenCategory: _openCategory,
                            reportDataExpanded: reportDataExpanded,
                            onReportDataExpanded: (value) =>
                                reportDataExpanded = value,
                          ),
                        ),
                    ],
                    if (view == GraduateView.courses &&
                        report.sections != null)
                      GraduateCourseControls(
                        search: search,
                        category: category,
                        categories: categories,
                        filter: courseFilter,
                        resultCount: visibleCourses.length,
                        hasCourses: courses.isNotEmpty,
                        onSearchChanged: (_) => setState(filterCourses),
                        onCategoryChanged: (value) => setState(() {
                          category = value;
                          filterCourses();
                        }),
                        onFilterChanged: (value) => setState(() {
                          courseFilter = value;
                          filterCourses();
                        }),
                        onClearFilters: _clearFilters,
                      ),
                  ],
                ),
              ),
            ),
            if (view == GraduateView.courses && report.sections != null)
              SliverLayoutBuilder(
                builder: (context, constraints) => SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ((constraints.crossAxisExtent - 900) / 2).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  sliver: SliverList.builder(
                    itemCount: visibleCourses.length,
                    itemBuilder: (context, index) =>
                        GraduateCourseCard(entry: visibleCourses[index]),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
  );
}
