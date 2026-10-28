import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

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
  Widget build(BuildContext context) => AppleListTile(
    key: Key('library-$id-status'),
    leading: loading
        ? const GinkgoActivity(size: 17)
        : const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: AppleDesign.statusPending,
            size: 20,
          ),
    title: Text(loading ? (hasSnapshot ? '正在更新…' : '正在加载…') : failure!),
    subtitle: hasSnapshot ? const Text('保留上次结果') : null,
    trailing: loading
        ? null
        : CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: retry,
            child: const Text('重试'),
          ),
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
            minimumSize: const Size(44, 32),
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
  'cancel' => AppleDesign.statusDanger,
  'leave' => AppleDesign.statusPending,
  _ => null,
};
