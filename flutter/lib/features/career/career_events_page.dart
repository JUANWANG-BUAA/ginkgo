import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/career.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/public_information_page.dart';

class CareerEventsPage extends StatelessWidget {
  const CareerEventsPage({super.key, required this.service});
  final CareerEventsGateway? service;

  @override
  Widget build(
    BuildContext context,
  ) => PublicInformationPage<CareerEvents, String>(
    service: service,
    initialQuery: _schoolMonth(DateTime.now()),
    read: (month, force) async {
      final result = await service!.careerEvents(
        month: month,
        forceRefresh: force,
      );
      return SectionResult(
        value: result.data,
        error: result.failure == null ? null : failureMessage(result.failure),
        failure: result.failure,
      );
    },
    scrollKey: const Key('career-events-scroll'),
    title: '就业活动',
    subtitle: '学校就业网公开的宣讲与双选安排',
    icon: CupertinoIcons.briefcase,
    refreshLabel: '刷新就业活动',
    loadingLabel: '正在读取就业活动…',
    unsupportedTitle: '当前服务不支持就业活动',
    queryBuilder: (context, month, busy, select) => AppleSection(
      header: const Text('月份'),
      children: [
        CupertinoListTile(
          title: Text(month),
          subtitle: const Text('按学校就业网日历月份查询'),
          trailing: CupertinoButton(
            onPressed: busy
                ? null
                : () async {
                    final value = await _pickMonth(context, month);
                    if (value != null && context.mounted) select(value);
                  },
            child: const Text('选择'),
          ),
        ),
      ],
    ),
    contentBuilder: (context, data) {
      if (data.events.isEmpty) {
        return const AppleStatusSection(
          title: '本月没有活动',
          description: '这是就业网成功返回的空结果；可查询其他月份。',
        );
      }
      return AppleSection(
        header: Text('${data.events.length} 条安排'),
        footer: Text('来源：学校就业网 · 同步 ${schoolTimestampLabel(data.fetchedAt)}'),
        children: [
          for (final event in data.events)
            AppleListTile(
              key: Key('career-event-${event.id}'),
              title: Text(event.title),
              subtitle: Text(
                '${event.beginsAt}–${event.endsAt}\n'
                '${event.campus.isEmpty ? '校区未提供' : event.campus} · '
                '${event.place.isEmpty ? '地点未提供' : event.place}\n'
                '${event.fairType.isEmpty ? '类型未提供' : event.fairType}',
              ),
              trailing: const Icon(CupertinoIcons.chevron_right),
              onTap: () => _openEvent(context, event),
            ),
        ],
      );
    },
  );
}

String _schoolMonth(DateTime instant) {
  final beijing = todaySchoolNow(instant);
  return '${beijing.year.toString().padLeft(4, '0')}-'
      '${beijing.month.toString().padLeft(2, '0')}';
}

Future<void> _openEvent(BuildContext context, CareerEvent event) async {
  if (event.url.isEmpty) return;
  if (!await openSchoolLink(event.url) && context.mounted) {
    await showSchoolLinkError(context);
  }
}

Future<String?> _pickMonth(BuildContext context, String month) async {
  var selected = DateTime.tryParse('$month-01T00:00:00Z');
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => Container(
      height: 280,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              CupertinoButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('确认'),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              key: const Key('career-month-picker'),
              mode: CupertinoDatePickerMode.monthYear,
              initialDateTime: selected,
              minimumYear: 2020,
              maximumYear: 2035,
              onDateTimeChanged: (value) =>
                  selected = DateTime(value.year, value.month),
            ),
          ),
        ],
      )
      ),
    ),
  );
  final value = selected;
  return value == null
      ? null
      : _schoolMonth(DateTime.utc(value.year, value.month));
}
