import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/academic_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'cgyy_models.dart';

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

/// The CGYY page header shared by the booking and the review page. Section,
/// subtitle and icon stay identical so the whole domain reads as one surface.
class CgyyPageHeader extends StatelessWidget {
  const CgyyPageHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => ApplePageHeader(
    largeTitle: Text(title),
    section: '空间资源',
    subtitle: '选择场馆并查看可预约空间',
    icon: CupertinoIcons.person_3,
    border: null,
  );
}

/// Error and empty states share one block so the hub and the day page cannot
/// drift apart. The retry action only appears when a retry is possible.
class CgyyStatusSection extends StatelessWidget {
  const CgyyStatusSection({
    super.key,
    required this.title,
    required this.description,
    this.onRetry,
    this.isError = false,
  });
  final String title, description;
  final VoidCallback? onRetry;
  final bool isError;
  @override
  Widget build(BuildContext context) => AppleSection(
    children: [
      AppleEmptyState(
        title: title,
        description: description,
        action: onRetry == null ? null : '重试',
        onAction: onRetry,
        error: isError,
      ),
    ],
  );
}

/// Two-action confirmation dialog shared by every CGYY write. The route guard
/// keeps a stale dialog from popping a screen the user already left.
class CgyyConfirmDialog extends StatelessWidget {
  const CgyyConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    this.confirmKey,
    this.destructive = false,
    this.isDefault = false,
  });
  final String title, content, cancelLabel, confirmLabel;
  final Key? confirmKey;
  final bool destructive, isDefault;
  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(title),
    content: Text(content),
    actions: [
      CupertinoDialogAction(
        onPressed: () {
          if (ModalRoute.of(context)?.isCurrent ?? false) {
            Navigator.pop(context, false);
          }
        },
        child: Text(cancelLabel),
      ),
      CupertinoDialogAction(
        key: confirmKey,
        isDestructiveAction: destructive,
        isDefaultAction: isDefault,
        onPressed: () {
          if (ModalRoute.of(context)?.isCurrent ?? false) {
            Navigator.pop(context, true);
          }
        },
        child: Text(confirmLabel),
      ),
    ],
  );
}

/// Shows a CGYY confirmation and resolves to true only after an explicit
/// confirm tap. Dismissing the dialog is never a confirmation.
Future<bool> showCgyyConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String cancelLabel,
  required String confirmLabel,
  Key? confirmKey,
  bool destructive = false,
  bool isDefault = false,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CgyyConfirmDialog(
      title: title,
      content: content,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
      destructive: destructive,
      isDefault: isDefault,
    ),
  );
  return confirmed == true;
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
