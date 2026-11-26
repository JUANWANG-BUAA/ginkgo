import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_visuals.dart';

/// The tone of a value or a status. Color only reinforces a word that is
/// already written next to it, so the meaning survives color blindness,
/// dark mode and grayscale screenshots.
enum StatusTone { neutral, accent, success, pending, danger, uncertain }

Color statusToneColor(BuildContext context, StatusTone tone) {
  switch (tone) {
    case StatusTone.neutral:
      return CupertinoColors.secondaryLabel.resolveFrom(context);
    case StatusTone.accent:
      return CupertinoTheme.of(context).primaryColor;
    case StatusTone.success:
      return AppleDesign.statusSuccess.resolveFrom(context);
    case StatusTone.pending:
      return AppleDesign.statusPending.resolveFrom(context);
    case StatusTone.danger:
      return AppleDesign.statusDanger.resolveFrom(context);
    case StatusTone.uncertain:
      return AppleDesign.statusUncertain.resolveFrom(context);
  }
}

/// A status is always three things: a word, an icon and a color. The word
/// carries the meaning on its own; the other two only reinforce it.
///
/// The vocabulary mirrors the shared Apple status presentation so the same
/// state reads the same way in every module.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.tone = StatusTone.neutral,
    this.compact = false,
  });

  /// 待确认 — the source did not confirm the state.
  const StatusChip.unknown(this.label, {super.key, this.compact = false})
    : icon = CupertinoIcons.question_circle_fill,
      tone = StatusTone.uncertain;

  /// 已完成 / 已签到 / 已提交.
  const StatusChip.done(this.label, {super.key, this.compact = false})
    : icon = CupertinoIcons.check_mark_circled_solid,
      tone = StatusTone.success;

  /// 待处理 / 未签到 — the user still has to act.
  const StatusChip.pending(this.label, {super.key, this.compact = false})
    : icon = CupertinoIcons.exclamationmark_circle_fill,
      tone = StatusTone.pending;

  /// 未通过 / 失败.
  const StatusChip.failed(this.label, {super.key, this.compact = false})
    : icon = CupertinoIcons.clear_circled_solid,
      tone = StatusTone.danger;

  final String label;
  final IconData icon;
  final StatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = statusToneColor(context, tone);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GinkgoBadge(
        label: label,
        icon: icon,
        color: color,
        compact: compact,
      ),
    );
  }
}
