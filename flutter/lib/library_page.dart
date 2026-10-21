import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'apple_design.dart';
import 'mirror_service.dart';
import 'mutation_dialog.dart';
import 'library_history_page.dart';
import 'library_controller.dart';
import 'library_stats_page.dart';
import 'resource_meter.dart';
import 'reservation_widgets.dart';
import 'src/rust/api/mirror.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final LibraryController controller;

  @override
  void initState() {
    super.initState();
    controller = LibraryController(widget.service)..addListener(_changed);
    controller.load();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  Widget _sectionStatus({
    required String id,
    required bool loading,
    required bool hasSnapshot,
    required String? failure,
    required VoidCallback retry,
  }) => AppleListTile(
    key: Key('library-$id-status'),
    leading: loading
        ? const CupertinoActivityIndicator()
        : const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: AppleDesign.statusPending,
            size: 20,
          ),
    title: Text(loading ? (hasSnapshot ? '正在更新…' : '正在加载…') : failure!),
    subtitle: hasSnapshot ? const Text('保留上次结果') : null,
    trailing: loading
        ? null
        : CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: retry,
            child: const Text('重试'),
          ),
  );

  Future<void> perform(LibraryBooking booking, String action) async {
    if (controller.submitting) return;
    final label = _actionLabel(action);
    final key = '${booking.id}/$action';
    if (controller.uncertainActions.contains(key)) return;
    final confirmed = await confirmMutation(
      context,
      title: '确认$label？',
      detail:
          '${booking.title}\n${booking.day} ${booking.startTime}–${booking.endTime}',
      action: label,
      destructive: action == 'cancel' || action == 'checkout',
    );
    if (confirmed && mounted) await controller.perform(booking, action);
  }

  String _actionLabel(String action) => switch (action) {
    'signin' => '签到入座 / 返回',
    'leave' => '暂离',
    'checkout' => '离馆',
    'cancel' => '取消预约',
    _ => action,
  };

  void _push(Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: const Key('library-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('图书馆'),
          border: null,
          trailing: AppleGlassButton(
            label: '刷新图书馆',
            onPressed: controller.busy
                ? null
                : () => controller.load(force: true),
            child: controller.busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(
          onRefresh: () => controller.load(force: true),
        ),
        SliverList.list(
          children: [
            AppleSection(
              children: [
                AppleListTile(
                  key: const Key('library-public-stats'),
                  title: const Text('在馆人数与空间余量'),
                  subtitle: const Text('学院路 · 沙河'),
                  leading: const Icon(CupertinoIcons.person_2),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(LibraryStatsPage(service: widget.service)),
                ),
              ],
            ),
            ...[
              if (controller.mutationNotice != null)
                AppleSection(
                  children: [
                    AppleListTile(title: Text(controller.mutationNotice!)),
                  ],
                ),
              _bookingSection(),
              AppleSection(
                children: [
                  AppleListTile(
                    key: const Key('library-history'),
                    title: const Text('全部预约记录'),
                    leading: const Icon(CupertinoIcons.clock),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        _push(LibraryHistoryPage(service: widget.service)),
                  ),
                ],
              ),
              _venueSection(),
              const SizedBox(height: 96),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _bookingSection() {
    final items = controller.bookings?.bookings ?? const <LibraryBooking>[];
    return AppleSection(
      header: const Text('当前预约'),
      children: [
        if (controller.loadingBookings || controller.bookingError != null)
          _sectionStatus(
            id: 'bookings',
            loading: controller.loadingBookings,
            hasSnapshot: controller.bookings != null,
            failure: controller.bookingError,
            retry: () => controller.loadBookings(force: true),
          ),
        if (controller.bookings != null && items.isEmpty)
          AppleListTile(
            leading: Icon(
              CupertinoIcons.book,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              size: 22,
            ),
            title: const Text('当前没有进行中的预约'),
          )
        else
          for (final booking in items)
            Column(
              children: [
                AppleListTile(
                  key: Key('library-booking-${booking.id}'),
                  minimumHeight: 68,
                  leading: const Icon(
                    CupertinoIcons.bookmark_fill,
                    color: AppleDesign.statusSuccess,
                    size: 22,
                  ),
                  title: Text(booking.title.isEmpty ? '图书馆预约' : booking.title),
                  subtitle: Text(
                    _bookingDetail(booking),
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                  additionalInfo: Text(
                    booking.statusName,
                    style: TextStyle(
                      fontSize: 14,
                      color: _bookingEnded(booking)
                          ? AppleDesign.statusInactive.resolveFrom(context)
                          : AppleDesign.statusSuccess.resolveFrom(context),
                    ),
                  ),
                ),
                if ((booking.actions ?? []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final action in booking.actions!)
                          ReservationActionButton(
                            buttonKey: Key(
                              'library-action-${booking.id}-$action',
                            ),
                            label: _actionLabel(action),
                            icon: switch (action) {
                              'signin' => CupertinoIcons.checkmark_seal,
                              'leave' => CupertinoIcons.pause_circle,
                              'checkout' => CupertinoIcons.arrow_right_circle,
                              _ => CupertinoIcons.xmark_circle,
                            },
                            tint: switch (action) {
                              'cancel' => AppleDesign.statusDanger,
                              'leave' => AppleDesign.statusPending,
                              _ => CupertinoColors.systemBlue,
                            },
                            onPressed:
                                controller.submitting ||
                                    controller.uncertainActions.contains(
                                      '${booking.id}/$action',
                                    )
                                ? null
                                : () => perform(booking, action),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
      ],
    );
  }

  bool _bookingEnded(LibraryBooking booking) =>
      ['取消', '结束', '过期', '失效'].any(booking.statusName.contains);

  /// Upstream sends HH:mm:ss; the row only has room for HH:mm.
  String _clock(String value) {
    final parts = value.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
  }

  String _bookingDetail(LibraryBooking booking) {
    final bits = [
      if (booking.day.isNotEmpty) booking.day,
      if (booking.startTime.isNotEmpty && booking.endTime.isNotEmpty)
        '${_clock(booking.startTime)}–${_clock(booking.endTime)}',
      // The title already names the space/seat; only repeat them when the
      // upstream row had no title at all.
      if (booking.title.isEmpty && booking.areaName.isNotEmpty)
        booking.areaName,
      if (booking.title.isEmpty && booking.seatNumber.isNotEmpty)
        '${booking.seatNumber}号',
    ];
    return bits.join(' · ');
  }

  Widget _venueSection() {
    final items = controller.venues?.venues ?? const <LibraryVenue>[];
    return AppleSection(
      header: const Text('选择场馆'),
      footer: const Text('空闲数以学校实时查询为准。'),
      children: [
        if (controller.loadingVenues || controller.venueError != null)
          _sectionStatus(
            id: 'venues',
            loading: controller.loadingVenues,
            hasSnapshot: controller.venues != null,
            failure: controller.venueError,
            retry: () => controller.loadVenues(force: true),
          ),
        if (controller.venues != null && items.isEmpty)
          const AppleListTile(
            title: Text('暂无可用场馆'),
            subtitle: Text('学校接口返回了空列表，请稍后刷新。'),
          )
        else
          for (final venue in items)
            ResourceMeter(
              key: Key('library-venue-${venue.id}'),
              label: venue.name,
              available: venue.free,
              total: venue.total,
              unit: '座',
              onTap: () => _push(
                _LibraryAreaPage(
                  service: widget.service,
                  venue: venue,
                  onReservationChanged: controller.reservationChanged,
                ),
              ),
            ),
      ],
    );
  }
}

class _LibraryAreaPage extends StatefulWidget {
  const _LibraryAreaPage({
    required this.service,
    required this.venue,
    required this.onReservationChanged,
  });
  final Future<void> Function() onReservationChanged;
  final MirrorService service;
  final LibraryVenue venue;
  @override
  State<_LibraryAreaPage> createState() => _LibraryAreaPageState();
}

class _LibraryAreaPageState extends State<_LibraryAreaPage> {
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
        CupertinoSliverNavigationBar(
          largeTitle: Text(widget.venue.name),
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
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取区域…'),
                      ],
                    ),
                  ),
                ],
              ),
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
                                  builder: (_) => _LibrarySlotPage(
                                    service: widget.service,
                                    area: area,
                                    onReservationChanged:
                                        widget.onReservationChanged,
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

class _LibrarySlotPage extends StatefulWidget {
  const _LibrarySlotPage({
    required this.service,
    required this.area,
    required this.onReservationChanged,
  });
  final Future<void> Function() onReservationChanged;
  final MirrorService service;
  final LibraryArea area;
  @override
  State<_LibrarySlotPage> createState() => _LibrarySlotPageState();
}

class _LibrarySlotPageState extends State<_LibrarySlotPage> {
  List<LibrarySlot>? slots;
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
      final result = await widget.service.librarySlots(widget.area.id);
      if (!mounted) return;
      setState(() {
        if (result.failure != null) {
          error = failureMessage(result.failure);
          return;
        }
        slots = result.slots;
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
      key: const Key('library-slots-scroll'),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(widget.area.name),
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
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: slots == null
                        ? '时段列表读取失败，请稍后重试。'
                        : '保留上次时段列表，请刷新后确认状态。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
              ),
            if (slots == null && error == null)
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取时段…'),
                      ],
                    ),
                  ),
                ],
              ),
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
                                  builder: (_) => _LibrarySeatPage(
                                    service: widget.service,
                                    area: widget.area,
                                    slot: slot,
                                    onReservationChanged:
                                        widget.onReservationChanged,
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

class _LibrarySeatPage extends StatefulWidget {
  const _LibrarySeatPage({
    required this.service,
    required this.area,
    required this.slot,
    required this.onReservationChanged,
  });
  final Future<void> Function() onReservationChanged;
  final MirrorService service;
  final LibraryArea area;
  final LibrarySlot slot;
  @override
  State<_LibrarySeatPage> createState() => _LibrarySeatPageState();
}

class _LibrarySeatPageState extends State<_LibrarySeatPage> {
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
        CupertinoSliverNavigationBar(
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
                      onPressed: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => LibraryPage(service: widget.service),
                        ),
                      ),
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
