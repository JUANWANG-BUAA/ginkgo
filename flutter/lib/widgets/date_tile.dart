import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';

/// A calendar anchor for an explicit ISO date; unknown formats stay textual.
class DateTile extends StatelessWidget {
  const DateTile(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|[ T])')
        .firstMatch(value);
    final color = GinkgoColors.resourceBlue.resolveFrom(context);
    if (match == null) return Icon(CupertinoIcons.calendar, color: color);
    return ExcludeSemantics(
      child: Container(
        padding: GinkgoSpacing.edgeInsetsBadge,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(GinkgoRadii.compact),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${int.parse(match[2]!)}月',
                style: GinkgoTypography.caption.copyWith(color: color),
              ),
              Text(
                match[3]!,
                style: GinkgoTypography.title2.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
