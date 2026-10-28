import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'library_seat_page.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
class LibrarySlotPage extends StatefulWidget {
  const LibrarySlotPage({
    super.key,
    required this.service,
    required this.area,
    required this.onReservationChanged,
    required this.onViewReservations,
  });
  final Future<void> Function() onReservationChanged;
  final VoidCallback onViewReservations;
  final LibrarySeatingGateway service;
  final LibraryArea area;
  @override
  State<LibrarySlotPage> createState() => _LibrarySlotPageState();
}

class _LibrarySlotPageState extends State<LibrarySlotPage> {
  List<LibrarySlot>? slots;
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
  void didUpdateWidget(LibrarySlotPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.area.id != widget.area.id) {
      requestSerial++;
      _loadTask = null;
      slots = null;
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
      final result = await widget.service.librarySlots(widget.area.id);
      if (!mounted || serial != requestSerial) return;
      setState(() {
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        slots = result.slots;
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
    child: CustomScrollView(
      key: const Key('library-slots-scroll'),
      slivers: [
        AppleRefreshPageHeader(
          title: widget.area.name,
          subtitle: '选择时段后查看空闲座位',
          icon: CupertinoIcons.clock,
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
                description: slots == null
                    ? '时段列表读取失败，请稍后重试。'
                    : '保留上次时段列表，请刷新后确认状态。',
                error: true,
                action: '重试',
                onAction: load,
              ),
            if (slots == null && error == null)
              const GinkgoLoadingView(label: '正在读取时段…'),
            if (slots != null)
              AppleSection(
                header: const Text('时段'),
                children: [
                  if (slots!.isEmpty)
                    const AppleListTile(title: Text('今天没有可预约时段'))
                  else
                    for (final slot in slots!)
                      AppleListTile(
                        key: Key('library-slot-${slot.id}'),
                        title: Text('${slot.start}–${slot.end}'),
                        subtitle: Text(slot.day),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: CupertinoColors.tertiaryLabel,
                        ),
                        onTap: busy || error != null
                            ? null
                            : () => Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => LibrarySeatPage(
                                    service: widget.service,
                                    area: widget.area,
                                    slot: slot,
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
