import 'package:flutter/cupertino.dart';

import 'cgyy_models.dart';

/// One venue's bookable slots.
///
/// The grid renders the selection state; the page owns which slots are
/// selected and what a tap changes. A slot reads as selected only while its
/// venue is the chosen one, so switching venue clears the previous times.
class CgyySlotGrid extends StatelessWidget {
  const CgyySlotGrid({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.slots,
    required this.selectedSpaceId,
    required this.selectedTimeIds,
    required this.onToggle,
    this.enabled = true,
  });
  final int spaceId;
  final String spaceName;
  final List<CgyyBookingChoice> slots;
  final int? selectedSpaceId;
  final Set<int> selectedTimeIds;
  final ValueChanged<CgyyBookingChoice> onToggle;
  final bool enabled;

  bool isSelected(CgyyBookingChoice slot) =>
      selectedSpaceId == spaceId && selectedTimeIds.contains(slot.timeId);

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  spaceName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${slots.length} 段可约',
                style: TextStyle(fontSize: 12, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final slot in slots)
                Semantics(
                  selected: isSelected(slot),
                  button: true,
                  label:
                      '$spaceName ${slot.time} ${isSelected(slot) ? '已选' : '空闲'}',
                  child: CupertinoButton(
                    minimumSize: const Size(96, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    color: isSelected(slot)
                        ? accent.withValues(alpha: 0.16)
                        : CupertinoColors.tertiarySystemFill.resolveFrom(
                            context,
                          ),
                    borderRadius: BorderRadius.circular(7),
                    onPressed: enabled ? () => onToggle(slot) : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slot.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        Text(
                          isSelected(slot) ? '已选' : '空闲',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected(slot)
                                ? accent
                                : CupertinoColors.secondaryLabel.resolveFrom(
                                    context,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
