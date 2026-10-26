import 'dart:typed_data';

import '../application/homework_files.dart';
import '../application/contracts.dart';

/// Synthetic capability, never reaches a real account or SPOC.
class DemoHomeworkFiles implements HomeworkFilesGateway {
  String? _assignment;
  HomeworkFileReceipt? _receipt;
  Uint8List? _bytes;
  bool _submitted = false;
  @override
  Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({
    String? assignmentId,
  }) async => const [];
  @override
  Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities(
    String assignmentId,
  ) async => const [
    HomeworkCapabilityEvidence(
      capability: 'fileSubmit',
      state: 'available',
      reason: '个人文件合成演示，不写学校系统',
      evidence: 'synthetic',
    ),
    HomeworkCapabilityEvidence(
      capability: 'textSubmit',
      state: 'unsupported',
      reason: '文本作答尚未接入，请前往官网',
      evidence: 'synthetic',
    ),
  ];
  @override
  Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId) async =>
      HomeworkFileWorkspace(
        assignmentId: assignmentId,
        methods: const ['file'],
        extensions: const ['pdf', 'txt', 'zip'],
        attachments: [
          const HomeworkFileAttachment('teacher', '合成作业要求.txt', 'teacher'),
          if (_submitted && _assignment == assignmentId)
            HomeworkFileAttachment(
              'submitted',
              _receipt?.name ?? '合成文件',
              'submitted',
            ),
        ],
        canSubmit: true,
        limitBytes: 20 * 1024 * 1024,
        limit: 9999,
        count: _submitted && _assignment == assignmentId ? 1 : 0,
      );
  @override
  Future<HomeworkFileReceipt> uploadHomeworkFile(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw StateError('Invalid demo file');
    }
    _assignment = assignmentId;
    _bytes = Uint8List.fromList(bytes);
    _submitted = false;
    return _receipt = HomeworkFileReceipt('synthetic-file', name, bytes.length);
  }

  @override
  Future<MutationResponse> submitHomeworkFile(String handle) async {
    if (_receipt?.handle != handle || _submitted) {
      return const MutationResponse(state: 'notSubmitted', message: '演示凭据不可用');
    }
    _submitted = true;
    return const MutationResponse(
      state: 'accepted',
      message: '演示提交成功（未写入学校系统）',
    );
  }

  @override
  Future<MutationResponse> reconcileHomeworkFile(String handle) async =>
      MutationResponse(
        state: _submitted ? 'accepted' : 'notSubmitted',
        message: '演示回查（未访问学校系统）',
      );
  @override
  Future<HomeworkFileDownload> downloadHomeworkFile(
    String assignmentId,
    String attachmentId,
  ) async {
    if (attachmentId == 'teacher') {
      return HomeworkFileDownload(
        '合成作业要求.txt',
        Uint8List.fromList('Synthetic homework requirements'.codeUnits),
      );
    }
    if (_assignment != assignmentId || _submitted == false || _bytes == null) {
      throw StateError('No demo attachment');
    }
    return HomeworkFileDownload(_receipt!.name, _bytes!);
  }
}
