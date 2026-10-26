import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

/// A resource snapshot. A free fraction is not a booking guarantee; unknown
/// totals and empty resources are kept distinct from a fully occupied one.
class ResourceMeter extends StatelessWidget {
  const ResourceMeter({
    super.key,
    required this.label,
    required this.available,
    required this.total,
    required this.unit,
    this.detail,
    this.onTap,
  });
  final String label, unit;
  final String? detail;
  final int? available, total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final free = available;
    final capacity = total;
    final known = free != null && capacity != null;
    final countsLabel = free == null
        ? (capacity == null ? '官网未提供数量' : '可用数量未提供 · 共 $capacity $unit')
        : capacity == null
        ? '$unit可用 · 总量未提供'
        : '$unit可用 · 共 $capacity $unit';
    final ratio = known && capacity > 0
        ? (free / capacity).clamp(0.0, 1.0)
        : null;
    final color = (free == 0
            ? AppleDesign.statusPending
            : AppleDesign.resourceTeal)
        .resolveFrom(context);
    final fillColor = color.withValues(alpha: free == 0 ? 0.90 : 0.55);
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
                  label,
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
                free == null ? '—' : '$free',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  countsLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 10),
            Semantics(
              label: '$label 空闲比例',
              value: '${(ratio * 100).round()}%',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 4,
                    child: ColoredBox(
                      color: CupertinoColors.tertiarySystemFill.resolveFrom(
                        context,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: ColoredBox(
                            color: fillColor,
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
          if (detail != null) ...[
            const SizedBox(height: 7),
            Text(
              detail!,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
          if (known && capacity == 0) ...[
            const SizedBox(height: 7),
            Text(
              '暂未提供此类资源',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? content
        : CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              child: content,
            ),
          );
  }
}
