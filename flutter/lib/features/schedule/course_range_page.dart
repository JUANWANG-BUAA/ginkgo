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
  });
  final CourseVisibility preferences;
  final String system;
  final Map<String, String> courses;
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
              footer: const Text(
                '关闭你担任助教或教师的课程后，主列表和个人统计会将其收起；可随时重新开启。此设置只影响本机当前账号，不修改学校选课或身份。不同系统分别设置。',
              ),
              children: [
                for (final course in courses.entries)
                  AppleListTile(
                    title: Text(course.value),
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
