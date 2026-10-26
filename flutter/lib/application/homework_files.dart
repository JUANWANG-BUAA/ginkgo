import 'dart:typed_data';

import 'package:ginkgo_mirror/application/contracts.dart';

/// Business-only capability, independent from school endpoints and AcademicGateway.
abstract interface class HomeworkFilesGateway {
  Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId);
  Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({
    String? assignmentId,
  });
  Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities(
    String assignmentId,
  );
  Future<HomeworkFileReceipt> uploadHomeworkFile(
    String assignmentId,
    String name,
    Uint8List bytes,
  );
  Future<MutationResponse> submitHomeworkFile(String handle);
  Future<MutationResponse> reconcileHomeworkFile(String handle);
  Future<HomeworkFileDownload> downloadHomeworkFile(
    String assignmentId,
    String attachmentId,
  );
}

/// Only opaque ownership-bound recovery metadata, never file bytes or names.
class HomeworkPendingSubmission {
  const HomeworkPendingSubmission(
    this.handle,
    this.assignmentId, {
    this.fileName,
    this.size,
  });
  final String handle, assignmentId;
  final String? fileName;
  final int? size;
  factory HomeworkPendingSubmission.fromJson(Map<String, dynamic> json) =>
      HomeworkPendingSubmission(
        json['handle'] as String,
        json['assignmentId'] as String,
        fileName: json['fileName'] as String?,
        size: json['size'] as int?,
      );
}

class HomeworkCapabilityEvidence {
  const HomeworkCapabilityEvidence({
    required this.capability,
    required this.state,
    required this.reason,
    required this.evidence,
  });
  final String capability, state, reason, evidence;
  factory HomeworkCapabilityEvidence.fromJson(Map<String, dynamic> json) =>
      HomeworkCapabilityEvidence(
        capability: json['capability'] as String,
        state: json['state'] as String,
        reason: json['reason'] as String,
        evidence: json['evidence'] as String,
      );
}

class HomeworkFileAttachment {
  const HomeworkFileAttachment(this.id, this.name, this.kind);
  final String id, name, kind;
}

class HomeworkFileWorkspace {
  const HomeworkFileWorkspace({
    required this.assignmentId,
    required this.methods,
    required this.extensions,
    required this.attachments,
    required this.canSubmit,
    required this.limitBytes,
    this.limit,
    this.count,
    this.blockedReason,
    this.returned = false,
    this.text,
    this.feedback,
  });
  final String assignmentId;
  final List<String> methods, extensions;
  final List<HomeworkFileAttachment> attachments;
  final bool canSubmit, returned;
  final int limitBytes;
  final int? limit, count;
  final String? blockedReason, text, feedback;
  factory HomeworkFileWorkspace.fromJson(Map<String, dynamic> j) {
    final id = j['assignmentId'] as String;
    final methods = (j['allowedMethods'] as List).cast<String>();
    final extensions = (j['allowedExtensions'] as List).cast<String>();
    final attachments = (j['attachments'] as List).map((v) {
      final a = v as Map<String, dynamic>;
      return HomeworkFileAttachment(
        a['id'] as String,
        a['name'] as String,
        a['kind'] as String,
      );
    }).toList();
    return HomeworkFileWorkspace(
      assignmentId: id,
      methods: methods,
      extensions: extensions,
      attachments: attachments,
      canSubmit: j['canSubmitFile'] as bool,
      limitBytes: j['fileLimitBytes'] as int,
      limit: j['submissionLimit'] as int?,
      count: j['submittedCount'] as int?,
      blockedReason: j['blockedReason'] as String?,
      returned: j['returned'] as bool,
      text: j['submittedText'] as String?,
      feedback: j['feedback'] as String?,
    );
  }
}

class HomeworkFileReceipt {
  const HomeworkFileReceipt(this.handle, this.name, this.size);
  final String handle, name;
  final int size;
}

class HomeworkFileDownload {
  const HomeworkFileDownload(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
