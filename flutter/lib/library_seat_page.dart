import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'apple_design.dart';
import 'mirror_service.dart';
import 'mutation_dialog.dart';
import 'reservation_widgets.dart';
import 'application/contracts.dart';

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
  final LibraryGateway service;
  final LibraryArea area;
  final LibrarySlot slot;
  @override
  State<LibrarySeatPage> createState() => LibrarySeatPageState();
}

class LibrarySeatPageState extends State<LibrarySeatPage> {
  List<LibrarySeat>? seats;
  String? error;
  bool busy = false;
  Future<void>? _loadTask;
  String search = '';
  bool availableOnly = false;
  List<LibrarySeat> visible = [];
  Map<String, int> visibleIndices = {};
  void prepare() {
    final query = search.trim().toLowerCase();
    visible = (seats ?? <LibrarySeat>[])
        .where(
          (seat) =>
              (!availableOnly || seat.available) &&
              (query.isEmpty || seat.name.toLowerCase().contains(query)),
        )
        .toList();
    visibleIndices = {
      for (final (index, seat) in visible.indexed)
        'library-seat-group-${seat.id}': index,
    };
  }

  bool submitting = false;
  bool awaitingVerification = false;
  String? mutationNotice;
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

  Future<void> load() =>
      _loadTask ??= _fetch().whenComplete(() => _loadTask = null);

  Future<void> _fetch() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.librarySeats(
        areaId: widget.area.id,
        slot: widget.slot,
      );
      if (!mounted) return;
      setState(() {
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        seats = result.seats;
        prepare();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = failureMessage(null));
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
      key: const Key('library-seats-scroll'),
      slivers: [
        ApplePageHeader(
          largeTitle: Text('${widget.slot.start}–${widget.slot.end}'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新列表',
            onPressed: busy ? null : load,
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (mutationNotice != null)
              AppleSection(
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
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: seats == null
                        ? '座位列表读取失败，请稍后重试。'
                        : '保留上次座位列表，请刷新后确认状态。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
              ),
            if (seats == null && error == null)
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取座位…'),
                      ],
                    ),
                  ),
                ],
              ),
            if (seats != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: CupertinoSearchTextField(
                  key: const Key('library-seat-search'),
                  placeholder: '搜索座位编号',
                  onChanged: (value) => setState(() {
                    search = value;
                    prepare();
                  }),
                ),
              ),
              AppleSection(
                children: [
                  AppleListTile(
                    title: const Text('只看空闲座位'),
                    trailing: CupertinoSwitch(
                      value: availableOnly,
                      onChanged: (value) => setState(() {
                        availableOnly = value;
                        prepare();
                      }),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 10),
                child: Text(
                  '${widget.area.name} · ${visible.length} 个座位',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
              if (visible.isEmpty)
                AppleSection(
                  children: [
                    AppleListTile(
                      title: Text(seats!.isEmpty ? '该时段没有座位数据' : '没有符合条件的座位'),
                    ),
                  ],
                ),
            ],
          ],
        ),
        if (visible.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppleDesign.pageInset,
            ),
            sliver: SliverList.builder(
              itemCount: visible.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                return visibleIndices[key.value];
              },
              itemBuilder: (context, index) => _seatRow(visible[index], index),
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
  );

  Widget _seatRow(LibrarySeat seat, int index) => ClipRRect(
    key: ValueKey('library-seat-group-${seat.id}'),
    borderRadius: BorderRadius.vertical(
      top: index == 0
          ? const Radius.circular(AppleDesign.groupRadius)
          : Radius.zero,
      bottom: index == visible.length - 1
          ? const Radius.circular(AppleDesign.groupRadius)
          : Radius.zero,
    ),
    child: ColoredBox(
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
        context,
      ),
      child: Column(
        children: [
          AppleListTile(
            key: Key('library-seat-${seat.id}'),
            trailing: seat.available
                ? ReservationActionButton(
                    buttonKey: Key('library-reserve-${seat.id}'),
                    label: '预约',
                    icon: CupertinoIcons.add_circled,
                    primary: true,
                    busy: submitting,
                    onPressed:
                        busy ||
                            error != null ||
                            submitting ||
                            awaitingVerification
                        ? null
                        : () => reserve(seat),
                  )
                : null,
            leading: Icon(
              seat.available
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color:
                  (seat.available
                          ? AppleDesign.statusSuccess
                          : CupertinoColors.tertiaryLabel)
                      .resolveFrom(context),
              size: 22,
            ),
            title: Text(
              seat.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              seat.statusName.isEmpty
                  ? (seat.available ? '空闲' : '不可用')
                  : seat.statusName,
              style: TextStyle(
                color:
                    (seat.available
                            ? AppleDesign.statusSuccess
                            : CupertinoColors.secondaryLabel)
                        .resolveFrom(context),
              ),
            ),
          ),
          if (index != visible.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 0.5,
                color: CupertinoColors.separator
                    .resolveFrom(context)
                    .withValues(alpha: 0.16),
              ),
            ),
        ],
      ),
    ),
  );
}
