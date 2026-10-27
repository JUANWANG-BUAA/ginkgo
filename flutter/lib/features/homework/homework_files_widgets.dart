import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/homework_files.dart';

/// 学校提交方式的中文名。未识别的取值原样保留，便于排查协议变化。
String homeworkSubmitMethodLabel(String method) =>
    const {
      'file': '文件',
      'text': '文本',
      'url': '链接',
      'audio': '录音',
      'annotation': '注释',
    }[method] ??
    method;

/// 附件种类的中文名。
String homeworkAttachmentKindLabel(String kind) =>
    const {
      'teacher': '教师附件',
      'rubric': '评分标准',
      'submitted': '已提交文件',
      'annotation': '注释文件',
      'feedback': '评阅附件',
    }[kind] ??
    kind;

/// 提交能力的中文名。
String homeworkCapabilityLabel(String capability) =>
    const {
      'textSubmit': '文本作答',
      'urlSubmit': '链接作答',
      'groupSubmit': '小组作答',
      'fileUpload': '文件上传',
      'fileSubmit': '文件提交',
      'fileReconcile': '结果回查',
    }[capability] ??
    '提交能力';

/// 提交能力状态的中文名。
String homeworkCapabilityStateLabel(String state) =>
    const {
      'unknown': '尚未确认',
      'unsupported': '暂不支持',
      'protocolChanged': '学校协议已变化，相关能力已停用',
      'tempUnavailable': '暂时不可用',
      'authRequired': '需要重新登录',
    }[state] ??
    '状态未知';

/// 作业提交方式与次数摘要。
class HomeworkSubmitSummary extends StatelessWidget {
  const HomeworkSubmitSummary({super.key, required this.data});

  final HomeworkFileWorkspace data;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CupertinoListTile(
        title: const Text('提交方式'),
        subtitle: Text(
          data.methods.isEmpty
              ? '未知'
              : data.methods.map(homeworkSubmitMethodLabel).join('、'),
        ),
      ),
      CupertinoListTile(
        title: const Text('提交次数'),
        subtitle: Text(
          '已提交 ${data.count ?? "未知"} 次 / 上限 ${data.limit == 9999 ? "不限" : data.limit ?? "未知"}',
        ),
      ),
    ],
  );
}

/// 作业附件列表，每项提供保存入口。
class HomeworkAttachmentList extends StatelessWidget {
  const HomeworkAttachmentList({
    super.key,
    required this.attachments,
    required this.busy,
    required this.onDownload,
  });

  final List<HomeworkFileAttachment> attachments;
  final bool busy;
  final ValueChanged<HomeworkFileAttachment> onDownload;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final attachment in attachments)
        CupertinoListTile(
          title: Text(attachment.name, maxLines: 2),
          subtitle: Text(homeworkAttachmentKindLabel(attachment.kind)),
          trailing: CupertinoButton(
            onPressed: busy ? null : () => onDownload(attachment),
            child: const Text('保存'),
          ),
        ),
    ],
  );
}

/// 不可用的提交能力说明。能力不可用时必须说明原因，避免用户反复重试。
class HomeworkCapabilityNotes extends StatelessWidget {
  const HomeworkCapabilityNotes({
    super.key,
    required this.capabilities,
    required this.methods,
  });

  final List<HomeworkCapabilityEvidence> capabilities;
  final List<String> methods;

  @override
  Widget build(BuildContext context) {
    final notes = capabilities.where(
      (c) =>
          c.state != 'available' &&
          (methods.contains(
                const {
                  'textSubmit': 'text',
                  'urlSubmit': 'url',
                  'groupSubmit': 'group',
                }[c.capability],
              ) ||
              const {
                'fileUpload',
                'fileSubmit',
                'fileReconcile',
              }.contains(c.capability)),
    );
    return Column(
      children: [
        for (final capability in notes)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${homeworkCapabilityLabel(capability.capability)}：'
              '${homeworkCapabilityStateLabel(capability.state)}\n'
              '${capability.reason}',
            ),
          ),
      ],
    );
  }
}

/// 个人文件作答的上传与提交操作区。
///
/// 上传后仍需确认提交；存在待确认提交、能力被阻断或已提交时禁用操作。
class HomeworkSubmitActions extends StatelessWidget {
  const HomeworkSubmitActions({
    super.key,
    required this.limitBytes,
    required this.receipt,
    required this.uncertain,
    required this.busy,
    required this.blocked,
    required this.onUpload,
    required this.onSubmit,
  });

  final int limitBytes;
  final HomeworkFileReceipt? receipt;
  final bool uncertain;
  final bool busy;
  final bool blocked;
  final VoidCallback onUpload;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final disabled = busy || blocked;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '个人文件作答 · 客户端上限 ${(limitBytes / (1024 * 1024)).toStringAsFixed(0)} MiB\n'
            '上传后还需确认提交；离开页面可能留下未绑定文件。',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        CupertinoButton(
          onPressed: disabled ? null : onUpload,
          child: const Text('选择并上传文件'),
        ),
        if (receipt != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('待提交文件：${receipt!.name}（${receipt!.size} 字节）'),
          ),
        if (receipt != null && !uncertain)
          CupertinoButton(
            onPressed: disabled ? null : onSubmit,
            child: const Text('提交作业'),
          ),
      ],
    );
  }
}

/// 本机待确认提交的提示与回查入口。
///
/// 记录仅用于回查，不保存文件内容；确认结果前禁止重新上传或提交。
class HomeworkPendingSubmissionNotice extends StatelessWidget {
  const HomeworkPendingSubmissionNotice({
    super.key,
    required this.count,
    required this.busy,
    required this.onReconcile,
  });

  final int count;
  final bool busy;
  final ValueChanged<int> onReconcile;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '发现本机待确认提交。记录仅用于回查，不保存文件内容；确认结果前禁止重新上传或提交。',
        ),
      ),
      for (var index = 0; index < count; index++)
        CupertinoButton(
          onPressed: busy ? null : () => onReconcile(index),
          child: Text('回查待确认提交 ${index + 1}'),
        ),
    ],
  );
}

/// 作业的教师评语与退回说明。
class HomeworkFeedbackNote extends StatelessWidget {
  const HomeworkFeedbackNote({
    super.key,
    required this.data,
  });

  final HomeworkFileWorkspace data;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (data.returned)
        const CupertinoListTile(title: Text('作业已退回，请查看教师要求')),
      if (data.text?.isNotEmpty == true)
        Padding(padding: const EdgeInsets.all(16), child: Text(data.text!)),
      if (data.feedback?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('评语：${data.feedback}'),
        ),
    ],
  );
}

/// 作业提交被阻断时的原因说明。
class HomeworkBlockedNote extends StatelessWidget {
  const HomeworkBlockedNote({
    super.key,
    required this.blockedReason,
    required this.canSubmit,
  });

  final String? blockedReason;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (blockedReason != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(blockedReason!),
        ),
      if (!canSubmit && blockedReason == null)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('当前作业个人文件提交条件尚未确认或不支持，请在官网核对。'),
        ),
    ],
  );
}
