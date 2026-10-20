import 'package:flutter/cupertino.dart';

import 'apple_widgets.dart';
import 'mirror_service.dart';
import 'library_history_page.dart';
import 'library_stats_page.dart';
import 'src/rust/api/mirror.dart';

/// booking.lib read-only hierarchy: current booking, venue, area, segment and
/// seat. Every write (reserve/sign-in/leave/checkout/cancel) is out of scope
/// until it gets confirmation and a post-submit re-query.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.service});
  final MirrorService service;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryBookingsResponse? bookings;
  LibraryVenuesResponse? venues;
  String? error;
  String? notice;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.service.libraryVenues(forceRefresh: force),
        widget.service.libraryBookings(forceRefresh: force),
      ]);
      final venueResult = results[0] as LibraryVenuesResponse;
      final bookingResult = results[1] as LibraryBookingsResponse;
      if (!mounted) return;
      final failure = bookingResult.failure ?? venueResult.failure;
      final hasData =
          bookingResult.bookings.isNotEmpty ||
          venueResult.venues.isNotEmpty ||
          bookings != null ||
          venues != null;
      setState(() {
        busy = false;
        if (failure != null && !hasData) {
          error = failureMessage(failure);
          return;
        }
        if (bookingResult.failure == null ||
            bookingResult.bookings.isNotEmpty) {
          bookings = bookingResult;
        }
        if (venueResult.failure == null || venueResult.venues.isNotEmpty) {
          venues = venueResult;
        }
        error = null;
        notice = failure == null
            ? null
            : '${failureMessage(failure)}，正在显示上次结果。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        if (bookings == null && venues == null) {
          error = failureMessage(null);
        } else {
          notice = '${failureMessage(null)}，正在显示上次结果。';
        }
      });
    }
  }

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
            onPressed: busy ? null : () => load(force: true),
            child: busy
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.refresh, size: 24),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: () => load(force: true)),
        SliverList.list(
          children: [
            AppleSection(
              children: [
                AppleListTile(
                  key: const Key('library-public-stats'),
                  title: const Text('在馆人数与空间余量'),
                  subtitle: const Text('两校区官网公开信息，无需预约登录'),
                  leading: const Icon(CupertinoIcons.person_2),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(LibraryStatsPage(service: widget.service)),
                ),
              ],
            ),
            if (notice != null)
              AppleSection(
                children: [
                  AppleListTile(
                    leading: const Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      color: CupertinoColors.systemOrange,
                      size: 20,
                    ),
                    title: Text(notice!),
                  ),
                ],
              ),
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '请检查网络后重试；旧结果会保留。',
                    error: true,
                    action: '重试',
                    onAction: () => load(force: true),
                  ),
                ],
              )
            else if (venues == null && bookings == null)
              AppleSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 10),
                        Text('正在读取图书馆座位数据…'),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _bookingSection(),
              AppleSection(
                children: [
                  AppleListTile(
                    key: const Key('library-history'),
                    title: const Text('全部预约记录'),
                    subtitle: const Text('按页查看进行中、已结束与已取消记录'),
                    leading: const Icon(CupertinoIcons.clock),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        _push(LibraryHistoryPage(service: widget.service)),
                  ),
                ],
              ),
              _venueSection(),
              AppleSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.service.isDemo
                          ? '离线合成样例，不连接图书馆账号；仅用于演示只读座位层级。'
                          : '真实账号只读数据；预约、签到、暂离、离馆与取消尚未开放。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 96),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _bookingSection() {
    final items = bookings?.bookings ?? const <LibraryBooking>[];
    return AppleSection(
      header: const Text('当前预约'),
      children: [
        if (items.isEmpty)
          const AppleListTile(
            leading: Icon(
              CupertinoIcons.book,
              color: CupertinoColors.tertiaryLabel,
              size: 22,
            ),
            title: Text('当前没有进行中的预约'),
            subtitle: Text('预约座位后，这里会显示学校返回的当前记录。'),
          )
        else
          for (final booking in items)
            AppleListTile(
              key: Key('library-booking-${booking.id}'),
              minimumHeight: 68,
              leading: const Icon(
                CupertinoIcons.bookmark_fill,
                color: CupertinoColors.systemGreen,
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
                booking.statusName,
                style: TextStyle(
                  fontSize: 14,
                  color: _bookingEnded(booking)
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : CupertinoColors.systemGreen,
                ),
              ),
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
    final items = venues?.venues ?? const <LibraryVenue>[];
    return AppleSection(
      header: const Text('选择场馆'),
      footer: const Text('空闲数来自学校实时座位接口；进入场馆后依次选择区域、时段与座位。'),
      children: [
        if (items.isEmpty)
          const AppleListTile(
            title: Text('暂无可用场馆'),
            subtitle: Text('学校接口返回了空列表，请稍后刷新。'),
          )
        else
          for (final venue in items)
            AppleListTile(
              key: Key('library-venue-${venue.id}'),
              leading: const Icon(
                CupertinoIcons.building_2_fill,
                color: CupertinoColors.systemIndigo,
                size: 22,
              ),
              title: Text(venue.name),
              subtitle: Text('空闲 ${venue.free} / ${venue.total}'),
              trailing: const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.tertiaryLabel,
              ),
              onTap: () => _push(
                _LibraryAreaPage(service: widget.service, venue: venue),
              ),
            ),
      ],
    );
  }
}

class _LibraryAreaPage extends StatefulWidget {
  const _LibraryAreaPage({required this.service, required this.venue});
  final MirrorService service;
  final LibraryVenue venue;
  @override
  State<_LibraryAreaPage> createState() => _LibraryAreaPageState();
}

class _LibraryAreaPageState extends State<_LibraryAreaPage> {
  List<LibraryArea>? areas;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.libraryAreas(widget.venue.id);
      if (!mounted) return;
      setState(() {
        busy = false;
        if (result.failure != null && result.areas.isEmpty) {
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
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '区域列表读取失败，请稍后重试。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
              )
            else if (areas == null)
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
              )
            else
              AppleSection(
                header: const Text('区域'),
                children: [
                  if (areas!.isEmpty)
                    const AppleListTile(title: Text('暂无开放区域'))
                  else
                    for (final area in areas!)
                      AppleListTile(
                        key: Key('library-area-${area.id}'),
                        title: Text(area.name),
                        subtitle: Text('空闲 ${area.free} / ${area.total}'),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: CupertinoColors.tertiaryLabel,
                        ),
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => _LibrarySlotPage(
                              service: widget.service,
                              area: area,
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
  const _LibrarySlotPage({required this.service, required this.area});
  final MirrorService service;
  final LibraryArea area;
  @override
  State<_LibrarySlotPage> createState() => _LibrarySlotPageState();
}

class _LibrarySlotPageState extends State<_LibrarySlotPage> {
  List<LibrarySlot>? slots;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final result = await widget.service.librarySlots(widget.area.id);
      if (!mounted) return;
      setState(() {
        if (result.failure != null && result.slots.isEmpty) {
          error = failureMessage(result.failure);
          return;
        }
        slots = result.slots;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = failureMessage(null));
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
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '时段读取失败，请稍后重试。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
              )
            else if (slots == null)
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
              )
            else
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
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => _LibrarySeatPage(
                              service: widget.service,
                              area: widget.area,
                              slot: slot,
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
  });
  final MirrorService service;
  final LibraryArea area;
  final LibrarySlot slot;
  @override
  State<_LibrarySeatPage> createState() => _LibrarySeatPageState();
}

class _LibrarySeatPageState extends State<_LibrarySeatPage> {
  List<LibrarySeat>? seats;
  String? error;
  String search = '';
  bool availableOnly = false;
  List<LibrarySeat> visible = [];
  void prepare() {
    final query = search.trim().toLowerCase();
    visible = (seats ?? <LibrarySeat>[])
        .where(
          (seat) =>
              (!availableOnly || seat.available) &&
              (query.isEmpty || seat.name.toLowerCase().contains(query)),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final result = await widget.service.librarySeats(
        areaId: widget.area.id,
        slot: widget.slot,
      );
      if (!mounted) return;
      setState(() {
        if (result.failure != null && result.seats.isEmpty) {
          error = failureMessage(result.failure);
          return;
        }
        seats = result.seats;
        prepare();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = failureMessage(null));
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
        ),
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (error != null)
              AppleSection(
                children: [
                  AppleEmptyState(
                    title: error!,
                    description: '座位列表读取失败，请稍后重试。',
                    error: true,
                    action: '重试',
                    onAction: load,
                  ),
                ],
              )
            else if (seats == null)
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
              )
            else ...[
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
              AppleSection(
                header: Text('${widget.area.name} · ${visible.length} 个座位'),
                footer: const Text('绿色为学校接口标记的空闲座位；预约写操作尚未开放，页面不提供提交按钮。'),
                children: [
                  if (visible.isEmpty)
                    AppleListTile(
                      title: Text(seats!.isEmpty ? '该时段没有座位数据' : '没有符合条件的座位'),
                    )
                  else
                    for (final seat in visible)
                      AppleListTile(
                        key: Key('library-seat-${seat.id}'),
                        leading: Icon(
                          seat.available
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: seat.available
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.tertiaryLabel,
                          size: 22,
                        ),
                        title: Text(seat.name),
                        subtitle: Text(
                          seat.statusName.isEmpty
                              ? (seat.available ? '空闲' : '不可用')
                              : seat.statusName,
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 96),
          ],
        ),
      ],
    ),
  );
}
