import 'dart:async';

/// A busy flag that recovers on its own.
///
/// Every controller in this app guards its work with a boolean ("is a read in
/// flight?"). A read that never settles would leave that flag set forever: the
/// guard then rejects every later attempt, and the feature stays dead until
/// the process restarts. The Dart-side native budget already caps the usual
/// cause, but a platform channel or a local write can still stall, so the flag
/// itself carries a deadline.
///
/// This is deliberately *not* a timeout on the work: the in-flight future keeps
/// running and its result is still applied. Only the gate reopens, which lets a
/// later attempt try again.
class BusyGate {
  BusyGate({required this.deadline});

  /// How long the gate stays closed before it reopens by itself.
  final Duration deadline;

  bool _busy = false;
  Timer? _watchdog;

  bool get busy => _busy;

  /// Close the gate. Returns false when it was already closed.
  bool enter() {
    if (_busy) return false;
    _busy = true;
    _watchdog?.cancel();
    _watchdog = Timer(deadline, () {
      // The work may still finish; only the gate reopens.
      _busy = false;
      _watchdog = null;
      onExpired?.call();
    });
    return true;
  }

  /// Reopen the gate. Safe to call when already open.
  void leave() {
    _watchdog?.cancel();
    _watchdog = null;
    _busy = false;
  }

  /// Called when the deadline passed while the work was still in flight.
  ///
  /// Controllers use it to tell the user that the previous attempt did not
  /// finish, so a recovered page never looks like it silently dropped work.
  void Function()? onExpired;

  void dispose() {
    _watchdog?.cancel();
    _watchdog = null;
    _busy = false;
    onExpired = null;
  }
}
