import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'application/contracts.dart';
import 'application/learning.dart';
import 'application/learning_context.dart';
import 'application/learning_file_actions.dart';
import 'application/refresh_section.dart';
import 'infrastructure/learning_file_actions.dart';
import 'apple_design.dart';
import 'apple_widgets.dart';
import 'loading_widgets.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({
    super.key,
    required this.service,
    this.accountId,
    this.saveFile = saveLearningFile,
  });
  final Object service;
  final String? accountId;
  final LearningFileSaver? saveFile;
  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  late RefreshSection<LearningRead<List<LearningCourse>>> courses;
  String query = '';
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    courses = RefreshSection()..addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool force = false}) {
    final service = widget.service;
    if (service is! LearningCourseGateway) return Future.value();
    return _refresh(
      courses,
      () => service.learningCourses(forceRefresh: force),
      force,
    );
  }

  @override
  void didUpdateWidget(covariant LearningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.accountId != widget.accountId) {
      epoch++;
      query = '';
      courses.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    epoch++;
    courses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        courses.value?.data
            .where(
              (c) => '${c.name} ${c.teacher ?? ''} ${c.term ?? ''}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList() ??
        [];
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('learning-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('SPOC 学习'),
            section: '学业',
            subtitle: '只读查看课程公告、资料与测验信息',
            icon: CupertinoIcons.book_circle,
            trailing: AppleGlassButton(
              label: '刷新课程',
              onPressed:
                  widget.service is LearningCourseGateway && !courses.loading
                  ? () => _load(force: true)
                  : null,
              child: const Icon(CupertinoIcons.refresh),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                key: ValueKey('learning-search-$epoch'),
                placeholder: '搜索已加载课程、教师或学期',
                onChanged: (v) => setState(() => query = v.trim()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ReadStatus(
              title: '课程',
              section: courses,
              supported: widget.service is LearningCourseGateway,
              onRefresh: () => _load(force: true),
            ),
          ),
          if (courses.value != null && rows.isEmpty)
            SliverToBoxAdapter(
              child: _LearningText(query.isEmpty ? '暂无课程' : '没有匹配的已加载课程'),
            ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final course = rows[i], e = epoch;
              return AppleSection(
                children: [
                  AppleListTile(
                    key: ValueKey('learning-course-${course.id}'),
                    title: Text(course.name),
                    subtitle: Text(
                      [
                        if (_present(course.teacher)) course.teacher!,
                        if (_present(course.term)) course.term!,
                      ].join(' · '),
                    ),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                    ),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => LearningCoursePage(
                          course: course,
                          service: widget.service,
                          accountId: widget.accountId,
                          saveFile: widget.saveFile,
                          isOwnerCurrent: () => mounted && e == epoch,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

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
    announcements = RefreshSection()..addListener(_changed);
    resources = RefreshSection()..addListener(_changed);
    assessments = RefreshSection()..addListener(_changed);
    columns = RefreshSection()..addListener(_changed);
    _resources();
    if (widget.service is CourseLearningContextGateway) {
      _columns();
    } else {
      _announcements();
      _assessments();
    }
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
    await _refresh(
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
    await Future.wait([
      if (a != null) _announcements(force: force),
      if (t != null) _assessments(force: force),
    ]);
  }

  Future<void> _announcements({bool force = false}) {
    final s = widget.service, col = announcementColumn;
    if (s is CourseLearningContextGateway) {
      if (col == null) return Future.value();
      return _refresh(
        announcements,
        () =>
            s.courseAnnouncementsIn(widget.course.id, col, forceRefresh: force),
        force,
      );
    }
    if (s is! CourseAnnouncementGateway) return Future.value();
    return _refresh(
      announcements,
      () => s.courseAnnouncements(widget.course.id, forceRefresh: force),
      force,
    );
  }

  Future<void> _assessments({bool force = false}) {
    final s = widget.service, col = assessmentColumn;
    if (s is CourseLearningContextGateway) {
      if (col == null) return Future.value();
      return _refresh(
        assessments,
        () => s.courseAssessmentsIn(widget.course.id, col, forceRefresh: force),
        force,
      );
    }
    if (s is! CourseAssessmentGateway) return Future.value();
    return _refresh(
      assessments,
      () => s.courseAssessments(widget.course.id, forceRefresh: force),
      force,
    );
  }

  Future<void> _resources({bool force = false}) {
    final s = widget.service, ids = path.map((f) => f.id).toList(), p = page;
    if (s is CourseLearningContextGateway) {
      return _refresh(
        resources,
        () => s.courseResourcesAt(
          widget.course.id,
          path: ids,
          page: p,
          forceRefresh: force,
        ),
        force,
      );
    }
    if (s is! CourseResourceGateway) return Future.value();
    return _refresh(
      resources,
      () => s.courseResources(
        widget.course.id,
        folder: ids.isEmpty ? null : ids.single,
        page: p,
        forceRefresh: force,
      ),
      force,
    );
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
          _LearningText('未发现可用$title栏目；不代表没有$title内容'),
        if (options.length > 1 && selected == null)
          _LearningText('请选择$title栏目（不自动使用第一项）'),
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
    final service = widget.service;
    if (service is! CourseLearningContextGateway) return;
    final e = epoch;
    String content;
    try {
      final health = await service.learningCapabilities(widget.course.id);
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
    try {
      final uri = _https(widget.course.sourceUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('open');
      }
    } catch (_) {
      if (current(e)) setState(() => linkError = '无法打开课程官网，请稍后重试。');
    }
  }

  Future<LearningDownload> _download(CourseResource item) {
    final s = widget.service;
    if (s is CourseLearningContextGateway) {
      return s.courseResourceDownloadAt(
        widget.course.id,
        item.id,
        path: path.map((f) => f.id).toList(),
        page: page,
      );
    }
    return (s as CourseResourceGateway).courseResourceDownload(
      widget.course.id,
      item.id,
      folder: path.isEmpty ? null : path.single.id,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContext = widget.service is CourseLearningContextGateway;
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
            _LearningText(widget.course.name, heading: true),
            if (_https(widget.course.sourceUrl) != null)
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  onPressed: _openSource,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text('前往课程官网'),
                ),
              ),
            if (linkError != null) _LearningText(linkError!, warning: true),
            if (hasContext && (columns.loading || columns.error != null))
              AppleSection(
                header: const Text('课程栏目'),
                children: [
                  _ReadStatus(
                    title: '栏目',
                    section: columns,
                    supported: true,
                    onRefresh: () => _columns(force: true),
                  ),
                ],
              ),
            AppleSection(
              header: const Text('公告'),
              children: [
                if (hasContext &&
                    columns.value?.data
                            .where((c) => c.kind == 'announcement')
                            .length !=
                        1)
                  _columnPicker('公告', 'announcement', announcementColumn),
                _ReadStatus(
                  title: '公告',
                  section: announcements,
                  supported: hasContext
                      ? announcementColumn != null
                      : widget.service is CourseAnnouncementGateway,
                  onRefresh: () => _announcements(force: true),
                ),
                if (announcements.value case final read?) ...[
                  if (read.data.isEmpty) const _LearningText('暂无公告'),
                  for (final a in read.data)
                    AppleListTile(
                      key: ValueKey('learning-announcement-${a.id}'),
                      title: Text(a.title),
                      subtitle: Text(a.publishedAt ?? '发布时间未知'),
                      onTap: () {
                        final e = epoch;
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => _AnnouncementPage(
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
            ),
            AppleSection(
              header: const Text('课程资料'),
              footer: const Text('只列当前目录的当前页；筛选不跨页。下载由你主动发起，不会批量保存。'),
              children: [
                if (path.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '根目录',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                  ),
                Wrap(
                  children: [
                    if (path.isNotEmpty)
                      CupertinoButton(
                        key: const Key('learning-root'),
                        onPressed: () => _navigate([], 1),
                        child: const Text('根目录'),
                      ),
                    for (var i = 0; i < path.length; i++)
                      CupertinoButton(
                        onPressed: () =>
                            _navigate(path.take(i + 1).toList(), 1),
                        child: Text('/ ${path[i].name}'),
                      ),
                  ],
                ),
                if (path.isNotEmpty)
                  CupertinoButton(
                    key: const Key('learning-parent'),
                    onPressed: () =>
                        _navigate(path.take(path.length - 1).toList(), 1),
                    child: const Text('返回上一级'),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoSearchTextField(
                    key: ValueKey(
                      'learning-resource-search-${path.map((f) => f.id).join('/')}/$page',
                    ),
                    placeholder: '筛选当前页资料名称',
                    onChanged: (v) => setState(() => resourceQuery = v.trim()),
                  ),
                ),
                _ReadStatus(
                  title: '资料',
                  section: resources,
                  supported:
                      hasContext || widget.service is CourseResourceGateway,
                  onRefresh: () => _resources(force: true),
                ),
                if (resources.value != null && items.isEmpty)
                  _LearningText(resourceQuery.isEmpty ? '暂无资料' : '当前页没有匹配资料'),
                for (final item in items)
                  if (item.folder)
                    AppleListTile(
                      key: ValueKey('learning-resource-${item.id}'),
                      title: Text(item.name),
                      subtitle: Text(
                        !hasContext && path.isNotEmpty
                            ? '当前服务不支持更深层级，请前往官网'
                            : '目录',
                      ),
                      leading: const Icon(CupertinoIcons.folder),
                      trailing: const CupertinoListTileChevron(),
                      onTap: !hasContext && path.isNotEmpty
                          ? null
                          : () => _navigate([...path, item], 1),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppleListTile(
                          key: ValueKey('learning-resource-${item.id}'),
                          title: Text(item.name),
                          subtitle: Text(
                            item.downloadable
                                ? (item.updatedAt ?? '更新时间未知')
                                : '学校未允许下载',
                          ),
                        ),
                        if (item.downloadable)
                          _LearningFileButton(
                            key: ValueKey('learning-save-${item.id}'),
                            download: () => _download(item),
                            saveFile: widget.saveFile,
                            isCurrent: () => current(epoch),
                            contextToken:
                                '${widget.accountId}/${widget.course.id}/${path.map((f) => f.id).join('/')}/$page/$epoch',
                          ),
                      ],
                    ),
                if (resources.value != null)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CupertinoButton(
                        key: const Key('learning-previous-page'),
                        onPressed: page > 1
                            ? () => _navigate(List.of(path), page - 1)
                            : null,
                        child: const Text('上一页'),
                      ),
                      Text('第 $page 页'),
                      CupertinoButton(
                        key: const Key('learning-next-page'),
                        onPressed: resources.value!.data.hasNext
                            ? () => _navigate(List.of(path), page + 1)
                            : null,
                        child: const Text('下一页'),
                      ),
                    ],
                  ),
              ],
            ),
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
                _ReadStatus(
                  title: '测验',
                  section: assessments,
                  supported: hasContext
                      ? assessmentColumn != null
                      : widget.service is CourseAssessmentGateway,
                  onRefresh: () => _assessments(force: true),
                ),
                if (assessments.value case final read?) ...[
                  if (read.data.isEmpty) const _LearningText('暂无测验'),
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

class _AnnouncementPage extends StatefulWidget {
  const _AnnouncementPage({
    required this.service,
    required this.course,
    required this.announcement,
    required this.isCurrent,
    this.column,
    this.saveFile,
  });
  final Object service;
  final String course;
  final String? column;
  final CourseAnnouncement announcement;
  final bool Function() isCurrent;
  final LearningFileSaver? saveFile;
  @override
  State<_AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<_AnnouncementPage> {
  final detail = RefreshSection<CourseAnnouncementDetail>();
  @override
  void initState() {
    super.initState();
    detail.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() => detail.refresh(() async {
    final s = widget.service;
    final value = s is CourseLearningContextGateway
        ? await s.courseAnnouncementDetailIn(
            widget.course,
            widget.column!,
            widget.announcement.id,
          )
        : await (s as CourseAnnouncementGateway).courseAnnouncementDetail(
            widget.course,
            widget.announcement.id,
          );
    if (!widget.isCurrent()) throw StateError('上下文已改变');
    return SectionResult(value: value);
  }, fallbackError: '公告读取失败，请重试或前往官网');
  Future<LearningDownload> _download(String file) {
    final s = widget.service;
    return s is CourseLearningContextGateway
        ? s.courseAnnouncementAttachmentIn(
            widget.course,
            widget.column!,
            widget.announcement.id,
            file,
          )
        : (s as CourseAnnouncementGateway).courseAnnouncementAttachment(
            widget.course,
            widget.announcement.id,
            file,
          );
  }

  @override
  void dispose() {
    detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: const CupertinoNavigationBar(middle: Text('公告详情')),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _LearningText(
            detail.value?.title ?? widget.announcement.title,
            heading: true,
          ),
          SectionFeedback(
            loading: detail.loading,
            label: '正在读取公告…',
            hasData: detail.value != null,
            error: detail.error,
            onRetry: _load,
          ),
          if (detail.value case final value?) ...[
            _LearningText(_present(value.content) ? value.content! : '暂无正文'),
            if (value.attachments.isNotEmpty)
              AppleSection(
                header: const Text('附件'),
                footer: const Text('仅在点击时下载；读取公告不会标记已读。'),
                children: [
                  for (final file in value.attachments)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppleListTile(
                          title: Text(file.name),
                          subtitle: const Text('公告附件'),
                        ),
                        _LearningFileButton(
                          download: () => _download(file.id),
                          saveFile: widget.saveFile,
                          isCurrent: widget.isCurrent,
                          contextToken:
                              '${widget.course}/${widget.column}/${widget.announcement.id}/${file.id}',
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}

class _LearningFileButton extends StatefulWidget {
  const _LearningFileButton({
    super.key,
    required this.download,
    required this.saveFile,
    required this.isCurrent,
    required this.contextToken,
  });
  final Future<LearningDownload> Function() download;
  final LearningFileSaver? saveFile;
  final bool Function() isCurrent;
  final String contextToken;
  @override
  State<_LearningFileButton> createState() => _LearningFileButtonState();
}

class _LearningFileButtonState extends State<_LearningFileButton> {
  bool busy = false;
  String? message;
  LearningSavedFile? saved;
  int epoch = 0;
  bool current(int e) =>
      mounted &&
      e == epoch &&
      widget.isCurrent() &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  void didUpdateWidget(covariant _LearningFileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextToken != widget.contextToken) {
      epoch++;
      busy = false;
      saved = null;
      message = null;
    }
  }

  Future<void> save() async {
    if (busy || !current(epoch)) return;
    final saver = widget.saveFile;
    if (saver == null) {
      setState(() => message = '当前平台保存能力不可用，请前往官网');
      return;
    }
    final e = epoch;
    setState(() {
      busy = true;
      saved = null;
      message = null;
    });
    try {
      final file = await widget.download();
      if (!current(e)) return;
      final result = await saver(file, () => current(e));
      if (current(e)) {
        setState(() {
          saved = result;
          message = result == null ? '已取消保存或上下文已改变' : '已保存';
        });
      }
    } catch (_) {
      if (current(e)) setState(() => message = '下载或保存失败，请重试或前往官网');
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    final e = epoch, file = saved;
    if (file == null || !current(e)) return;
    try {
      await file.open();
    } catch (_) {
      if (current(e)) setState(() => message = '文件已保存，但无法打开，请从文件管理器查看');
    }
  }

  @override
  void dispose() {
    epoch++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      children: [
        CupertinoButton(
          onPressed: busy ? null : save,
          child: Text(busy ? '正在下载…' : '下载并保存'),
        ),
        if (saved != null)
          CupertinoButton(onPressed: open, child: const Text('打开已保存文件')),
        if (message != null)
          Text(message!, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

Future<void> _refresh<T>(
  RefreshSection<LearningRead<T>> section,
  Future<LearningRead<T>> Function() read,
  bool force,
) => section.refresh(
  () async {
    final result = await read();
    return SectionResult(
      value: result,
      error: result.failure == null ? null : failureMessage(result.failure),
    );
  },
  fallbackError: '本地服务暂时不可用，请重试',
  force: force,
);

class _ReadStatus<T> extends StatelessWidget {
  const _ReadStatus({
    required this.title,
    required this.section,
    required this.supported,
    required this.onRefresh,
  });
  final String title;
  final RefreshSection<LearningRead<T>> section;
  final bool supported;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!supported) _LearningText('当前服务暂不支持$title'),
      if (supported) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              key: ValueKey('learning-refresh-$title'),
              minimumSize: const Size(48, 48),
              onPressed: section.loading ? null : onRefresh,
              child: Text('刷新$title'),
            ),
          ),
        ),
        SectionFeedback(
          loading: section.loading,
          label: '正在读取$title…',
          hasData: section.value != null,
          error: section.error,
          onRetry: onRefresh,
        ),
        if (section.value?.stale == true)
          const _LearningText('旧缓存 · 可能不是最新结果', warning: true),
      ],
    ],
  );
}

class _LearningText extends StatelessWidget {
  const _LearningText(this.text, {this.heading = false, this.warning = false});
  final String text;
  final bool heading, warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: heading ? 22 : 16,
        height: 1.4,
        fontWeight: heading ? FontWeight.w600 : null,
        color: warning
            ? AppleDesign.statusUncertain.resolveFrom(context)
            : null,
      ),
    ),
  );
}

bool _present(String? value) => value != null && value.trim().isNotEmpty;
Uri? _https(String source) {
  final uri = Uri.tryParse(source);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}
