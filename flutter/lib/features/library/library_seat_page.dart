import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/long_page_scroll.dart';
import 'package:ginkgo_mirror/application/collection_window.dart';
import 'package:ginkgo_mirror/widgets/collection_toolbar.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/mutation_dialog.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'library_cards.dart';
import 'library_controls.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
class LibrarySeatPage extends StatefulWidget {
  const LibrarySeatPage({
    super.key,
    required this.service,
    required this.area,
    required this.slot,
    required this.onReservationChanged,
    required this.onViewReservations,
  });
  final Future<void> Function() onReservationChanged;
  final VoidCallback onViewReservations;
  final LibrarySeatingGateway service;
  final LibraryArea area;
  final LibrarySlot slot;
  @override
  State<LibrarySeatPage> createState() => _LibrarySeatPageState();
}

class _LibrarySeatPageState extends State<LibrarySeatPage> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  final window = CollectionWindow();
  final resultsAnchor = CollectionAnchor();
  List<LibrarySeat>? seats;
  String? error;
  bool busy = false;
  Future<void>? _loadTask;
  int requestSerial = 0;
  String search = '';
  bool availableOnly = false;
  List<LibrarySeat> visible = [];
  Map<String, int> visibleIndices = {};

  bool submitting = false;
  bool awaitingVerification = false;
  String? mutationNotice;

  void prepare({bool reset = false}) {
    final query = search.trim().toLowerCase();
    visible = (seats ?? <LibrarySeat>[])
        .where(
          (seat) =>
              (!availableOnly || seat.available) &&
              (query.isEmpty || seat.name.toLowerCase().contains(query)),
        )
        .toList();
    window.reconcile(visible.map((seat) => seat.id), reset: reset);
    visibleIndices = {
      for (var index = window.start; index < window.end; index++)
        'library-seat-group-${visible[index].id}': index - window.start,
    };
  }

  Future<void> reserve(LibrarySeat seat) async {
    if (submitting || awaitingVerification) return;
    final confirmed = await confirmMutation(
      context,
      title: '确认预约？',
      detail:
          '${widget.area.name} · ${seat.name}\n${widget.slot.day} ${widget.slot.start}–${widget.slot.end}',
      action: '确认预约',
    );
    if (!confirmed || !mounted || submitting) return;
    setState(() {
      submitting = true;
      awaitingVerification = true;
    });
    var message = '预约结果待核实，请查看当前预约，勿重复提交';
    try {
      final result = await widget.service.reserveLibrarySeat(
        areaId: widget.area.id,
        seatId: seat.id,
        slot: widget.slot,
      );
      message = result.message;
      if (result.state == 'notSubmitted' || result.state == 'rejected') {
        awaitingVerification = false;
      }
    } catch (_) {
      /* Unknown result is never a retry prompt. */
    }
    if (mounted) setState(() => mutationNotice = message);
    // Publish the readback to the original page even if this route was popped
    // during submission. Seat availability must not delay the booking result.
    await Future.wait([widget.onReservationChanged(), if (mounted) load()]);
    if (mounted) {
      setState(() {
        submitting = false;
        mutationNotice = message;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(LibrarySeatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.area.id != widget.area.id ||
        oldWidget.slot.id != widget.slot.id) {
      requestSerial++;
      _loadTask = null;
      seats = null;
      visible = [];
      visibleIndices = {};
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
      final result = await widget.service.librarySeats(
        areaId: widget.area.id,
        slot: widget.slot,
      );
      if (!mounted || serial != requestSerial) return;
      setState(() {
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        seats = result.seats;
        prepare();
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
      child: LongPageScroll(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        key: const Key('library-seats-scroll'),
        slivers: [
          AppleRefreshPageHeader(
            title: '${widget.slot.start}–${widget.slot.end}',
            subtitle: '${widget.area.name} · 选择空闲座位',
            icon: CupertinoIcons.square_grid_2x2,
            refreshLabel: '刷新列表',
            busy: busy,
            onRefresh: load,
          ),
          CupertinoSliverRefreshControl(onRefresh: load),
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (mutationNotice != null)
                  AppleSection(
                    animateSize: false,
                    children: [
                      AppleListTile(
                        title: Text(mutationNotice!),
                        trailing: CupertinoButton(
                          onPressed: widget.onViewReservations,
                          child: const Text('查看预约'),
                        ),
                      ),
                    ],
                  ),
                if (error != null && seats == null)
                  AppleStatusSection(
                    title: error!,
                    description: '座位列表读取失败，请稍后重试。',
                    error: true,
                    action: '重试',
                    onAction: load,
                    animateSize: false,
                  ),
                if (seats == null && error == null)
                  const GinkgoLoadingView(label: '正在读取座位…'),
              ],
            ),
          ),
          resultsAnchor.sliver,
          if (seats != null)
            PinnedHeaderSliver(
              child: CollectionQuerySurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        widget.area.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: LibraryFilterField(
                        placeholder: '搜索座位编号',
                        filterKey: const Key('library-seat-search'),
                        onChanged: (value) => setState(() {
                          search = value;
                          prepare(reset: true);
                          resultsAnchor.reveal(scrollController);
                        }),
                      ),
                    ),
                    AppleListTile(
                      leading: const Icon(
                        CupertinoIcons.line_horizontal_3_decrease_circle,
                        size: 20,
                      ),
                      title: const Text('只看空闲座位'),
                      trailing: CupertinoSwitch(
                        value: availableOnly,
                        onChanged: (value) => setState(() {
                          availableOnly = value;
                          prepare(reset: true);
                          resultsAnchor.reveal(scrollController);
                        }),
                      ),
                    ),

                    CollectionToolbar(
                      window: window,
                      unit: '个座位',
                      error: error,
                      onRetry: load,
                      busy: busy || submitting,
                      onPageChanged: (page) {
                        setState(() {
                          window.select(page);
                          prepare();
                        });
                        resultsAnchor.reveal(scrollController);
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (seats != null && visible.isEmpty)
            SliverToBoxAdapter(
              child: AppleSection(
                animateSize: false,
                children: [
                  AppleListTile(
                    title: Text(seats!.isEmpty ? '该时段没有座位数据' : '没有符合条件的座位'),
                  ),
                ],
              ),
            ),
          if (visible.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppleDesign.pageInset,
              ),
              sliver: SliverList.builder(
                itemCount: window.end - window.start,
                findChildIndexCallback: (key) {
                  if (key is! ValueKey<String>) return null;
                  return visibleIndices[key.value];
                },
                itemBuilder: (context, index) =>
                    _seatRow(visible[window.start + index], index),
              ),
            ),
          if (seats != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
                child: Text(
                  '选择空闲座位后确认预约。',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    )
    ),
  );

  Widget _seatRow(LibrarySeat seat, int index) => librarySeatRow(
    context,
    groupKey: ValueKey('library-seat-group-${seat.id}'),
    seat: seat,
    roundedTop: index == 0,
    roundedBottom: index == window.end - window.start - 1,
    hasSeparator: index != visible.length - 1,
    reserveEnabled:
        !busy && error == null && !submitting && !awaitingVerification,
    submitting: submitting,
    onReserve: () => reserve(seat),
  );
}
