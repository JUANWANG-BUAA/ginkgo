import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/mutation_dialog.dart';
import 'package:ginkgo_mirror/features/reservations/reservation_widgets.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'library_area_page.dart';
import 'library_books_page.dart';
import 'library_controller.dart';
import 'library_history_page.dart';
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
    if (current.submitting) return;
    final label = libraryActionLabel(action);
    final key = '${booking.id}/$action';
    if (current.uncertainActions.contains(key)) return;
    final confirmed = await confirmMutation(
      context,
      title: '确认$label？',
      detail:
          '${booking.title}\n${booking.day} ${booking.startTime}–${booking.endTime}',
      action: label,
      destructive: action == 'cancel' || action == 'checkout',
    );
    if (confirmed && mounted && identical(controller, current)) {
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
            busy: controller.busy,
            onRefresh: () => controller.loadBookings(force: true),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => controller.loadBookings(force: true),
          ),
          SliverList.list(
            children: [
              AppleSection(
                children: [
                  AppleListTile(
                    key: const Key('library-find-seats'),
                    title: const Text('预约座位'),
                    subtitle: const Text('选择场馆、区域与可预约时段'),
                    leading: const Icon(CupertinoIcons.rectangle_grid_2x2),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _openVenueSelection,
                  ),
                  AppleListTile(
                    key: const Key('library-books'),
                    title: const Text('查书目与馆藏'),
                    subtitle: const Text('公开目录检索 · 复本状态'),
                    leading: const Icon(CupertinoIcons.book),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        _push(LibraryBooksPage(service: widget.service)),
                  ),
                  if (widget.onOpenLoans != null)
                    AppleListTile(
                      key: const Key('library-loans-entry'),
                      title: const Text('本人借阅'),
                      subtitle: const Text('按需读取当前账号借阅记录'),
                      leading: const Icon(CupertinoIcons.bookmark),
                      trailing: const CupertinoListTileChevron(),
                      onTap: widget.onOpenLoans,
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
                      leading: const Icon(CupertinoIcons.clock),
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
                title: Text(unresolved.isEmpty ? '当前没有进行中的预约' : '暂无已确认的进行中预约'),
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

  bool _bookingIsCurrent(LibraryBooking booking) {
    if (_bookingIsEnded(booking)) return false;
    // Actions describe which operations the domain currently permits; they do
    // not identify the upstream status. Unknown labels stay out of this group.
    return const {'使用中', '进行中'}.contains(booking.statusName.trim());
  }

  Widget _bookingRow(LibraryBooking booking, {bool unresolved = false}) =>
      Column(
        children: [
          AppleListTile(
            key: Key('library-booking-${booking.id}'),
            minimumHeight: 68,
            leading: Icon(
              unresolved
                  ? CupertinoIcons.exclamationmark_circle
                  : CupertinoIcons.bookmark_fill,
              color: unresolved
                  ? AppleDesign.statusUncertain.resolveFrom(context)
                  : AppleDesign.statusSuccess.resolveFrom(context),
              size: 22,
            ),
            title: Text(booking.title.isEmpty ? '图书馆预约' : booking.title),
            subtitle: Text(
              _bookingDetail(booking),
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            additionalInfo: Text(
              booking.statusName.isEmpty ? '状态待核实' : booking.statusName,
              style: TextStyle(
                fontSize: 14,
                color: unresolved
                    ? AppleDesign.statusUncertain.resolveFrom(context)
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
                      buttonKey: Key('library-action-${booking.id}-$action'),
                      label: libraryActionLabel(action),
                      icon: libraryActionIcon(action),
                      compact: true,
                      tint: libraryActionTint(action),
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
      );

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
