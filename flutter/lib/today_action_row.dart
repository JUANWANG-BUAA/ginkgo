import 'package:flutter/cupertino.dart';

import 'apple_design.dart';

/// Dashboard action rows reflow naturally and retain a 48dp minimum target.
class TodayActionRow extends StatelessWidget {
  const TodayActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    this.statusColor,
    this.onTap,
    this.emphasized = false,
    this.summary = false,
    this.caption = false,
  });
  final String title;
  final String? subtitle, status;
  final Color? statusColor;
  final VoidCallback? onTap;
  final bool emphasized;

  /// Supporting summaries remain accessible without competing with item titles.
  final bool summary;
  final bool caption;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: emphasized
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
            : GinkgoSpacing.edgeInsetsListTile,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status != null) ...[
                    Text(
                      status!,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor ??
                            (emphasized
                                ? accent
                                : AppleDesign.statusInactive.resolveFrom(context)),
                        fontWeight: (emphasized || statusColor != null)
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: emphasized
                          ? 20
                          : caption
                          ? 13
                          : summary
                          ? 15
                          : 17,
                      fontWeight: emphasized
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: summary || caption
                          ? AppleDesign.statusInactive.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppleDesign.statusInactive.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 12),
              const ExcludeSemantics(child: CupertinoListTileChevron()),
            ],
          ],
        ),
      ),
    );
    final cardTint = statusColor ?? accent;
    final surface = emphasized
        ? Container(
            decoration: BoxDecoration(
              color: cardTint.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cardTint.withValues(alpha: isDark ? 0.26 : 0.18),
                width: 1.0,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: content,
          )
        : content;
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        hint: onTap == null ? null : '打开详情',
        child: onTap == null
            ? surface
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                onPressed: onTap,
                child: surface,
              ),
      ),
    );
  }
}
