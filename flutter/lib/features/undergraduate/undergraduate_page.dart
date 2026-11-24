import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/academic_widgets.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/feature_intro.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

/// 本科生教务中心（BYXT 课表、本科考试安排、学分成绩总览与教务快捷入口）。
///
/// 复用既有只读 `AcademicGateway`（BYXT 课表/考试 + buaascore 成绩），不新增写操作；
/// 若当前登录账号为研究生，则清晰提示身份差异并提供一键跳转研究生教务。
class UndergraduatePage extends StatefulWidget {
  const UndergraduatePage({
    super.key,
    required this.service,
    this.onOpenFeature,
  });

  final AcademicGateway service;
  final ValueChanged<String>? onOpenFeature;

  @override
  State<UndergraduatePage> createState() => _UndergraduatePageState();
}

class _UndergraduatePageState extends State<UndergraduatePage> {
  static const _graduateTermPattern = r'^\d{5}$';
  static const double _hairline = 0.75;

  ScheduleResponse? _schedule;
  GradeResponse? _grades;
  List<ScheduleTerm> _terms = const [];
  String? _selectedTerm;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _serial = 0;

  bool get _looksGraduateTerm =>
      _schedule != null &&
      RegExp(_graduateTermPattern).hasMatch(_schedule!.termId.trim());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UndergraduatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _serial++;
      _schedule = null;
      _grades = null;
      _terms = const [];
      _selectedTerm = null;
      _error = null;
      _notice = null;
      _busy = false;
      _load();
    }
  }

  Future<void> _load({bool force = false, String? termId}) async {
    final serial = ++_serial;
    final requestedTerm = termId ?? _selectedTerm;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final scheduleFuture = widget.service.schedule(
        termId: requestedTerm,
        forceRefresh: force,
      );
      final gradeFuture = widget.service.grades(
        termCode: requestedTerm,
        forceRefresh: force,
      );
      final results = await Future.wait<Object>([scheduleFuture, gradeFuture]);
      if (!mounted || serial != _serial) return;
      final schedule = results[0] as ScheduleResponse;
      final grades = results[1] as GradeResponse;
      setState(() {
        _busy = false;
        if (schedule.failure != null &&
            schedule.termId.isEmpty &&
            grades.failure != null &&
            grades.fetchedAt == null) {
          _error = failureMessage(schedule.failure ?? grades.failure);
          return;
        }
        if (schedule.termId.isNotEmpty || schedule.failure == null) {
          _schedule = schedule;
          if (schedule.terms.isNotEmpty) {
            _terms = schedule.terms;
          }
          _selectedTerm = schedule.termId.isNotEmpty
              ? schedule.termId
              : _selectedTerm;
        }
        if (grades.fetchedAt != null || grades.failure == null) {
          _grades = grades;
        }
        final partialFailure = schedule.failure ?? grades.failure;
        _notice = partialFailure == null
            ? null
            : '${failureMessage(partialFailure)}，已展示可用教务数据。';
      });
    } catch (_) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _busy = false;
        _error = failureMessage(null);
      });
    }
  }

  String _termName(String? id) {
    if (id == null || id.isEmpty) return '当前学期';
    for (final term in _terms) {
      if (term.id == id) return term.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalInset = ((MediaQuery.sizeOf(context).width - 900) / 2)
        .clamp(0.0, double.infinity);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('undergraduate-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('本科生教务'),
            section: '学业 · BYXT',
            subtitle: '本科课表、考试安排、成绩绩点与教务快捷入口',
            icon: CupertinoIcons.rosette,
            border: null,
            trailing: AppleToolbarButton(
              label: '刷新本科教务',
              busy: _busy,
              onPressed: _busy ? null : () => _load(force: true),
              child: _busy
                  ? const GinkgoActivity(size: GinkgoSpacing.pageInset)
                  : const Icon(CupertinoIcons.refresh),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => _load(force: true)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalInset),
            sliver: SliverList.list(
              children: [
                if (_terms.length > 1) _termPicker(),
                if (_notice != null)
                  AppleSection(
                    children: [
                      AppleListTile(
                        leading: Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: AppleDesign.statusPending.resolveFrom(context),
                        ),
                        title: Text(_notice!),
                      ),
                    ],
                  ),
                if (_error != null && _schedule == null && _grades == null)
                  AppleSection(
                    children: [
                      AppleEmptyState(
                        title: _error!,
                        description: '请检查网络连接或会话状态后重试。',
                        error: true,
                        action: '重试',
                        onAction: () => _load(force: true),
                      ),
                    ],
                  )
                else if (_busy && _schedule == null && _grades == null)
                  const AppleSection(
                    children: [GinkgoLoadingView(label: '正在读取本科教务信息…')],
                  )
                else ...[
                  _buildAcademicSummary(context),
                  if (_looksGraduateTerm) _buildGraduateNotice(context),
                  _buildExamsSection(context),
                  _buildQuickActionsSection(context),
                ],
                const SizedBox(height: GinkgoSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _termPicker() => AppleSection(
    children: [
      ApplePickerTile<String>(
        title: '学期',
        value: _selectedTerm ?? _terms.first.id,
        values: _terms.map((t) => t.id).toList(growable: false),
        label: _termName,
        onSelected: (id) {
          if (id == _selectedTerm) return;
          setState(() => _selectedTerm = id);
          _load(force: true, termId: id);
        },
      ),
    ],
  );

  Widget _buildAcademicSummary(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final schedule = _schedule;
    final grades = _grades;
    final gpa = grades?.summary.gradePointAverage;
    final avg = grades?.summary.weightedAverage;
    final credits = grades?.summary.creditTotal;
    final courseCount = schedule?.courses.length ?? 0;
    final examCount = schedule?.exams.length ?? 0;

    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: dark ? 0.45 : 0.35);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final accent = _looksGraduateTerm
        ? AppleDesign.statusPending.resolveFrom(context)
        : GinkgoColors.resourceBlue;

    return Padding(
      key: const Key('undergraduate-dashboard'),
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.md,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(color: border, width: _hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(GinkgoSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        _termName(_selectedTerm),
                        if (schedule != null && schedule.weekNumber > 0)
                          '第 ${schedule.weekNumber} 周',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.headline.copyWith(
                        color: labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: GinkgoSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(GinkgoRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GinkgoSpacing.sm,
                        vertical: GinkgoSpacing.xs,
                      ),
                      child: Text(
                        _looksGraduateTerm ? '研究生源兼容' : 'BYXT 本科',
                        style: GinkgoTypography.caption2.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.md),
              AcademicMetricGrid(
                children: [
                  AcademicMetric(
                    label: gpa != null ? '平均绩点' : '加权平均',
                    value: gpa != null
                        ? 'GPA ${gpa.toStringAsFixed(2)}'
                        : avg != null
                        ? avg.toStringAsFixed(1)
                        : '暂未出分',
                    prominent: true,
                  ),
                  AcademicMetric(label: '本周课程', value: '$courseCount 节'),
                  AcademicMetric(label: '学期考试', value: '$examCount 场'),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.sm),
              Text(
                [
                  if (credits != null && credits > 0)
                    '已出分学分 ${academicNumber(credits)}',
                  grades?.fetchedAt != null
                      ? '更新于 ${schoolTimestampLabel(grades!.fetchedAt)}'
                      : (widget.service.isDemo ? '离线演示数据' : '实时只读'),
                ].join(' · '),
                style: GinkgoTypography.caption2.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraduateNotice(BuildContext context) => AppleSection(
    children: [
      AppleListTile(
        key: const Key('undergraduate-graduate-hint'),
        leading: Icon(
          CupertinoIcons.info_circle_fill,
          color: AppleDesign.statusPending.resolveFrom(context),
        ),
        title: const Text('当前账号已自动使用研究生课表源'),
        subtitle: const Text('本科考试接口仅对本科生开放，研究生学籍与学分请前往研究生教务。'),
        trailing: widget.onOpenFeature != null
            ? const CupertinoListTileChevron()
            : null,
        onTap: widget.onOpenFeature == null
            ? null
            : () => widget.onOpenFeature!('graduate'),
      ),
    ],
  );

  Widget _buildExamsSection(BuildContext context) {
    final exams = _schedule?.exams ?? const <ScheduleExam>[];
    return AppleSection(
      header: const FeatureSectionTitle(
        '本科考试安排',
        icon: CupertinoIcons.doc_checkmark_fill,
        color: GinkgoColors.accent,
      ),
      footer: const Text('数据来自 BYXT 考试接口；考场与座号请以教务处最终通知为准。'),
      children: exams.isEmpty
          ? [
              AppleEmptyState(
                icon: CupertinoIcons.calendar_badge_minus,
                title: _looksGraduateTerm ? '本科考试接口未对研究生开放' : '本学期暂无考试安排',
                description: _looksGraduateTerm
                    ? '当前账号为研究生课表源，可在课表页查看日程或前往研究生教务。'
                    : '教务系统发布考场与座号后将自动在此汇总显示。',
              ),
            ]
          : [for (final exam in exams) _ExamTile(exam: exam)],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) => AppleSection(
    header: const FeatureSectionTitle(
      '本科教务常用功能',
      icon: CupertinoIcons.square_grid_2x2_fill,
      color: GinkgoColors.resourceBlue,
    ),
    children: [
      if (widget.onOpenFeature != null) ...[
        AppleListTile(
          key: const Key('undergrad-open-schedule'),
          leading: const Icon(
            CupertinoIcons.calendar,
            color: GinkgoColors.resourceBlue,
          ),
          title: const Text('本科周课表与节次'),
          subtitle: const Text('切换学期周次、检索课程与教室'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => widget.onOpenFeature!('schedule'),
        ),
        AppleListTile(
          key: const Key('undergrad-open-grades'),
          leading: const Icon(
            CupertinoIcons.chart_bar_alt_fill,
            color: GinkgoColors.resourcePurple,
          ),
          title: const Text('课程成绩与绩点明细'),
          subtitle: const Text('按学期核对成绩、学分与加权均分'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => widget.onOpenFeature!('grades'),
        ),
        AppleListTile(
          key: const Key('undergrad-open-bykc'),
          leading: const Icon(
            CupertinoIcons.book_solid,
            color: GinkgoColors.resourceTeal,
          ),
          title: const Text('博雅课程目录'),
          subtitle: const Text('查看可选博雅讲座与报名时间'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => widget.onOpenFeature!('bykc'),
        ),
        AppleListTile(
          key: const Key('undergrad-open-evaluation'),
          leading: const Icon(
            CupertinoIcons.checkmark_rectangle,
            color: GinkgoColors.resourceTeal,
          ),
          title: const Text('教学评价完成度'),
          subtitle: const Text('只读核对本学期未评课程进度'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => widget.onOpenFeature!('teaching-evaluation'),
        ),
        AppleListTile(
          key: const Key('undergrad-open-homework'),
          leading: const Icon(
            CupertinoIcons.doc_text,
            color: GinkgoColors.accent,
          ),
          title: const Text('SPOC 课程作业'),
          subtitle: const Text('追踪截止倒计时与个人提交进度'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => widget.onOpenFeature!('homework'),
        ),
        AppleListTile(
          key: const Key('undergrad-open-learning'),
          leading: const Icon(
            CupertinoIcons.book_circle,
            color: GinkgoColors.resourceBlue,
          ),
          title: const Text('SPOC 课程资料与公告'),
          subtitle: const Text('浏览课程公告、课件资料与测验'),
          trailing: const CupertinoListTileChevron(),
          onTap: () => widget.onOpenFeature!('learning'),
        ),
      ],
    ],
  );
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.exam});

  final ScheduleExam exam;

  @override
  Widget build(BuildContext context) {
    final timeLine = [
      if (exam.examDate?.isNotEmpty == true) exam.examDate!,
      if (exam.startTime?.isNotEmpty == true && exam.endTime?.isNotEmpty == true)
        '${exam.startTime}-${exam.endTime}'
      else if (exam.examTimeDescription?.isNotEmpty == true)
        exam.examTimeDescription!,
    ].join(' · ');
    final placeLine = [
      if (exam.examPlace?.isNotEmpty == true) exam.examPlace!,
      if (exam.examSeatNo?.isNotEmpty == true) '座号 ${exam.examSeatNo!}',
      if (exam.examType?.isNotEmpty == true) exam.examType!,
    ].join(' · ');

    return AppleListTile(
      leading: const Icon(
        CupertinoIcons.clock_fill,
        color: GinkgoColors.accent,
      ),
      title: Text(exam.courseName),
      subtitle: Text(
        [
          if (timeLine.isNotEmpty) timeLine,
          if (placeLine.isNotEmpty) placeLine,
        ].join('\n'),
      ),
      trailing: exam.week != null
          ? GinkgoBadge(
              label: '第 ${exam.week} 周',
              icon: CupertinoIcons.calendar,
            )
          : null,
    );
  }
}
