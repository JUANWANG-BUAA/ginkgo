import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/resource_meter.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
import 'package:ginkgo_mirror/features/library/library_slot_page.dart';

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
  final LibraryGateway service;
  final LibraryVenue venue;
  @override
  State<LibraryAreaPage> createState() => LibraryAreaPageState();
}

class LibraryAreaPageState extends State<LibraryAreaPage> {
  List<LibraryArea>? areas;
  String? error;
  bool busy = false;
  Future<void>? _loadTask;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() =>
      _loadTask ??= _fetch().whenComplete(() => _loadTask = null);

  Future<void> _fetch() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryAreas(widget.venue.id);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        areas = result.areas;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = failureMessage(null);
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('library-areas-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: Text(widget.venue.name),
          section: '空间资源',
          subtitle: '查看开放区域与座位余量',
          icon: CupertinoIcons.rectangle_grid_2x2,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新列表',
            onPressed: busy ? null : load,
            child: busy
                ? const GinkgoActivity(size: 17)
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: areas == null
                        ? '区域列表读取失败，请稍后重试。'
                        : '保留上次区域列表，请刷新后确认状态。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
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
    ),
  );
}
