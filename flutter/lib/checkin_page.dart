import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'src/rust/api/mirror.dart';

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// iclass read-only status. This page never submits a sign-in: writes need
/// per-course confirmation, a post-submit re-query and an unknown-result rule.
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  CheckInResponse? data;
  String? error;
  String? notice;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.checkin(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null && result.courses.isEmpty) {
          error = failureMessage(result.failure);
          notice = null;
          return;
        }
        data = result;
        error = null;
        notice = result.failure == null
            ? null
            : '${failureMessage(result.failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        if (data == null) {
          error = failureMessage(null);
        } else {
          notice = '${failureMessage(null)}，正在显示上次结果。';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('checkin-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('课程签到'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新签到状态',
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            if (notice != null)
              AppleSection(
                children: [
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: CupertinoColors.systemOrange,
                      size: 20,
                    ),
                    title: Text(notice!),
                  ),
                ],
              ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '请检查网络后重试；已确认的旧状态会保留。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
                  ),
                ],
              )
            else if (data == null)
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取 iclass 当天课程…'),
                      ],
                    ),
                  ),
                ],
              )
            else
              ..._content(data!),
          ],
        ),
      ],
    ),
  );

  List<Widget> _content(CheckInResponse data) {
    final date = DateTime.tryParse(data.date);
    final dateLabel = date == null
        ? data.date
        : '${date.year}年${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';
    final signed = data.courses
        .where((course) => course.status == CheckInStatus.signed)
        .length;
    final unknown = data.courses
        .where((course) => course.status == CheckInStatus.unknown)
        .length;
    final notSigned = data.courses.length - signed - unknown;
    return [
      AppleSection(
        header: Text(dateLabel),
        children: [
          AppleListTile(
            title: Text(
              data.courses.isEmpty ? '今天没有课程' : '今天 ${data.courses.length} 节课',
            ),
            subtitle: Text(
              data.courses.isEmpty
                  ? '学校签到系统返回当天无课程。'
                  : [
                      '已签到 $signed',
                      '未签到 $notSigned',
                      if (unknown > 0) '待确认 $unknown',
                    ].join(' · '),
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            additionalInfo: Text(
              _fetchedLabel(data.fetchedAt),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
      if (data.courses.isEmpty)
        AppleSection(
          children: const [
            AppleEmptyState(
              title: '今天没有课程',
              description: '可以到课表确认其他教学周，或稍后下拉刷新。',
            ),
          ],
        )
      else
        AppleSection(
          header: const Text('当天课程'),
          footer: const Text(
            '签到状态来自 iclass 实时查询；同一课程出现多条不一致记录时显示“待确认”，不会据此提交签到。',
          ),
          children: [for (final course in data.courses) _courseRow(course)],
        ),
      AppleSection(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.service.isDemo
                  ? '离线合成样例，不连接学校账号；仅用于演示只读签到页。'
                  : '真实账号只读数据；签到提交尚未开放，开放后会逐课程二次确认并在提交后回查状态。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _courseRow(CheckInCourse course) {
    final (icon, color, label) = switch (course.status) {
      CheckInStatus.signed => (
        CupertinoIcons.checkmark_circle_fill,
        CupertinoColors.systemGreen,
        '已签到',
      ),
      CheckInStatus.notSigned => (
        CupertinoIcons.circle,
        CupertinoColors.tertiaryLabel,
        '未签到',
      ),
      CheckInStatus.unknown => (
        CupertinoIcons.question_circle_fill,
        CupertinoColors.systemOrange,
        '待确认',
      ),
    };
    final details = [
      '${course.beginsAt}–${course.endsAt}',
      if (course.classroomName != null) course.classroomName!,
      if (course.teacherName != null) course.teacherName!,
    ];
    return AppleListTile(
      key: Key('checkin-course-${course.id}'),
      minimumHeight: 68,
      leading: Icon(icon, size: 26, color: color),
      title: Text(course.courseName),
      subtitle: Text(
        details.join(' · '),
        maxLines: 2,
        style: TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      additionalInfo: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (course.mergedRecordCount > 1)
            Text(
              '合并 ${course.mergedRecordCount} 条',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          if (course.conflicting)
            Text(
              '记录不一致',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemOrange.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }

  /// The bridge sends Asia/Shanghai RFC 3339 timestamps; keep the school clock
  /// rather than the device time zone.
  String _fetchedLabel(String? fetchedAt) {
    if (fetchedAt == null) return '';
    final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(fetchedAt);
    if (match == null) return '';
    return '核对 ${match.group(1)}:${match.group(2)}';
  }
}
