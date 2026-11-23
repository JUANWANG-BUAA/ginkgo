import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/homework_files.dart';
import 'package:ginkgo_mirror/application/service_health.dart';
import 'package:ginkgo_mirror/infrastructure/native_command.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

mixin NativeHomeworkFiles implements HomeworkFilesGateway {
  String? get expectedAccount;

  Future<HomeworkResponse> homework({bool forceRefresh = false}) =>
      coalescedNativeRead(
        account: expectedAccount,
        key: 'homework',
        forceRefresh: forceRefresh,
        command: () => ServiceHealthTracker.shared.observe(
          ServiceEndpointId.homework,
          () => boundedNativeRead(
            () => live.loadHomework(forceRefresh: forceRefresh),
          ),
          failureOf: (r) => r.failure,
          staleOf: (r) => r.failure != null && r.fetchedAt != null,
        ),
      );

  Future<live.HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadHomeworkDetail(
      assignmentId: assignmentId,
      forceRefresh: forceRefresh,
    ),
  );

  String get _homeworkOwner {
    final owner = expectedAccount;
    if (owner == null || owner.isEmpty) {
      throw StateError('账号未绑定');
    }
    return owner;
  }

  Future<void> _prepareHomework() async {
    final root = await getApplicationSupportDirectory();
    final canonical = await root.resolveSymbolicLinks();
    final r = await boundedNativeRead(
      () => live.configureHomeworkRecovery(
        expectedAccount: _homeworkOwner,
        storageRoot: canonical,
      ),
    );
    if (r.failure != null || r.configured != true) {
      throw StateError('提交保护存储不可用，已阻止写入；附件读取不受影响');
    }
  }

  @override
  Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({
    String? assignmentId,
  }) async {
    await _prepareHomework();
    final r = await boundedNativeRead(
      () => live.pendingHomeworkSubmissions(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
      ),
    );
    if (r.failure != null || r.data == null) {
      throw StateError('未能读取待核实提交，请勿重复提交');
    }
    return List.unmodifiable(
      r.data!.map(
        (v) => HomeworkPendingSubmission(
          v.handle,
          v.assignmentId,
          fileName: v.fileName,
          size: v.size,
        ),
      ),
    );
  }

  @override
  Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities(
    String assignmentId,
  ) async {
    await _prepareHomework();
    final r = await boundedNativeRead(
      () => live.homeworkCapabilities(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
      ),
    );
    if (r.failure != null || r.data == null) {
      throw StateError('作业接口状态检测失败，请重新登录或重试');
    }
    return List.unmodifiable(
      r.data!.map(
        (v) => HomeworkCapabilityEvidence(
          capability: v.capability,
          state: switch (v.state) {
            live.HomeworkCapabilityStateDto.available => 'available',
            live.HomeworkCapabilityStateDto.unknown => 'unknown',
            live.HomeworkCapabilityStateDto.unsupported => 'unsupported',
            live.HomeworkCapabilityStateDto.protocolChanged =>
              'protocolChanged',
            live.HomeworkCapabilityStateDto.tempUnavailable =>
              'tempUnavailable',
            live.HomeworkCapabilityStateDto.authRequired => 'authRequired',
          },
          reason: v.reason,
          evidence: v.evidence,
        ),
      ),
    );
  }

  @override
  Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId) async {
    final r = await boundedNativeRead(
      () => live.homeworkFileWorkspace(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
      ),
    );
    if (r.failure != null || r.data == null) {
      throw StateError('作业服务暂不可用，请刷新或前往官网');
    }
    final d = r.data!;
    return HomeworkFileWorkspace(
      assignmentId: d.assignmentId,
      methods: List.unmodifiable(d.allowedMethods),
      extensions: List.unmodifiable(d.allowedExtensions),
      limit: d.submissionLimit,
      count: d.submittedCount,
      returned: d.returned,
      text: d.submittedText,
      feedback: d.feedback,
      attachments: List.unmodifiable(
        d.attachments.map((a) => HomeworkFileAttachment(a.id, a.name, a.kind)),
      ),
      canSubmit: d.canSubmitFile,
      blockedReason: d.blockedReason,
      limitBytes: d.fileLimitBytes,
    );
  }

  @override
  Future<HomeworkFileReceipt> uploadHomeworkFile(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) async {
    await _prepareHomework();
    final r = await boundedNativeWrite(
      () => live.uploadHomeworkFile(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
        name: name,
        bytes: bytes,
      ),
    );
    if (r.failure != null || r.data == null) {
      throw StateError('作业服务暂不可用，请刷新或前往官网');
    }
    return HomeworkFileReceipt(
      r.data!.handle,
      r.data!.fileName,
      r.data!.size.toInt(),
    );
  }

  @override
  Future<MutationResponse> submitHomeworkFile(String handle) async {
    await _prepareHomework();
    return boundedNativeWrite(
      () => live.submitHomeworkFile(
        expectedAccount: _homeworkOwner,
        handle: handle,
        confirmed: true,
      ),
    );
  }

  @override
  Future<MutationResponse> reconcileHomeworkFile(String handle) => live
      .reconcileHomeworkFile(expectedAccount: _homeworkOwner, handle: handle);

  @override
  Future<HomeworkFileDownload> downloadHomeworkFile(
    String assignmentId,
    String attachmentId,
  ) async {
    final r = await boundedNativeWrite(
      () => live.downloadHomeworkFile(
        expectedAccount: _homeworkOwner,
        assignmentId: assignmentId,
        attachmentId: attachmentId,
      ),
    );
    if (r.failure != null || r.bytes == null || r.name == null) {
      throw StateError('附件下载失败，请前往官网');
    }
    return HomeworkFileDownload(r.name!, Uint8List.fromList(r.bytes!));
  }
}
