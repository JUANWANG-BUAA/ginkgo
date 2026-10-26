import 'learning_models.dart';

/// User-initiated local save; implementors must recheck current after selection
/// and before committing bytes. Null means cancelled or invalidated.
typedef LearningFileSaver = Future<LearningSavedFile?> Function(
  LearningDownload file,
  bool Function() isCurrent,
);

class LearningSavedFile {
  const LearningSavedFile({required this.open});
  final Future<void> Function() open;
}
