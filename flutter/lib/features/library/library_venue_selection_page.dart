import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/design/tokens/spacing.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'library_cards.dart';
import 'library_controller.dart';
import 'library_widgets.dart';

/// Focused venue selection route reached from the library's seat-booking task.
class LibraryVenueSelectionPage extends StatefulWidget {
  const LibraryVenueSelectionPage({
    super.key,
    required this.controller,
    required this.onOpenStats,
    required this.onSelectVenue,
  });

  final LibraryController controller;
  final VoidCallback onOpenStats;
  final ValueChanged<LibraryVenue> onSelectVenue;

  @override
  State<LibraryVenueSelectionPage> createState() =>
      _LibraryVenueSelectionPageState();
}

class _LibraryVenueSelectionPageState extends State<LibraryVenueSelectionPage> {
  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(LibraryVenueSelectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _scheduleLoad();
  }

  void _scheduleLoad() {
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller != controller) return;
      _loadIfNeeded();
    });
  }

  void _loadIfNeeded() {
    final controller = widget.controller;
    if (controller.venues == null && !controller.loadingVenues) {
      unawaited(controller.loadVenues());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final venues = controller.venues?.venues;
      final loading = controller.loadingVenues;
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
          context,
        ),
        child: SafeArea(
          child: CustomScrollView(
            key: const Key('library-venues-scroll'),
            slivers: [
              AppleRefreshPageHeader(
                title: '预约座位',
                subtitle: '先选择场馆，再查看开放区域与可预约时段',
                icon: CupertinoIcons.rectangle_grid_2x2,
                refreshLabel: '刷新场馆',
                busy: loading,
                onRefresh: () => controller.loadVenues(force: true),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: () => controller.loadVenues(force: true),
              ),
              SliverList.list(
                children: [
                  AppleSection(
                    children: [
                      AppleListTile(
                        key: const Key('library-public-stats'),
                        title: const Text('在馆人数与空间余量'),
                        subtitle: const Text('学院路与沙河 · 官网公开数据'),
                        leading: const Icon(CupertinoIcons.person_2),
                        trailing: const CupertinoListTileChevron(),
                        onTap: widget.onOpenStats,
                      ),
                    ],
                  ),
                  if (loading || controller.venueError != null)
                    LibrarySectionStatus(
                      id: 'venues',
                      loading: loading,
                      hasSnapshot: venues != null,
                      failure: controller.venueError,
                      retry: () => controller.loadVenues(force: true),
                    ),
                  if (venues != null && venues.isEmpty)
                    const AppleSection(
                      children: [
                        AppleEmptyState(
                          title: '暂无可用场馆',
                          description: '学校接口返回了空列表，请稍后刷新。',
                        ),
                      ],
                    ),
                  if (venues case final items? when items.isNotEmpty)
                    AppleSection(
                      header: const Text('选择场馆'),
                      footer: const Text('空闲数以学校实时查询为准。'),
                      children: [
                        for (final venue in items)
                          LibraryVenueMeter(
                            venue: venue,
                            onTap: () => widget.onSelectVenue(venue),
                          ),
                      ],
                    ),
                  const SizedBox(height: GinkgoSpacing.bottomScrollClearance),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
