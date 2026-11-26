import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';

import 'schedule_widgets.dart';

class CourseRangePage extends StatelessWidget {
  const CourseRangePage({
    super.key,
    required this.preferences,
    required this.system,
    required this.courses,
    this.courseRoles = const {},
  });
  final CourseVisibility preferences;
  final String system;
  final Map<String, String> courses;
  final Map<String, String> courseRoles;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) => CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('我的课程范围')),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        child: ListView(
          children: [
            ScheduleSection(
              title: '作为我的学生课程',
              footer: const Text('关闭非个人课程后，主列表和统计会将其收起，可随时恢复。'),
              children: [
                for (final course in courses.entries)
                  AppleListTile(
                    title: Text(course.value),
                    subtitle: courseRoles[course.key] == null
                        ? null
                        : Text(courseRoles[course.key]!),
                    trailing: CupertinoSwitch(
                      key: ValueKey('course-range-${course.key}'),
                      value: !preferences.hidden(system, course.key),
                      onChanged: preferences.loadFailed
                          ? null
                          : (value) => preferences.setHidden(
                              system,
                              course.key,
                              !value,
                            ),
                    ),
                  ),
              ],
            ),
            if (preferences.error != null)
              AppleStatusSection(
                title: preferences.error!,
                description: '重试成功后即可继续调整；已保存的原设置不会被覆盖。',
                action: '重试读取',
                onAction: preferences.retryRestore,
                error: true,
              ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    ),
  );
}
