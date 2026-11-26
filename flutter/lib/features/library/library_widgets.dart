import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart' show LibraryBooking;
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/reservations/reservation_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/widgets/status_chip.dart';

/// Library chrome shared by the venue / area / slot / seat / books pages.
/// Every piece keeps the same visual language: one quiet inset group, one
/// branded wait, and text that states what the school actually reported.

/// Inline status for a section that is still loading or that failed while
/// keeping its last known content. The retry repeats exactly the read that
/// failed.
class LibrarySectionStatus extends StatelessWidget {
  const LibrarySectionStatus({
    super.key,
    required this.id,
    required this.loading,
    required this.hasSnapshot,
    required this.failure,
    required this.retry,
  });

  final String id;
  final bool loading;
  final bool hasSnapshot;
  final String? failure;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => SectionFeedback(
    key: Key('library-$id-status'),
    loading: loading,
    label: hasSnapshot ? '正在更新…' : '正在加载…',
    hasData: hasSnapshot,
    error: failure,
    onRetry: retry,
  );
}

/// The toggle of a collapsible read-only note. The label states the current
/// state so TalkBack users know the note is collapsed before they open it.
class LibraryDisclosureToggle extends StatelessWidget {
  const LibraryDisclosureToggle({
    super.key,
    required this.label,
    required this.expanded,
    required this.onToggle,
    this.toggleKey,
  });

  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
        child: Semantics(
          button: true,
          label: label,
          expanded: expanded,
          onTap: onToggle,
          excludeSemantics: true,
          child: CupertinoButton(
            key: toggleKey,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(48, 48),
            onPressed: onToggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.info, size: 14, color: secondary),
                const SizedBox(width: 4),
                Text(
                  expanded ? '收起说明' : label,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 12,
                  color: secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The body of a read-only note that the reader opened on purpose.
class LibraryNoteText extends StatelessWidget {
  const LibraryNoteText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

/// The human label of one booking action. The same mapping is used by the
/// confirmation dialog and by the inline action buttons, so a user never
/// confirms one wording and sees another.
String libraryActionLabel(String action) => switch (action) {
  'signin' => '签到入座 / 返回',
  'leave' => '暂离',
  'checkout' => '离馆',
  'cancel' => '取消预约',
  _ => action,
};

/// The icon of one booking action.
IconData libraryActionIcon(String action) => switch (action) {
  'signin' => CupertinoIcons.checkmark_seal,
  'leave' => CupertinoIcons.pause_circle,
  'checkout' => CupertinoIcons.arrow_right_circle,
  _ => CupertinoIcons.xmark_circle,
};

/// The semantic tint of one booking action. Actions without a tint keep the
/// theme accent.
CupertinoDynamicColor? libraryActionTint(String action) => switch (action) {
  'cancel' || 'checkout' => AppleDesign.statusDanger,
  'leave' => AppleDesign.statusPending,
  _ => null,
};

/// Clean, structured booking card for active or pending library seat records.
///
/// Splits long slash-separated room paths (`学院路校区图书馆/四楼/四层中文借阅室东区`)
/// into a crisp primary room headline + subtle breadcrumb, pairs a compact
/// status chip on top-right, and renders an even full-width action bar below a
/// hairline divider instead of cramped trailing text or floating centered pills.
class LibraryBookingCard extends StatelessWidget {
  const LibraryBookingCard({
    super.key,
    required this.booking,
    required this.statusLabel,
    required this.statusTone,
    required this.timeDetail,
    required this.actionsDisabled,
    required this.uncertainActions,
    required this.onAction,
  });

  final LibraryBooking booking;
  final String statusLabel;
  final StatusTone statusTone;
  final String timeDetail;
  final bool actionsDisabled;
  final Set<String> uncertainActions;
  final ValueChanged<String> onAction;

  (String, String?) _splitLocation(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return ('图书馆预约', null);
    final segments = trimmed
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.length <= 1) return (trimmed, null);
    return (segments.last, segments.sublist(0, segments.length - 1).join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final (headline, breadcrumb) = _splitLocation(booking.title);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final actions = booking.actions ?? const <String>[];
    final chip = switch (statusTone) {
      StatusTone.success => StatusChip.done(statusLabel, compact: true),
      StatusTone.pending => StatusChip.pending(statusLabel, compact: true),
      StatusTone.danger => StatusChip(
        label: statusLabel,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        tone: StatusTone.danger,
        compact: true,
      ),
      StatusTone.uncertain ||
      StatusTone.neutral ||
      StatusTone.accent => StatusChip.unknown(statusLabel, compact: true),
    };

    return Padding(
      key: Key('library-booking-${booking.id}'),
      padding: GinkgoSpacing.edgeInsetsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (breadcrumb != null) ...[
                      Text(
                        breadcrumb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GinkgoTypography.caption.copyWith(
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: GinkgoSpacing.xs),
                    ],
                    Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GinkgoTypography.headline.copyWith(
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GinkgoSpacing.sm),
              chip,
            ],
          ),
          if (timeDetail.isNotEmpty) ...[
            const SizedBox(height: GinkgoSpacing.xs),
            Row(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: GinkgoSpacing.md,
                  color: secondary,
                ),
                const SizedBox(width: GinkgoSpacing.xs),
                Expanded(
                  child: Text(
                    timeDetail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GinkgoTypography.footnote.copyWith(
                      color: secondary,
                      fontFeatures: GinkgoTypography.tabularDigits,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: GinkgoSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: separator.withValues(alpha: 0.45),
                    width: GinkgoSpacing.hairline,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: GinkgoSpacing.sm),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: GinkgoSpacing.sm),
                      Expanded(
                        child: ReservationActionButton(
                          buttonKey: Key(
                            'library-action-${booking.id}-${actions[i]}',
                          ),
                          label: libraryActionLabel(actions[i]),
                          icon: libraryActionIcon(actions[i]),
                          compact: true,
                          tint: libraryActionTint(actions[i]),
                          onPressed:
                              actionsDisabled ||
                                  uncertainActions.contains(
                                    '${booking.id}/${actions[i]}',
                                  )
                              ? null
                              : () => onAction(actions[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
