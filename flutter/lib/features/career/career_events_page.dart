import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ginkgo_mirror/application/career.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class CareerEventsPage extends StatefulWidget {
  const CareerEventsPage({super.key, required this.service});
  final Object service;

  @override
  State<CareerEventsPage> createState() => _CareerEventsPageState();
}

class _CareerEventsPageState extends State<CareerEventsPage> {
  CareerEventsGateway? get gateway => widget.service is CareerEventsGateway
      ? widget.service as CareerEventsGateway
      : null;
  String month = _schoolMonth(DateTime.now());
  CareerEvents? data;
  String? error;
  bool busy = false;
  bool pendingRefresh = false;
  int generation = 0;

  static String _schoolMonth(DateTime instant) {
    final beijing = instant.toUtc().add(const Duration(hours: 8));
    return '${beijing.year.toString().padLeft(4, '0')}-'
        '${beijing.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CareerEventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      generation++;
      data = null;
      error = null;
      busy = false;
      pendingRefresh = false;
      load();
    }
  }

  Future<void> load({bool force = false}) async {
    final gateway = this.gateway;
    if (gateway == null) return;
    if (busy) {
      if (force) pendingRefresh = true;
      return;
    }
    final requestGeneration = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await gateway.careerEvents(
        month: month,
        forceRefresh: force,
      );
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        busy = false;
        if (result.failure != null) error = failureMessage(result.failure);
        if (result.data != null) data = result.data;
      });
    } catch (_) {
      if (mounted && requestGeneration == generation) {
        setState(() {
          busy = false;
          error = failureMessage(null);
        });
      }
    }
    if (mounted && requestGeneration == generation && pendingRefresh) {
      pendingRefresh = false;
      await load(force: true);
    }
  }

  void selectMonth(String value) {
    if (value == month) return;
    setState(() {
      month = value;
      error = null;
    });
    load(force: true);
  }

  Future<void> open(CareerEvent event) async {
    if (event.url.isEmpty) return;
    final uri = Uri.tryParse(event.url);
    var opened = false;
    try {
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('无法打开官网'),
          content: const Text('请稍后重试。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = this.gateway;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        key: const Key('career-events-scroll'),
        slivers: [
          ApplePageHeader(
            largeTitle: const Text('就业活动'),
            section: '资讯与就业',
            subtitle: '学校就业网公开的宣讲与双选安排',
            icon: CupertinoIcons.briefcase,
            border: null,
            trailing: AppleGlassButton(
              label: '刷新就业活动',
              onPressed: busy ? null : () => load(force: true),
              child: busy
                  ? const GinkgoActivity(size: 17)
                  : const Icon(CupertinoIcons.refresh),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
          SliverList.list(
            children: [
              if (gateway == null)
                const AppleSection(
                  children: [
                    AppleEmptyState(
                      title: '当前服务不支持就业活动',
                      description: '请连接真实服务后重试。',
                      error: true,
                    ),
                  ],
                )
              else ...[
                AppleSection(
                  header: const Text('月份'),
                  children: [
                    CupertinoListTile(
                      title: Text(month),
                      subtitle: const Text('按学校就业网日历月份查询'),
                      trailing: CupertinoButton(
                        onPressed: busy ? null : () => _showMonthPicker(),
                        child: const Text('选择'),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  AppleSection(
                    children: [
                      AppleEmptyState(
                        title: error!,
                        description: data == null ? '请重试或前往官网。' : '正在显示上次结果。',
                        action: '重试',
                        onAction: () => load(force: true),
                        error: true,
                      ),
                    ],
                  ),
                if (data == null && busy)
                  const AppleSection(
                    children: [GinkgoLoadingView(label: '正在读取就业活动…')],
                  ),
                if (data != null) ...[
                  if (data!.events.isEmpty)
                    AppleSection(
                      children: [
                        AppleEmptyState(
                          title: '本月没有活动',
                          description: '这是就业网成功返回的空结果；可查询其他月份。',
                        ),
                      ],
                    )
                  else
                    AppleSection(
                      header: Text('${data!.events.length} 条安排'),
                      footer: Text(
                        '来源：学校就业网 · 同步 ${schoolTimestampLabel(data!.fetchedAt)}',
                      ),
                      children: [
                        for (final event in data!.events)
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
                            onTap: () => open(event),
                          ),
                      ],
                    ),
                ],
                Padding(padding: GinkgoSpacing.edgeInsetsPage),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthPicker() async {
    var selected = DateTime.tryParse('$month-01T00:00:00Z');
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
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
        ),
      ),
    );
    final value = selected;
    if (!mounted || value == null) return;
    selectMonth(_schoolMonth(DateTime.utc(value.year, value.month)));
  }
}
