import 'package:flutter/cupertino.dart';

import 'application/contracts.dart';
import 'application/refresh_section.dart';
import 'apple_widgets.dart';
import 'course_visibility.dart';
import 'homework_projection.dart';
import 'loading_widgets.dart';

/// A separate read can finish before or after today's timetable.
class TodayHomeworkSection extends StatelessWidget {
  const TodayHomeworkSection({
    super.key,
    required this.section,
    required this.onRetry,
    this.onOpen,
  });
  final RefreshSection<HomeworkResponse> section;
  final VoidCallback onRetry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final data = section.value;
    final personal = personalHomeworkItems(
      data?.items ?? [],
      CourseVisibilityScope.of(context),
    );
    final pending = personal.where(
      (item) => item.status == HomeworkStatus.pending,
    );
    final unknown = personal.where(
      (item) => item.status == HomeworkStatus.unknown,
    );
    return AppleSection(
      key: const Key('today-homework'),
      header: const Text('学校作业'),
      footer: const Text('个人课程作业 · 不含助教课程'),
      children: [
        if (section.loading || section.error != null)
          SectionFeedback(
            loading: section.loading,
            label: data == null ? '正在检查学校作业…' : '正在更新学校作业…',
            hasData: data != null,
            error: section.error,
            onRetry: onRetry,
          ),
        if (data != null)
          SectionReveal(
            child: Column(
              children: [
                AppleListTile(
                  leading: Icon(
                    CupertinoIcons.doc_text,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  title: Text(
                    pending.isNotEmpty
                        ? '${pending.length} 项作业待处理'
                        : section.error == null
                        ? '当前没有待处理作业'
                        : '作业状态尚未确认',
                  ),
                  subtitle: unknown.isEmpty
                      ? null
                      : Text('${unknown.length} 项状态待确认，请进入作业核对'),
                  trailing: onOpen == null
                      ? null
                      : const CupertinoListTileChevron(),
                  onTap: onOpen,
                ),
                for (final item in pending.take(3))
                  AppleListTile(
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item.courseName),
                    onTap: onOpen,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
