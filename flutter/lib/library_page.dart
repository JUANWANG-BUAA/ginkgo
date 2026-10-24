import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'apple_design.dart';
import 'mirror_service.dart';
import 'mutation_dialog.dart';
import 'library_history_page.dart';
import 'library_books_page.dart';
import 'library_controller.dart';
import 'library_stats_page.dart';
import 'loading_widgets.dart';
import 'reservation_widgets.dart';
import 'application/contracts.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
import 'library_area_page.dart';

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
        ? const GinkgoActivity(size: 17)
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
        ApplePageHeader(
          largeTitle: const Text('图书馆'),
          section: '空间资源',
          subtitle: '选择场馆、区域与可预约时段',
          icon: CupertinoIcons.book,
          border: null,
          trailing: AppleGlassButton(
            label: '刷新图书馆',
            onPressed: controller.busy
                ? null
                : () => controller.load(force: true),
            child: controller.busy
                ? const GinkgoActivity(size: 17)
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
                AppleListTile(
                  key: const Key('library-books'),
                  title: const Text('查书目与馆藏'),
                  subtitle: const Text('公开目录检索 · 复本状态'),
                  leading: const Icon(CupertinoIcons.book),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(LibraryBooksPage(service: widget.service)),
                ),
              ],
            ),
            if (_firstLoad)
              const AppleSection(
                animateSize: false,
                children: [GinkgoLoadingView(label: '正在读取图书馆…', compact: true)],
              )
            else ...[
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
            ],
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );

  /// Both first reads share one quiet, branded wait instead of two spinners.
  bool get _firstLoad =>
      controller.bookings == null &&
      controller.venues == null &&
      (controller.loadingBookings || controller.loadingVenues);

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
                            compact: true,
                            tint: switch (action) {
                              'cancel' => AppleDesign.statusDanger,
                              'leave' => AppleDesign.statusPending,
                              _ => null,
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
            _VenueMeter(
              venue: venue,
              onTap: () => _push(
                LibraryAreaPage(
                  service: widget.service,
                  venue: venue,
                  onReservationChanged: controller.reservationChanged,
                  onViewReservations: () =>
                      _push(LibraryPage(service: widget.service)),
                ),
              ),
            ),
      ],
    );
  }
}

/// Venue capacity has three readable states: a quiet thin bar while seats are
/// plentiful, a pending tint when they run low, and no bar at all when the
/// school did not report a capacity. Zero free seats is a measurement; a zero
/// total is not, so the latter never renders as a "0" count.
class _VenueMeter extends StatelessWidget {
  const _VenueMeter({required this.venue, this.onTap});

  static const _tightRatio = 0.2;

  final LibraryVenue venue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final known = venue.total > 0;
    final ratio = known ? (venue.free / venue.total).clamp(0.0, 1.0) : null;
    final tight = ratio != null && (venue.free <= 0 || ratio < _tightRatio);
    final color = tight ? AppleDesign.statusPending : AppleDesign.resourceTeal;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  venue.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 3),
                  child: CupertinoListTileChevron(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                known ? '${venue.free}' : '—',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  color: color.resolveFrom(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  known ? '座可用 · 共 ${venue.total} 座' : '余量待确认',
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 10),
            Semantics(
              label: '${venue.name} 空闲比例',
              value: tight ? '余量紧张' : '余量充足',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    key: Key('library-venue-bar-${venue.id}'),
                    height: 3,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: ColoredBox(
                            key: Key('library-venue-fill-${venue.id}'),
                            color: color
                                .resolveFrom(context)
                                .withValues(alpha: tight ? 0.55 : 0.4),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? KeyedSubtree(key: Key('library-venue-${venue.id}'), child: content)
        : CupertinoButton(
            key: Key('library-venue-${venue.id}'),
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              child: content,
            ),
          );
  }
}
