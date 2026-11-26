import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/mutation_dialog.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

import 'library_action_grid.dart';
import 'library_area_page.dart';
import 'library_books_page.dart';
import 'library_controller.dart';
import 'library_history_page.dart';
import 'library_slot_page.dart';
import 'library_stats_page.dart';
import 'library_venue_selection_page.dart';
import 'library_widgets.dart';

/// Library hierarchy and explicit, single-attempt booking actions.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.service, this.onOpenLoans});
  final MirrorService service;
  final VoidCallback? onOpenLoans;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibraryController controller;
  bool confirming = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    controller = LibraryController(widget.service)..addListener(_changed);
    controller.loadBookings();
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      controller.removeListener(_changed);
      controller.dispose();
      _attach();
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  Future<void> perform(LibraryBooking booking, String action) async {
    final current = controller;
    if (confirming ||
        current.submitting ||
        current.loadingBookings ||
        current.bookingError != null ||
        current.bookings?.stale == true) {
      return;
    }
    final revision = current.bookingRevision;
    final label = libraryActionLabel(action);
    final key = '${booking.id}/$action';
    if (current.uncertainActions.contains(key)) return;
    confirming = true;
    bool confirmed;
    try {
      confirmed = await confirmMutation(
        context,
        title: '确认$label？',
        detail:
            '${booking.title}\n${booking.day} ${booking.startTime}–${booking.endTime}',
        action: label,
        destructive: action == 'cancel' || action == 'checkout',
      );
    } finally {
      confirming = false;
    }
    if (confirmed &&
        mounted &&
        identical(controller, current) &&
        revision == current.bookingRevision &&
        !current.loadingBookings &&
        current.bookingError == null &&
        current.bookings?.stale != true &&
        (current.bookings?.bookings.any(
              (value) =>
                  value.id == booking.id &&
                  (value.actions?.contains(action) ?? false),
            ) ??
            false)) {
      await current.perform(booking, action);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  void _openVenueSelection() => _push(
    LibraryVenueSelectionPage(
      controller: controller,
      onOpenStats: () => _push(LibraryStatsPage(service: widget.service)),
      onSelectVenue: (venue) => _push(
        LibraryAreaPage(
          service: widget.service,
          venue: venue,
          onReservationChanged: controller.reservationChanged,
          onViewReservations: () => _push(
            LibraryPage(
              service: widget.service,
              onOpenLoans: widget.onOpenLoans,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: SafeArea(
      child: CustomScrollView(
        key: const Key('library-scroll'),
        slivers: [
          AppleRefreshPageHeader(
            title: '图书馆',
            subtitle: '预约座位、查找书目与管理本人借阅',
            icon: CupertinoIcons.book,
            refreshLabel: '刷新预约',
            busy: controller.loadingBookings,
            onRefresh: () => controller.loadBookings(force: true),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => controller.loadBookings(force: true),
          ),
          SliverList.list(
            children: [
              LibraryBentoGrid(
                onFindSeats: _openVenueSelection,
                onOpenBooks: () =>
                    _push(LibraryBooksPage(service: widget.service)),
                onOpenStats: () =>
                    _push(LibraryStatsPage(service: widget.service)),
                onOpenLoans: widget.onOpenLoans,
              ),
              if (AppPreferencesScope.of(context).favoriteLibraryAreaId != null &&
                  AppPreferencesScope.of(context).favoriteLibraryAreaName !=
                      null)
                AppleSection(
                  header: const Text('常去区域'),
                  children: [
                    AppleListTile(
                      key: const Key('library-favorite-area'),
                      leading: const Icon(CupertinoIcons.bolt_fill),
                      title: Text(
                        AppPreferencesScope.of(
                          context,
                        ).favoriteLibraryAreaName!,
                      ),
                      subtitle: const Text('一键直达座位列表，跳过场馆翻找'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () {
                        final prefs = AppPreferencesScope.of(context);
                        final id = prefs.favoriteLibraryAreaId!;
                        final name = prefs.favoriteLibraryAreaName!;
                        _push(
                          LibrarySlotPage(
                            service: widget.service,
                            area: LibraryArea(
                              id: id,
                              name: name,
                              free: 0,
                              total: 0,
                            ),
                            onReservationChanged: controller.reservationChanged,
                            onViewReservations: () => _push(
                              LibraryPage(
                                service: widget.service,
                                onOpenLoans: widget.onOpenLoans,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              if (_firstLoad)
                const AppleSection(
                  animateSize: false,
                  children: [
                    GinkgoLoadingView(label: '正在读取预约…', compact: true),
                  ],
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
                      leading: const GinkgoIconTile(
                        icon: CupertinoIcons.clock,
                        size: GinkgoIconTokens.md,
                        iconSize: GinkgoIconTokens.glyphMd,
                        color: GinkgoColors.resourceTeal,
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () =>
                          _push(LibraryHistoryPage(service: widget.service)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 96),
            ],
          ),
        ],
      ),
    ),
  );

  /// Both first reads share one quiet, branded wait instead of two spinners.
  bool get _firstLoad =>
      controller.bookings == null && controller.loadingBookings;

  Widget _bookingSection() {
    final items = controller.bookings?.bookings ?? const <LibraryBooking>[];
    final current = items.where(_bookingIsCurrent).toList();
    final ended = items.where(_bookingIsEnded).toList();
    final previous =
        controller.loadingBookings ||
        controller.bookingError != null ||
        controller.bookings?.stale == true;
    final unresolved = items
        .where(
          (booking) => !_bookingIsCurrent(booking) && !_bookingIsEnded(booking),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppleSection(
          header: const Text('当前预约'),
          children: [
            if (controller.loadingBookings || controller.bookingError != null)
              LibrarySectionStatus(
                id: 'bookings',
                loading: controller.loadingBookings,
                hasSnapshot: controller.bookings != null,
                failure: controller.bookingError,
                retry: () => controller.loadBookings(force: true),
              ),
            if (controller.bookings != null && current.isEmpty)
              AppleListTile(
                leading: Icon(
                  unresolved.isEmpty
                      ? CupertinoIcons.book
                      : CupertinoIcons.exclamationmark_circle,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  size: 22,
                ),
                title: Text(
                  previous
                      ? '上次结果中没有已确认的进行中预约'
                      : unresolved.isEmpty
                      ? '当前没有进行中的预约'
                      : '暂无已确认的进行中预约',
                ),
                subtitle: ended.isEmpty
                    ? null
                    : Text('另有 ${ended.length} 条已取消或结束的记录'),
              )
            else
              for (final booking in current) _bookingRow(booking),
          ],
        ),
        if (controller.bookings != null && unresolved.isNotEmpty)
          AppleSection(
            header: const Text('待核实状态'),
            footer: const Text('学校返回的状态尚未识别，请在全部预约记录中核对。'),
            children: [
              for (final booking in unresolved)
                _bookingRow(booking, unresolved: true),
            ],
          ),
      ],
    );
  }

  bool _bookingIsEnded(LibraryBooking booking) => const {
    '取消',
    '已取消',
    '结束',
    '已结束',
    '已完成',
    '过期',
    '已过期',
    '失效',
    '已失效',
  }.contains(booking.statusName.trim());

  /// Resolves the user-facing status label from upstream `statusName`, falling
  /// back to explicit active seat lifecycle flags when `index/subscribe` omits
  /// `status_name` on live bookings (e.g. `flag_out` -> `leave` + `checkout`).
  String _effectiveStatusLabel(LibraryBooking booking) {
    final raw = booking.statusName.trim();
    if (raw.isNotEmpty) return raw;
    final actions = booking.actions ?? const <String>[];
    if (actions.contains('leave') && actions.contains('checkout')) return '使用中';
    if (actions.contains('signin') && actions.contains('checkout')) {
      return '暂离中';
    }
    if (actions.contains('signin') || actions.contains('cancel')) return '已预约';
    return '状态待核实';
  }

  bool _bookingIsCurrent(LibraryBooking booking) {
    if (_bookingIsEnded(booking)) return false;
    final raw = booking.statusName.trim();
    if (const {'使用中', '进行中', '已签到', '暂离中', '已预约'}.contains(raw)) {
      return true;
    }
    // When upstream omits status_name on an active `index/subscribe` record
    // while sending seat lifecycle flags (`leave`/`checkout`/`signin`), treat
    // it as an active current booking rather than forcing an alarming banner.
    if (raw.isEmpty) {
      final actions = booking.actions ?? const <String>[];
      return actions.any(
        (a) => a == 'leave' || a == 'checkout' || a == 'signin',
      );
    }
    return false;
  }

  StatusTone _bookingTone(String label, {required bool unresolved}) {
    if (unresolved) return StatusTone.uncertain;
    return switch (label) {
      '使用中' || '进行中' || '已签到' => StatusTone.success,
      '暂离中' || '已预约' => StatusTone.pending,
      _ => StatusTone.uncertain,
    };
  }

  Widget _bookingRow(LibraryBooking booking, {bool unresolved = false}) {
    final label = _effectiveStatusLabel(booking);
    return LibraryBookingCard(
      booking: booking,
      statusLabel: label,
      statusTone: _bookingTone(label, unresolved: unresolved),
      timeDetail: _bookingDetail(booking),
      actionsDisabled:
          controller.submitting ||
          controller.loadingBookings ||
          controller.bookingError != null ||
          controller.bookings?.stale == true,
      uncertainActions: controller.uncertainActions,
      onAction: (action) => perform(booking, action),
    );
  }

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
}
