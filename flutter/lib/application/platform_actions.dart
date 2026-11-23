import 'package:ginkgo_mirror/application/checkin_qr.dart';
import 'package:ginkgo_mirror/application/file_actions.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/maintenance.dart';

/// The platform actions the presentation layer needs.
///
/// The composition root binds the real implementations once, above the
/// pages. A page receives what it needs through the page context instead of
/// naming an adapter, so the page and the workspace always share one
/// capability.
class PlatformActions {
  const PlatformActions({
    this.learningFileSaver,
    this.homeworkFilePicker,
    this.homeworkFileSave,
    this.checkinQrSaver,
    this.maintenance,
  });

  /// Saves a learning resource locally and offers to open it.
  final LearningFileSaver? learningFileSaver;

  /// Asks the user for a file.
  final HomeworkFilePicker? homeworkFilePicker;

  /// Saves the chosen file and reports what happened.
  final HomeworkFileSave? homeworkFileSave;

  /// Writes a single overwritten check-in QR image to the album or chosen file.
  final CheckinQrSaver? checkinQrSaver;

  /// The update and self-check capability.
  final MaintenanceService? maintenance;
}
