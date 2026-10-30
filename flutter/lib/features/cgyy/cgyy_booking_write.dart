/// Write-flow primitives of the CGYY booking draft.
library;

export 'package:ginkgo_mirror/application/cgyy_commands.dart'
    show CgyyBookingDraft;

/// The booking command failed before a draft existed. The typed school failure
/// is recorded in the diagnostic log at the throw site.
class CgyyBookingFailure implements Exception {
  const CgyyBookingFailure();
}
