import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_context.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'learning_widgets.dart';

class LearningAnnouncementPage extends StatefulWidget {
  const LearningAnnouncementPage({
    super.key,
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
  State<LearningAnnouncementPage> createState() => LearningAnnouncementPageState();
}

class LearningAnnouncementPageState extends State<LearningAnnouncementPage> {
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
          LearningText(
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
            LearningText(presentText(value.content) ? value.content! : '暂无正文'),
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
                        LearningFileButton(
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