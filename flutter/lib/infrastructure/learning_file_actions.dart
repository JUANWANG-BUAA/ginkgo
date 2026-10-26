import '../application/homework_files.dart';
import '../application/learning_file_actions.dart';
import '../application/learning_models.dart';
import 'package:ginkgo_mirror/infrastructure/homework_file_io.dart';

/// Learning and homework share only the local byte-save capability, not URLs
/// or authorization context. Null represents picker cancellation/invalidation.
Future<LearningSavedFile?> saveLearningFile(
  LearningDownload file,
  bool Function() isCurrent,
) async {
  final result = await saveAndOpenSchoolFile(
    HomeworkFileDownload(file.name, file.bytes),
    isCurrent: isCurrent,
  );
  if (result.status != FileSaveStatus.saved) return null;
  return LearningSavedFile(
    open: () async {
      final status = await result.open();
      if (status != FileOpenStatus.opened) {
        throw StateError(switch (status) {
          FileOpenStatus.unsupported => '此设备没有可打开该文件的应用',
          FileOpenStatus.stale => '页面或账号已变更，请重新选择文件',
          _ => '无法打开已保存文件，请从系统文件管理器打开',
        });
      }
    },
  );
}
