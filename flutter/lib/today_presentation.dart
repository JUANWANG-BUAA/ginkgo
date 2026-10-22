import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';

/// A quiet inset rule for rows nested inside a reveal animation.
class TodayVisualDivider extends StatelessWidget {
  const TodayVisualDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: GinkgoSpacing.edgeInsetsPage,
    child: ColoredBox(
      color: CupertinoColors.separator
          .resolveFrom(context)
          .withValues(alpha: 0.16),
      child: const SizedBox(height: 0.5, width: double.infinity),
    ),
  );
}

/// Today-only typography and spacing; the shared section keeps its behavior.
class TodayVisualSection extends StatelessWidget {
  const TodayVisualSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final Widget? header, footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 4 : 0),
    child: AppleSection(
      header: header == null
          ? null
          : DefaultTextStyle.merge(
              style: GinkgoTypography.footnote.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
              ),
              child: header!,
            ),
      footer: footer == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(
                color: AppleDesign.statusInactive.resolveFrom(context),
              ),
              child: footer!,
            ),
      children: children,
    ),
  );
}
