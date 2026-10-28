import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_context.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/learning_ports.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/infrastructure/learning_file_actions.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'learning_announcement_page.dart';
import 'learning_resource_section.dart';
import 'learning_widgets.dart';

enum LearningCourseTab { resources, announcements, assessments }

class LearningCoursePage extends StatefulWidget {
  const LearningCoursePage({
    super.key,
    required this.course,
    required this.service,
    this.accountId,
    this.saveFile = saveLearningFile,
    this.isOwnerCurrent,
  });
  final LearningCourse course;
  final Object service;
  final String? accountId;
  final LearningFileSaver? saveFile;
  final bool Function()? isOwnerCurrent;
  @override
  State<LearningCoursePage> createState() => _LearningCoursePageState();
}

class _LearningCoursePageState extends State<LearningCoursePage> {
  late RefreshSection<LearningRead<List<CourseAnnouncement>>> announcements;
  late RefreshSection<LearningRead<CourseResourcePage>> resources;
  late RefreshSection<LearningRead<List<CourseAssessment>>> assessments;
  late RefreshSection<LearningRead<List<LearningColumn>>> columns;
  String? announcementColumn, assessmentColumn, linkError;
  List<CourseResource> path = [];
  int page = 1, epoch = 0;
  String resourceQuery = '';
  LearningCourseTab tab = LearningCourseTab.resources;
  late LearningPorts ports = LearningPorts.resolve(widget.service);
  @override
  void initState() {
    super.initState();
    _attach();
  }

  bool current(int e) =>
      mounted && e == epoch && (widget.isOwnerCurrent?.call() ?? true);
  void _changed() {
    if (mounted) setState(() {});
  }

  void _attach() {
    ports = LearningPorts.resolve(widget.service);
    announcements = RefreshSection()..addListener(_changed);
    resources = RefreshSection()..addListener(_changed);
    assessments = RefreshSection()..addListener(_changed);
    columns = RefreshSection()..addListener(_changed);
    _resources();
    if (ports.context != null) _columns();
  }

  void _detach() {
    announcements.dispose();
    resources.dispose();
    assessments.dispose();
    columns.dispose();
  }

  @override
  void didUpdateWidget(covariant LearningCoursePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.course.id != widget.course.id ||
        oldWidget.accountId != widget.accountId) {
      epoch++;
      _detach();
      path = [];
      page = 1;
      resourceQuery = '';
      announcementColumn = null;
      assessmentColumn = null;
      linkError = null;
      tab = LearningCourseTab.resources;
      _attach();
    }
  }

  @override
  void dispose() {
    epoch++;
    _detach();
    super.dispose();
  }

  Future<void> _columns({bool force = false}) async {
    final service = widget.service;
    if (service is! CourseLearningContextGateway) return;
    final e = epoch, target = columns;
    await learningRefresh(
      target,
      () => service.learningColumns(widget.course.id, forceRefresh: force),
      force,
    );
    if (!current(e) || target.error != null) return;
    final rows = target.value?.data ?? [];
    String? selected(String? old, String kind) {
      final options = rows.where((c) => c.kind == kind).toList();
      if (options.any((c) => c.id == old)) return old;
      return options.length == 1 ? options.single.id : null;
    }

    final a = selected(announcementColumn, 'announcement'),
        t = selected(assessmentColumn, 'assessment');
    if (a != announcementColumn) {
      announcements.dispose();
      announcements = RefreshSection()..addListener(_changed);
    }
    if (t != assessmentColumn) {
      assessments.dispose();
      assessments = RefreshSection()..addListener(_changed);
    }
    setState(() {
      announcementColumn = a;
      assessmentColumn = t;
    });
    if (tab == LearningCourseTab.announcements && a != null) {
      await _announcements(force: force);
    }
    if (tab == LearningCourseTab.assessments && t != null) {
      await _assessments(force: force);
    }
  }

  Future<void> _announcements({bool force = false}) {
    final col = announcementColumn;
    final context = ports.context;
    if (context != null) {
      if (col == null) return Future.value();
      return learningRefresh(
        announcements,
        () =>
            context.courseAnnouncementsIn(
              widget.course.id,
              col,
              forceRefresh: force,
            ),
        force,
      );
    }
    final gateway = ports.announcements;
    if (gateway == null) return Future.value();
    return learningRefresh(
      announcements,
      () => gateway.courseAnnouncements(widget.course.id, forceRefresh: force),
      force,
    );
  }

  Future<void> _assessments({bool force = false}) {
    final col = assessmentColumn;
    final context = ports.context;
    if (context != null) {
      if (col == null) return Future.value();
      return learningRefresh(
        assessments,
        () => context.courseAssessmentsIn(
          widget.course.id,
          col,
          forceRefresh: force,
        ),
        force,
      );
    }
    final gateway = ports.assessments;
    if (gateway == null) return Future.value();
    return learningRefresh(
      assessments,
      () => gateway.courseAssessments(widget.course.id, forceRefresh: force),
      force,
    );
  }

  Future<void> _resources({bool force = false}) {
    final ids = path.map((f) => f.id).toList(), p = page;
    final context = ports.context;
    if (context != null) {
      return learningRefresh(
        resources,
        () => context.courseResourcesAt(
          widget.course.id,
          path: ids,
          page: p,
          forceRefresh: force,
        ),
        force,
      );
    }
    final gateway = ports.resources;
    if (gateway == null) return Future.value();
    return learningRefresh(
      resources,
      () => gateway.courseResources(
        widget.course.id,
        folder: ids.isEmpty ? null : ids.single,
        page: p,
        forceRefresh: force,
      ),
      force,
    );
  }

  void _selectTab(LearningCourseTab value) {
    if (tab == value) return;
    setState(() => tab = value);
    if (value == LearningCourseTab.announcements &&
        announcements.value == null &&
        !announcements.loading) {
      _announcements();
    }
    if (value == LearningCourseTab.assessments &&
        assessments.value == null &&
        !assessments.loading) {
      _assessments();
    }
  }

  void _navigate(List<CourseResource> nextPath, int nextPage) {
    epoch++;
    resources.dispose();
    resources = RefreshSection()..addListener(_changed);
    setState(() {
      path = nextPath;
      page = nextPage;
      resourceQuery = '';
    });
    _resources();
  }

  Widget _columnPicker(String title, String kind, String? selected) {
    final options =
        columns.value?.data.where((c) => c.kind == kind).toList() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (columns.value != null && options.isEmpty)
          LearningText('未发现可用$title栏目；不代表没有$title内容'),
        if (options.length > 1 && selected == null)
          LearningText('请选择$title栏目（不自动使用第一项）'),
        for (final c in options.length > 1 ? options : const <LearningColumn>[])
          CupertinoButton(
            key: ValueKey('learning-column-${c.id}'),
            onPressed: () {
              epoch++;
              if (kind == 'announcement') {
                announcements.dispose();
                announcements = RefreshSection()..addListener(_changed);
                setState(() => announcementColumn = c.id);
                _announcements();
              } else {
                assessments.dispose();
                assessments = RefreshSection()..addListener(_changed);
                setState(() => assessmentColumn = c.id);
                _assessments();
              }
            },
            child: Text('${selected == c.id ? '✓ ' : ''}${c.name}'),
          ),
      ],
    );
  }

  Future<void> _showHealth() async {
    final learningContext = ports.context;
    if (learningContext == null) return;
    final e = epoch;
    String content;
    try {
      final health = await learningContext.learningCapabilities(widget.course.id);
      const labels = {
        'unknown': '尚未验证',
        'available': '本会话读取成功',
        'authRequired': '需要认证',
        'temporarilyUnavailable': '暂不可用',
        'protocolChanged': '协议或路径已变化',
        'accessDenied': '访问受限',
      };
      content = [
        '栏目：${labels[health.columns] ?? '尚未验证'}',
        '公告：${labels[health.announcements] ?? '尚未验证'}',
        '资料：${labels[health.resources] ?? '尚未验证'}',
        '测验：${labels[health.assessments] ?? '尚未验证'}',
        '资料下载：${labels[health.resourceDownload] ?? '尚未验证'}',
        '公告附件：${labels[health.announcementDownload] ?? '尚未验证'}',
        '仅依据本会话实际操作，不主动批量探测；尚未验证不等于失效。',
      ].join('\n');
    } catch (_) {
      content = '暂未取得接口状态，不能据此判断学校接口不存在。';
    }
    if (!mounted || !current(e)) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('学习接口状态'),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSource() async {
    final e = epoch;
    if (!await openSchoolLink(widget.course.sourceUrl) && current(e)) {
      setState(() => linkError = schoolLinkError);
    }
  }

  Future<LearningDownload> _download(CourseResource item) {
    final context = ports.context;
    if (context != null) {
      return context.courseResourceDownloadAt(
        widget.course.id,
        item.id,
        path: path.map((f) => f.id).toList(),
        page: page,
      );
    }
    final gateway = ports.resources;
    if (gateway == null) {
      throw StateError('当前服务不支持资料下载');
    }
    return gateway.courseResourceDownload(
      widget.course.id,
      item.id,
      folder: path.isEmpty ? null : path.single.id,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContext = ports.context != null;
    final items =
        resources.value?.data.items
            .where(
              (f) => f.name.toLowerCase().contains(resourceQuery.toLowerCase()),
            )
            .toList() ??
        [];
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('课程详情'),
        previousPageTitle: '学习',
        trailing: hasContext
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                onPressed: _showHealth,
                child: const Icon(
                  CupertinoIcons.info_circle,
                  semanticLabel: '学习接口状态',
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            LearningText(widget.course.name, heading: true),
            if (httpsUri(widget.course.sourceUrl) != null)
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  onPressed: _openSource,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text('前往课程官网'),
                ),
              ),
            if (linkError != null) LearningText(linkError!, warning: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<LearningCourseTab>(
                  groupValue: tab,
                  onValueChanged: (value) {
                    if (value != null) _selectTab(value);
                  },
                  children: const {
                    LearningCourseTab.resources: Text('资料'),
                    LearningCourseTab.announcements: Text('公告'),
                    LearningCourseTab.assessments: Text('测验'),
                  },
                ),
              ),
            ),
            if (hasContext && (columns.loading || columns.error != null))
              AppleSection(
                header: const Text('课程栏目'),
                children: [
                  LearningReadStatus(
                    title: '栏目',
                    section: columns,
                    supported: true,
                    onRefresh: () => _columns(force: true),
                  ),
                ],
              ),
            if (tab == LearningCourseTab.announcements)
              AppleSection(
                header: const Text('公告'),
                children: [
                  if (hasContext &&
                      columns.value?.data
                              .where((c) => c.kind == 'announcement')
                              .length !=
                          1)
                    _columnPicker('公告', 'announcement', announcementColumn),
                  LearningReadStatus(
                    title: '公告',
                    section: announcements,
                    supported: hasContext
                        ? announcementColumn != null
                        : ports.announcements != null,
                    onRefresh: () => _announcements(force: true),
                  ),
                  if (announcements.value case final read?) ...[
                    if (read.data.isEmpty) const LearningText('暂无公告'),
                    for (final a in read.data)
                      AppleListTile(
                        key: ValueKey('learning-announcement-${a.id}'),
                        title: Text(a.title),
                        subtitle: Text(a.publishedAt ?? '发布时间未知'),
                        onTap: () {
                          final e = epoch;
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => LearningAnnouncementPage(
                                service: widget.service,
                                course: widget.course.id,
                                column: announcementColumn,
                                announcement: a,
                                saveFile: widget.saveFile,
                                isCurrent: () => current(e),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              )
            else if (tab == LearningCourseTab.resources)
              LearningResourceSection(
                path: path,
                page: page,
                items: items,
                resourceQuery: resourceQuery,
                resources: resources,
                supported: hasContext || ports.resources != null,
                hasContext: hasContext,
                saveFile: widget.saveFile,
                contextToken:
                    '${widget.accountId}/${widget.course.id}/${path.map((f) => f.id).join('/')}/$page/$epoch',
                onQueryChanged: (value) =>
                    setState(() => resourceQuery = value),
                onNavigate: _navigate,
                onRefresh: () => _resources(force: true),
                onDownload: _download,
                isCurrent: () => current(epoch),
              )
            else
              AppleSection(
                header: const Text('测验（只读）'),
                footer: const Text('仅展示信息，不开始、作答或提交测验；未知时间或个人得分不会推测。'),
                children: [
                  if (hasContext &&
                      columns.value?.data
                              .where((c) => c.kind == 'assessment')
                              .length !=
                          1)
                    _columnPicker('测验', 'assessment', assessmentColumn),
                  LearningReadStatus(
                    title: '测验',
                    section: assessments,
                    supported: hasContext
                        ? assessmentColumn != null
                        : ports.assessments != null,
                    onRefresh: () => _assessments(force: true),
                  ),
                  if (assessments.value case final read?) ...[
                    if (read.data.isEmpty) const LearningText('暂无测验'),
                    for (final item in read.data)
                      AppleListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '开始：${item.startsAt ?? '未知'}\n截止：${item.dueAt ?? '未知'}\n成绩：${item.score ?? '未知'}',
                        ),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
