import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'package:ginkgo_mirror/application/local_tasks.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';

class TaskDraft {
  const TaskDraft(this.title, this.due);
  final String title, due;
}

/// User must explicitly confirm. Failed saves retain all editable fields.
class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    this.title = '',
    this.due = '',
    this.sourceAssignmentId,
    this.isNew = true,
    required this.onSave,
  });
  final String title, due;
  final String? sourceAssignmentId;
  final bool isNew;
  final Future<bool> Function(TaskDraft draft) onSave;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final title = TextEditingController(text: widget.title);
  late final due = TextEditingController(text: widget.due);
  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    due.dispose();
    super.dispose();
  }

  /// Unsaved edits must be confirmed before the draft is thrown away; an
  /// untouched editor closes without a dialog.
  bool get _dirty => title.text != widget.title || due.text != widget.due;

  Future<void> _confirmDiscard() async {
    final leave = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('返回后本次编辑的内容不会保留。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> pickDeadline({required bool includeTime}) async {
    if (saving) return;
    FocusScope.of(context).unfocus();
    final raw = due.text.trim();
    final parsed = parseSchoolTimestamp(raw) ?? DateTime.tryParse(raw);
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final seed = parsed ?? now;
    // Picker DateTime is a wall-clock carrier, never device timezone conversion.
    var selected = DateTime(
      seed.year,
      seed.month,
      seed.day,
      seed.hour,
      seed.minute,
    );
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (popupContext) => Container(
        color: CupertinoColors.systemBackground.resolveFrom(popupContext),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('截止时间 · 北京时间'),
              ),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 24,
                children: [
                  CupertinoButton(
                    minimumSize: const Size(48, 48),
                    onPressed: () => Navigator.pop(popupContext),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    key: const Key('task-picker-confirm'),
                    minimumSize: const Size(48, 48),
                    onPressed: () => Navigator.pop(popupContext, selected),
                    child: const Text('确定'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  key: const Key('task-deadline-picker'),
                  mode: includeTime
                      ? CupertinoDatePickerMode.dateAndTime
                      : CupertinoDatePickerMode.date,
                  use24hFormat: true,
                  initialDateTime: selected,
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    final day =
        '${result.year.toString().padLeft(4, '0')}-${two(result.month)}-${two(result.day)}';
    setState(() {
      due.text = includeTime
          ? '${day}T${two(result.hour)}:${two(result.minute)}:00+08:00'
          : day;
      error = null;
    });
  }

  Future<void> save() async {
    if (saving || title.text.trim().isEmpty) return;
    final deadline = due.text.trim();
    if (!isLocalTaskDue(deadline)) {
      setState(() => error = '请输入有效日期或带时区的精确时间，也可以清空截止时间。');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final ok = await widget.onSave(TaskDraft(title.text.trim(), deadline));
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
    } catch (_) {
      // A write may have reached storage. Never retry automatically.
    }
    if (mounted) {
      setState(() {
        saving = false;
        error = '保存未确认，草稿已保留。请返回刷新待办核对后再操作。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !_dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || saving) return;
      _confirmDiscard();
    },
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.isNew ? '新增待办' : '编辑待办'),
        leading: saving ? const SizedBox.shrink() : null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppleSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '待办内容',
                        style: GinkgoTypography.headline.copyWith(
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        key: const Key('task-title'),
                        controller: title,
                        padding: const EdgeInsets.all(12),
                        style: GinkgoTypography.body.copyWith(
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        placeholder: '待办内容',
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 5,
                        enabled: !saving,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: GinkgoSpacing.xl),
                      Text(
                        '截止时间（可不设置）',
                        style: GinkgoTypography.headline.copyWith(
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localTaskDueLabel(due.text.trim()),
                        style: GinkgoTypography.footnote.copyWith(
                          color: AppleDesign.statusInactive.resolveFrom(
                            context,
                          ),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CupertinoButton(
                            key: const Key('task-pick-date'),
                            color: CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            minimumSize: const Size(48, 48),
                            onPressed: saving
                                ? null
                                : () => pickDeadline(includeTime: false),
                            child: Text(
                              '选择日期',
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                          CupertinoButton(
                            key: const Key('task-pick-time'),
                            color: CupertinoColors.tertiarySystemFill
                                .resolveFrom(context),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            minimumSize: const Size(48, 48),
                            onPressed: saving
                                ? null
                                : () => pickDeadline(includeTime: true),
                            child: Text(
                              '选择精确时间',
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoColors.label.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        key: const Key('task-due'),
                        controller: due,
                        padding: const EdgeInsets.all(12),
                        style: GinkgoTypography.subheadline.copyWith(
                          color: CupertinoColors.label.resolveFrom(context),
                          height: 1.4,
                        ),
                        placeholder: '无截止时间',
                        enabled: !saving,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '日期：2026-10-22；精确时间：2026-10-22T18:30:00+08:00（北京时间）。清空即不设截止。',
                        style: GinkgoTypography.footnote.copyWith(
                          color: AppleDesign.statusInactive.resolveFrom(
                            context,
                          ),
                          height: 1.4,
                        ),
                      ),
                      CupertinoButton(
                        key: const Key('task-clear-due'),
                        minimumSize: const Size(48, 48),
                        onPressed: saving
                            ? null
                            : () => setState(() => due.clear()),
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                        child: Text(
                          '不设截止时间',
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                (saving
                                        ? CupertinoColors.secondaryLabel
                                        : AppleDesign.statusInactive)
                                    .resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.sourceAssignmentId != null)
              AppleSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '来源：学校作业 · ${widget.sourceAssignmentId}\n编辑标题和截止时间不会解除来源关联。',
                      style: GinkgoTypography.footnote.copyWith(
                        color: AppleDesign.statusInactive.resolveFrom(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
              child: Text(
                '这是本机个人待办，标记完成不代表已向学校提交作业。',
                style: GinkgoTypography.footnote.copyWith(
                  color: AppleDesign.statusInactive.resolveFrom(context),
                  height: 1.4,
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: AppleDesign.statusDanger.resolveFrom(context),
                  ),
                ),
              ),
            Padding(
              padding: GinkgoSpacing.edgeInsetsPage,
              child: CupertinoButton(
                key: const Key('task-save'),
                color: CupertinoTheme.of(context).primaryColor
                    .withValues(alpha: 0.12),
                minimumSize: const Size(48, 48),
                onPressed: saving || title.text.trim().isEmpty ? null : save,
                child: saving
                    ? const GinkgoActivity(size: 17)
                    : Text(
                        widget.isNew ? '确认添加' : '保存',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
