import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'cgyy_booking_fields.dart';
import 'cgyy_booking_slots.dart';
import 'cgyy_models.dart';

/// The venue and the date of the requested booking. Both are read-only: the
/// page was opened for exactly one venue on one day.
class CgyyVenueSection extends StatelessWidget {
  const CgyyVenueSection({
    super.key,
    required this.siteName,
    required this.date,
  });
  final String siteName, date;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: const Text('场地与日期'),
    children: [
      AppleListTile(title: const Text('场地'), subtitle: Text(siteName)),
      AppleListTile(title: const Text('日期'), subtitle: Text(date)),
    ],
  );
}

/// The venues and their bookable slots. One venue can be chosen per booking
/// and at most twelve slots belong to it.
class CgyySlotSection extends StatelessWidget {
  const CgyySlotSection({
    super.key,
    required this.loading,
    required this.loaded,
    required this.choices,
    required this.selectedSpaceId,
    required this.selectedTimeIds,
    required this.onToggleSlot,
    this.enabled = true,
  });
  final bool loading, loaded;
  final List<CgyyBookingChoice> choices;
  final int? selectedSpaceId;
  final Set<int> selectedTimeIds;
  final ValueChanged<CgyyBookingChoice> onToggleSlot;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spaces = <int, String>{
      for (final choice in choices) choice.spaceId: choice.spaceName,
    };
    return AppleSection(
      header: const Text('选择空间与时段'),
      footer: const Text('同一次预约只能选择一个空间，最多选择 12 个时段。'),
      children: [
        if (loading) const GinkgoLoadingView(label: '正在读取预约信息…'),
        if (loaded && choices.isEmpty)
          const AppleEmptyState(title: '当天暂无可预约空间', description: '请返回切换日期或场地。'),
        for (final entry in spaces.entries)
          CgyySlotGrid(
            spaceId: entry.key,
            spaceName: entry.value,
            slots: choices.where((c) => c.spaceId == entry.key).toList(),
            selectedSpaceId: selectedSpaceId,
            selectedTimeIds: selectedTimeIds,
            onToggle: onToggleSlot,
            enabled: enabled,
          ),
      ],
    );
  }
}

/// The details the school asks for. The values stay in memory for this form
/// only; nothing here is written to the device log.
class CgyyDetailsSection extends StatelessWidget {
  const CgyyDetailsSection({
    super.key,
    required this.purposes,
    required this.purposeId,
    required this.phone,
    required this.theme,
    required this.content,
    required this.joiners,
    required this.participantCount,
    required this.philosophy,
    required this.offSchool,
    required this.onSelectPurpose,
    required this.onStepParticipant,
    required this.onTogglePhilosophy,
    required this.onToggleOffSchool,
    this.enabled = true,
  });
  final List<CgyyPurpose> purposes;
  final int? purposeId;
  final TextEditingController phone, theme, content, joiners;
  final int participantCount;
  final bool philosophy, offSchool;
  final ValueChanged<int> onSelectPurpose;
  final ValueChanged<int> onStepParticipant;
  final ValueChanged<bool> onTogglePhilosophy;
  final ValueChanged<bool> onToggleOffSchool;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AppleSection(
    header: const Text('预约信息'),
    footer: const Text('手机号与参与人仅用于本次学校预约，不保存在本机日志中。'),
    children: [
      CgyyBookingTextField(
        label: '手机号（11 位）',
        controller: phone,
        number: true,
        enabled: enabled,
      ),
      CgyyBookingTextField(label: '活动主题', controller: theme, enabled: enabled),
      CgyyPurposePicker(
        purposes: purposes,
        purposeId: purposeId,
        onChanged: onSelectPurpose,
        enabled: enabled,
      ),
      CgyyParticipantStepper(
        value: participantCount,
        onChanged: onStepParticipant,
        enabled: enabled,
      ),
      CgyyBookingTextField(
        label: '活动内容',
        controller: content,
        multiline: true,
        enabled: enabled,
      ),
      CgyyBookingTextField(
        label: '参与人说明',
        controller: joiners,
        enabled: enabled,
      ),
      AppleListTile(
        title: const Text('哲学社会科学类'),
        trailing: CupertinoSwitch(
          value: philosophy,
          onChanged: enabled ? (value) => onTogglePhilosophy(value) : null,
        ),
      ),
      AppleListTile(
        title: const Text('含校外参与人'),
        trailing: CupertinoSwitch(
          value: offSchool,
          onChanged: enabled ? (value) => onToggleOffSchool(value) : null,
        ),
      ),
    ],
  );
}

/// A short guidance line shown after the form acted on the user.
class CgyyNoticeSection extends StatelessWidget {
  const CgyyNoticeSection({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => AppleSection(
    children: [
      AppleListTile(
        leading: const Icon(CupertinoIcons.info_circle),
        title: Text(message),
      ),
    ],
  );
}

/// The actions of the booking form. Only one write path is offered and the
/// refresh stays available while the draft is still editable.
class CgyyBookingActionsSection extends StatelessWidget {
  const CgyyBookingActionsSection({
    super.key,
    required this.busy,
    required this.loading,
    required this.review,
    required this.enabled,
    required this.onSubmit,
    required this.onRefresh,
    required this.onLeave,
  });
  final bool busy, loading, review, enabled;
  final VoidCallback onSubmit, onRefresh, onLeave;

  @override
  Widget build(BuildContext context) => AppleSection(
    footer: const Text('实验功能，真实预约往返仍需人工验收。提交后需核对学校审批状态。'),
    children: [
      CupertinoButton(
        onPressed: busy || loading || review || !enabled ? null : onSubmit,
        child: const Text('确认信息并验证'),
      ),
      if (!review)
        CupertinoButton(
          onPressed: busy || loading ? null : onRefresh,
          child: const Text('刷新空闲时段'),
        ),
      if (review)
        CupertinoButton(
          onPressed: busy ? null : onLeave,
          child: const Text('返回并核对我的预约'),
        ),
    ],
  );
}
