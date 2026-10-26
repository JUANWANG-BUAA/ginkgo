import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/academic_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';

/// Venue card content shared by the hub page and the day query page.
Widget cgyySiteContent(CgyySite site, {bool chevron = false}) {
  final tint = site.campus.contains('沙河')
      ? CupertinoColors.systemBlue
      : CupertinoColors.systemTeal;
  return CgyyTileContent(
    icon: CupertinoIcons.building_2_fill,
    tint: tint,
    title: site.name.isEmpty ? site.venue : site.name,
    detail: [
      site.venue,
      site.campus,
    ].where((value) => value.isNotEmpty && value != site.name).join(' · '),
    badges: [
      if (site.seats != null)
        AcademicBadge(
          '${site.seats} 座',
          tint: tint,
          icon: CupertinoIcons.person_2,
        ),
    ],
    chevron: chevron,
  );
}

/// Inset rows inherit Cupertino press feedback and add a quiet pointer state.
/// The whole row remains a single action with its full readable label.
class CgyyInteractiveRow extends StatefulWidget {
  const CgyyInteractiveRow({
    super.key,
    required this.child,
    required this.onTap,
  });
  final Widget child;
  final VoidCallback onTap;
  @override
  State<CgyyInteractiveRow> createState() => _CgyyInteractiveRowState();
}

class _CgyyInteractiveRowState extends State<CgyyInteractiveRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      color: CupertinoColors.systemTeal
          .resolveFrom(context)
          .withValues(alpha: hovered ? 0.045 : 0),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: widget.onTap,
        child: widget.child,
      ),
    ),
  );
}

class CgyyTileContent extends StatelessWidget {
  const CgyyTileContent({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    this.badges = const [],
    this.chevron = false,
  });
  final IconData icon;
  final CupertinoDynamicColor tint;
  final String title, detail;
  final List<Widget> badges;
  final bool chevron;
  @override
  Widget build(BuildContext context) {
    final color = tint.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: badges),
                ],
              ],
            ),
          ),
          if (chevron) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CgyySlotRow extends StatelessWidget {
  const CgyySlotRow({super.key, required this.time, required this.status});
  final String time, status;
  @override
  Widget build(BuildContext context) {
    final (tint, icon) = switch (status) {
      '空闲' => (AppleDesign.statusSuccess, CupertinoIcons.checkmark_circle),
      '不可预约' => (AppleDesign.statusInactive, CupertinoIcons.minus_circle),
      _ => (AppleDesign.statusUncertain, CupertinoIcons.question_circle),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            time,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          );
          final badge = AcademicBadge(status, tint: tint, icon: icon);
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 9), badge],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}

/// Icon with a readable semantics label for icon-only stepper buttons.
class SemanticsLabelIcon extends StatelessWidget {
  const SemanticsLabelIcon({
    super.key,
    required this.label,
    required this.icon,
  });
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) =>
      Semantics(label: label, child: Icon(icon, size: 18));
}
