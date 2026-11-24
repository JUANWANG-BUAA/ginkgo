import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

/// Tactile 2×2 Bento action deck for the Library tab.
///
/// Replaces the flat 3-row settings-style list with high-craft interactive
/// surface tiles while preserving all existing test keys, minimum 48dp touch
/// targets, dark mode contrast, and narrow-screen / large-text stacking.
class LibraryBentoGrid extends StatelessWidget {
  const LibraryBentoGrid({
    super.key,
    required this.onFindSeats,
    required this.onOpenBooks,
    required this.onOpenStats,
    this.onOpenLoans,
  });

  final VoidCallback onFindSeats;
  final VoidCallback onOpenBooks;
  final VoidCallback onOpenStats;
  final VoidCallback? onOpenLoans;

  @override
  Widget build(BuildContext context) {
    final tiles = <_BentoTileData>[
      _BentoTileData(
        key: const Key('library-find-seats'),
        title: '预约座位',
        subtitle: '选场馆与空闲时段',
        icon: CupertinoIcons.rectangle_grid_2x2_fill,
        color: GinkgoColors.resourceBlue,
        onTap: onFindSeats,
      ),
      _BentoTileData(
        key: const Key('library-books'),
        title: '查书目与馆藏',
        subtitle: '公开检索与复本状态',
        icon: CupertinoIcons.book_fill,
        color: GinkgoColors.resourceTeal,
        onTap: onOpenBooks,
      ),
      if (onOpenLoans != null)
        _BentoTileData(
          key: const Key('library-loans-entry'),
          title: '本人借阅',
          subtitle: '按需查在借与到期日',
          icon: CupertinoIcons.bookmark_fill,
          color: GinkgoColors.resourcePurple,
          onTap: onOpenLoans!,
        ),
      _BentoTileData(
        key: const Key('library-live-stats'),
        title: '在馆实时人数',
        subtitle: '两校区液位拥挤度',
        icon: CupertinoIcons.chart_bar_alt_fill,
        color: GinkgoColors.accent,
        onTap: onOpenStats,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GinkgoSpacing.pageInset,
        GinkgoSpacing.md,
        GinkgoSpacing.pageInset,
        GinkgoSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn =
              constraints.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.45;
          if (singleColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(height: GinkgoSpacing.sm),
                  _BentoTile(data: tiles[i]),
                ],
              ],
            );
          }
          final rows = <Widget>[];
          for (var i = 0; i < tiles.length; i += 2) {
            final left = tiles[i];
            final right = i + 1 < tiles.length ? tiles[i + 1] : null;
            if (rows.isNotEmpty) {
              rows.add(const SizedBox(height: GinkgoSpacing.sm));
            }
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _BentoTile(data: left)),
                    if (right != null) ...[
                      const SizedBox(width: GinkgoSpacing.sm),
                      Expanded(child: _BentoTile(data: right)),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );
        },
      ),
    );
  }
}

class _BentoTileData {
  const _BentoTileData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final Key key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.data});

  final _BentoTileData data;

  static const double _iconSize = 34.0;
  static const double _minTileHeight = 92.0;
  static const double _minTouchTarget = 48.0;
  static const double _hairline = 0.75;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final surface = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final border = data.color.withValues(alpha: dark ? 0.28 : 0.18);
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoButton(
      key: data.key,
      padding: EdgeInsets.zero,
      minimumSize: const Size(_minTouchTarget, _minTileHeight),
      onPressed: data.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(GinkgoRadii.group),
          border: Border.all(color: border, width: _hairline),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: data.color.withValues(alpha: 0.08),
                    blurRadius: GinkgoSpacing.md,
                    offset: const Offset(0, GinkgoSpacing.xs),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(GinkgoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GinkgoIconTile(
                    icon: data.icon,
                    size: _iconSize,
                    color: data.color,
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: GinkgoSpacing.md,
                    color: secondary,
                  ),
                ],
              ),
              const SizedBox(height: GinkgoSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GinkgoTypography.headline.copyWith(color: label),
                  ),
                  const SizedBox(height: GinkgoSpacing.xs),
                  Text(
                    data.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GinkgoTypography.caption.copyWith(color: secondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
