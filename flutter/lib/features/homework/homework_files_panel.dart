import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/file_actions.dart';
import 'package:ginkgo_mirror/application/homework_files.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'homework_files_widgets.dart';

class HomeworkFilesPanel extends StatefulWidget {
  const HomeworkFilesPanel({
    super.key,
    required this.assignmentId,
    required this.title,
    required this.course,
    required this.gateway,
    this.onSubmitted,
    required this.pickFile,
    required this.saveFile,
  });
  final String assignmentId, title, course;
  final HomeworkFilesGateway gateway;
  final VoidCallback? onSubmitted;
  final HomeworkFilePicker pickFile;
  final HomeworkFileSave saveFile;
  @override
  State<HomeworkFilesPanel> createState() => _HomeworkFilesPanelState();
}

class _HomeworkFilesPanelState extends State<HomeworkFilesPanel> {
  HomeworkFileWorkspace? data;
  HomeworkFileReceipt? receipt;
  List<HomeworkPendingSubmission> pending = const [];
  List<HomeworkCapabilityEvidence> capabilities = const [];
  String? message, recoveryMessage;
  FileSaveResult? savedFile;
  bool busy = false, uncertain = false, accepted = false, confirming = false;
  bool recoveryLoaded = false;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant HomeworkFilesPanel old) {
    super.didUpdateWidget(old);
    if (old.gateway != widget.gateway ||
        old.assignmentId != widget.assignmentId ||
        old.title != widget.title ||
        old.course != widget.course) {
      epoch++;
      data = null;
      receipt = null;
      pending = const [];
      capabilities = const [];
      busy = uncertain = accepted = confirming = recoveryLoaded = false;
      message = recoveryMessage = null;
      savedFile = null;
      load();
    }
  }

  bool current(int e) => mounted && e == epoch;
  bool get blockedByPending =>
      uncertain || pending.isNotEmpty || !recoveryLoaded;
  bool get fileCapabilityBlocked =>
      !capabilities.any(
        (c) => c.capability == 'fileSubmit' && c.state == 'available',
      ) ||
      capabilities.any(
        (c) =>
            const {'fileUpload', 'fileSubmit'}.contains(c.capability) &&
            c.state != 'available',
      );

  Future<void> load() async {
    if (busy) return;
    final e = epoch;
    final gateway = widget.gateway;
    final id = widget.assignmentId;
    setState(() {
      busy = true;
      recoveryLoaded = false;
    });
    try {
      final value = await gateway.homeworkFiles(id);
      if (value.assignmentId != id) throw StateError('作业上下文已变化');
      if (current(e)) {
        setState(() {
          data = value;
          if (!uncertain && !accepted) message = null;
        });
      }
    } catch (_) {
      if (current(e)) {
        setState(() => message = '附件及提交信息加载失败，请重试或前往官网');
      }
    }
    if (!current(e)) return;
    try {
      final value = await gateway.pendingHomeworkSubmissions(assignmentId: id);
      if (value.any((p) => p.assignmentId != id || p.handle.isEmpty) ||
          value.map((p) => p.handle).toSet().length != value.length) {
        throw StateError('回查上下文无效');
      }
      if (current(e)) {
        setState(() {
          pending = List.unmodifiable(value);
          recoveryLoaded = true;
          recoveryMessage = null;
        });
      }
    } catch (_) {
      if (current(e)) {
        setState(() {
          recoveryLoaded = false;
          recoveryMessage = '未能核对本机待确认提交记录，暂不能上传或提交。请重试，勿重复提交。';
        });
      }
    }
    if (!current(e)) return;
    try {
      final value = await gateway.homeworkCapabilities(id);
      if (current(e)) setState(() => capabilities = List.unmodifiable(value));
    } catch (_) {
      if (current(e)) {
        setState(() => capabilities = const []);
      }
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    final d = data;
    if (busy ||
        d == null ||
        !d.canSubmit ||
        blockedByPending ||
        fileCapabilityBlocked ||
        accepted) {
      return;
    }
    final e = epoch;
    final gateway = widget.gateway;
    final id = widget.assignmentId;
    setState(() => busy = true);
    try {
      final file = await widget.pickFile();
      if (!current(e) || file == null) return;
      final length = await file.length();
      if (!current(e)) return;
      if (length == 0 || length > d.limitBytes) {
        setState(() => message = '文件为空或超过客户端大小限制');
        return;
      }
      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      if (d.extensions.isNotEmpty && !d.extensions.contains(extension)) {
        setState(() => message = '不支持此文件格式');
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      if (!current(e)) return;
      if (bytes.length != length ||
          bytes.isEmpty ||
          bytes.length > d.limitBytes) {
        setState(() => message = '读取期间文件已变化，请重新选择文件');
        return;
      }
      setState(() => receipt = null);
      final result = await gateway.uploadHomeworkFile(id, file.name, bytes);
      if (result.handle.isEmpty ||
          result.name.isEmpty ||
          result.size != bytes.length) {
        throw StateError('上传回执无效');
      }
      if (current(e)) {
        setState(() {
          receipt = result;
          message = '文件已上传，尚未提交作业';
        });
      }
    } catch (_) {
      if (current(e)) {
        setState(() => message = '上传未完成，作业尚未提交；可能存在未绑定的服务器文件');
      }
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final r = receipt;
    if (busy ||
        r == null ||
        blockedByPending ||
        fileCapabilityBlocked ||
        accepted ||
        data?.canSubmit != true) {
      return;
    }
    final e = epoch;
    final gateway = widget.gateway;
    final course = widget.course, title = widget.title;
    setState(() {
      busy = true;
      confirming = true;
    });
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认提交作业'),
        content: Text(
          '课程：$course\n作业：$title\n最终文件：${r.name}\n大小：${r.size} 字节\n已有提交可能被覆盖。此操作会写入学校系统。上传文件本身不代表作业已提交。',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    if (!current(e)) return;
    setState(() => confirming = false);
    if (confirmed != true) {
      setState(() => busy = false);
      return;
    }
    // Consume the one-shot action before awaiting. Unknown replies only permit reads.
    setState(() => uncertain = true);
    try {
      final result = await gateway.submitHomeworkFile(r.handle);
      if (current(e)) applyResult(result, r.handle);
    } catch (_) {
      if (current(e)) {
        setState(() => message = '提交结果未知，请只回查状态，勿重复提交');
      }
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  void applyResult(MutationResponse result, String handle) {
    final known = const {
      'accepted',
      'notSubmitted',
      'rejected',
    }.contains(result.state);
    setState(() {
      message = known
          ? result.message
          : '${result.message}\n提交结果仍未知，只能回查，勿重复提交。';
      if (known) {
        pending = pending.where((p) => p.handle != handle).toList();
        if (receipt?.handle == handle) receipt = null;
      }
      accepted = accepted || result.state == 'accepted';
      uncertain = !known || pending.isNotEmpty;
    });
    if (result.state == 'accepted') {
      widget.onSubmitted?.call();
      refreshAfterSubmission();
    }
  }

  Future<void> refreshAfterSubmission() async {
    final e = epoch;
    try {
      final value = await widget.gateway.homeworkFiles(widget.assignmentId);
      if (current(e) && value.assignmentId == widget.assignmentId) {
        setState(() => data = value);
      }
    } catch (_) {
      if (current(e)) {
        setState(() => message = '${message ?? "提交结果已确认"}\n附件列表更新失败，请刷新查看。');
      }
    }
  }

  Future<void> reconcile(String handle) async {
    if (busy) return;
    final e = epoch;
    setState(() => busy = true);
    try {
      final result = await widget.gateway.reconcileHomeworkFile(handle);
      if (current(e)) applyResult(result, handle);
    } catch (_) {
      if (current(e)) {
        setState(() => message = '回查失败，请在官网确认，勿重发');
      }
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  Future<void> download(HomeworkFileAttachment attachment) async {
    if (busy) return;
    final e = epoch;
    final gateway = widget.gateway;
    final id = widget.assignmentId;
    setState(() => busy = true);
    try {
      final file = await gateway.downloadHomeworkFile(id, attachment.id);
      if (!current(e)) return;
      final result = await widget.saveFile(
        file,
        isCurrent: () => current(e),
      );
      if (!current(e)) return;
      setState(() {
        savedFile = result.status == FileSaveStatus.saved ? result : null;
        message = switch (result.status) {
          FileSaveStatus.saved => '文件已保存',
          FileSaveStatus.cancelled => '已取消保存',
          FileSaveStatus.stale => '页面已变化，已停止保存',
        };
      });
    } catch (_) {
      if (current(e)) setState(() => message = '附件保存失败，请在官网查看');
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  Future<void> openSavedFile() async {
    final file = savedFile;
    if (busy || file == null) return;
    final e = epoch;
    setState(() => busy = true);
    try {
      final status = await file.open();
      if (current(e)) {
        setState(
          () => message = switch (status) {
            FileOpenStatus.opened => '已请求系统打开文件',
            FileOpenStatus.unsupported => '此平台暂不支持直接打开，请在文件管理器中查看',
            FileOpenStatus.unavailable => '没有可用的打开方式，请在文件管理器中查看',
            FileOpenStatus.stale => '页面已变化，已停止打开文件',
          },
        );
      }
    } catch (_) {
      if (current(e)) setState(() => message = '打开失败，请在文件管理器中查看');
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return AppleSection(
      header: const Text('附件与提交'),
      footer: const Text('上传不等于提交。提交前仍须核对课程、作业与最终文件；结果未知时仅回查。真实学校写入尚待验收。'),
      children: [
        if (message != null)
          CupertinoListTile(title: Text(message!, maxLines: 8)),
        if (savedFile?.canOpen == true)
          CupertinoButton(
            onPressed: busy ? null : openSavedFile,
            child: const Text('打开已保存文件'),
          ),
        if (recoveryMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(recoveryMessage!),
          ),
        if (busy && !confirming)
          const Padding(
            padding: EdgeInsets.all(12),
            child: GinkgoActivity(size: 24),
          ),
        CupertinoListTile(
          title: const Text('文件与提交状态'),
          trailing: CupertinoButton(
            onPressed: busy ? null : load,
            child: Text(d == null ? '重试' : '刷新'),
          ),
        ),
        if (pending.isNotEmpty) ...[
          HomeworkPendingSubmissionNotice(
            count: pending.length,
            busy: busy,
            onReconcile: (index) => reconcile(pending[index].handle),
          ),
        ],
        if (uncertain && receipt != null)
          CupertinoButton(
            onPressed: busy ? null : () => reconcile(receipt!.handle),
            child: const Text('仅回查提交结果'),
          ),
        if (d != null) ...[
          HomeworkSubmitSummary(data: d),
          if (d.methods.any((m) => m != 'file'))
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '目前仅支持个人文件作答；文本、链接、录音、注释及小组作答请前往官网。若作业允许个人文件方式，可继续下方文件流程。',
              ),
            ),
          HomeworkFeedbackNote(data: d),
          HomeworkAttachmentList(
            attachments: d.attachments,
            busy: busy,
            onDownload: download,
          ),
          HomeworkBlockedNote(
            blockedReason: d.blockedReason,
            canSubmit: d.canSubmit,
          ),
          if (capabilities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('提交能力状态尚未确认，请刷新后再试；附件仍可独立查看。'),
            ),
          HomeworkCapabilityNotes(
            capabilities: capabilities,
            methods: d.methods,
          ),
          if (d.canSubmit) ...[
            HomeworkSubmitActions(
              limitBytes: d.limitBytes,
              receipt: receipt,
              uncertain: uncertain,
              busy: busy,
              blocked: blockedByPending || fileCapabilityBlocked || accepted,
              onUpload: upload,
              onSubmit: submit,
            ),
          ],
        ],
      ],
    );
  }
}
