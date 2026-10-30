import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/resource_meter.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'library_slot_page.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
class LibraryAreaPage extends StatefulWidget {
  const LibraryAreaPage({
    super.key,
    required this.service,
    required this.venue,
    required this.onReservationChanged,
    required this.onViewReservations,
  });
  final Future<void> Function() onReservationChanged;
  final VoidCallback onViewReservations;
  final LibrarySeatingGateway service;
  final LibraryVenue venue;
  @override
  State<LibraryAreaPage> createState() => _LibraryAreaPageState();
}

class _LibraryAreaPageState extends State<LibraryAreaPage> {
  List<LibraryArea>? areas;
  String? error;
  bool busy = false;
  Future<void>? _loadTask;
  int requestSerial = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(LibraryAreaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.venue.id != widget.venue.id) {
      requestSerial++;
      _loadTask = null;
      areas = null;
      error = null;
      busy = false;
      load();
    }
  }

  Future<void> load() {
    final running = _loadTask;
    if (running != null) return running;
    late final Future<void> task;
    task = _fetch().whenComplete(() {
      if (identical(_loadTask, task)) _loadTask = null;
    });
    return _loadTask = task;
  }

  Future<void> _fetch() async {
    final serial = ++requestSerial;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryAreas(widget.venue.id);
      if (!mounted || serial != requestSerial) return;
      setState(() {
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        areas = result.areas;
      });
    } catch (_) {
      if (!mounted || serial != requestSerial) return;
      setState(() => error = failureMessage(null));
    } finally {
      if (mounted && serial == requestSerial) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: CustomScrollView(
      key: const Key('library-areas-scroll'),
      slivers: [
        AppleRefreshPageHeader(
          title: widget.venue.name,
          subtitle: '查看开放区域与座位余量',
          icon: CupertinoIcons.rectangle_grid_2x2,
          refreshLabel: '刷新列表',
          busy: busy,
          onRefresh: load,
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (error != null)
              AppleStatusSection(
                title: error!,
                description: areas == null
                    ? '区域列表读取失败，请稍后重试。'
                    : '保留上次区域列表，请刷新后确认状态。',
                error: true,
                action: '重试',
                onAction: load,
              ),
            if (areas == null && error == null)
              const GinkgoLoadingView(label: '正在读取区域…'),
            if (areas != null)
              AppleSection(
                header: const Text('区域'),
                children: [
                  if (areas!.isEmpty)
                    const AppleListTile(title: Text('暂无开放区域'))
                  else
                    for (final area in areas!)
                      ResourceMeter(
                        key: Key('library-area-${area.id}'),
                        label: area.name,
                        available: area.free,
                        total: area.total,
                        unit: '座',
                        onTap: busy || error != null
                            ? null
                            : () => Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => LibrarySlotPage(
                                    service: widget.service,
                                    area: area,
                                    onReservationChanged:
                                        widget.onReservationChanged,
                                    onViewReservations:
                                        widget.onViewReservations,
                                  ),
                                ),
                              ),
                      ),
                ],
              ),
            const SizedBox(height: 96),
          ],
        ),
      ],
    )
    ),
  );
}
