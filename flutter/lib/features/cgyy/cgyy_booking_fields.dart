import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'cgyy_models.dart';
import 'cgyy_widgets.dart';

/// A labelled booking field. The label doubles as the placeholder and as the
/// semantics name so the field stays readable without a visible title.
class CgyyBookingTextField extends StatelessWidget {
  const CgyyBookingTextField({
    super.key,
    required this.label,
    required this.controller,
    this.number = false,
    this.multiline = false,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final bool number, multiline, enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: CupertinoTextFormFieldRow(
      controller: controller,
      placeholder: label,
      keyboardType: number
          ? TextInputType.number
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      enabled: enabled,
      maxLength: number ? 11 : 500,
    ),
  );
}

/// The participant counter. The stepper never leaves the 1–100 range the
/// school accepts and keeps a 48dp touch target on both buttons.
class CgyyParticipantStepper extends StatelessWidget {
  const CgyyParticipantStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AppleListTile(
    title: Text('参与人数：$value 人'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton.tinted(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(48, 48),
          onPressed: enabled && value > 1 ? () => onChanged(value - 1) : null,
          child: const SemanticsLabelIcon(
            label: '减少参与人数',
            icon: CupertinoIcons.minus,
          ),
        ),
        const SizedBox(width: 2),
        CupertinoButton.tinted(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(48, 48),
          onPressed: enabled && value < 100 ? () => onChanged(value + 1) : null,
          child: const SemanticsLabelIcon(
            label: '增加参与人数',
            icon: CupertinoIcons.plus,
          ),
        ),
      ],
    ),
  );
}

/// The activity type picker. The anchored menu keeps every option above the
/// phone tab bar; the selection is owned by the page.
class CgyyPurposePicker extends StatelessWidget {
  const CgyyPurposePicker({
    super.key,
    required this.purposes,
    required this.purposeId,
    required this.onChanged,
    this.enabled = true,
  });
  final List<CgyyPurpose> purposes;
  final int? purposeId;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchor) => AppleListTile(
      title: const Text('活动类型'),
      additionalInfo: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.44,
        child: Text(
          purposes
              .firstWhere((p) => p.id == purposeId, orElse: () => purposes.first)
              .name,
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(CupertinoIcons.chevron_up_chevron_down, size: 14),
      onTap: enabled
          ? () async {
              final selected = await choose<int>(
                anchor,
                '活动类型',
                purposes.map((p) => p.id).toList(),
                (id) => purposes.firstWhere((p) => p.id == id).name,
                selected: purposeId,
              );
              if (selected != null) onChanged(selected);
            }
          : null,
    ),
  );
}
