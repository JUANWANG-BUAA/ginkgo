import 'package:flutter/foundation.dart';

import 'apple_widgets.dart' show failureMessage;
import 'mirror_service.dart';
import 'application/contracts.dart';

/// One library page owns its read snapshots and post-write readback queue.
/// Disposing the page suppresses notifications, never replays a write.
class LibraryController extends ChangeNotifier {
  LibraryController(this.service);

  final LibraryGateway service;
  LibraryBookingsResponse? bookings;
  LibraryVenuesResponse? venues;
  String? bookingError, venueError, mutationNotice;
  bool loadingBookings = false, loadingVenues = false, submitting = false;
  final Set<String> uncertainActions = {};
  Future<void>? _bookingTask, _venueTask;
  Future<void>? _bookingForcedRun, _venueForcedRun;
  bool _disposed = false;
  int _generation = 0;
  bool get busy => loadingBookings || loadingVenues;

  /// Drops every in-flight read at its next await: call when the account or
  /// service behind [service] changes, so a late response from the previous
  /// context never lands. Follow with load(force: true).
  void invalidate() => _generation++;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool force = false}) =>
      Future.wait([loadVenues(force: force), loadBookings(force: force)]);

  /// Same rule as [RefreshSection]: overlapping plain reads join the slot; a
  /// forced refresh re-runs after the in-flight read instead of being merged
  /// into it and losing the force flag.
  Future<void> _enqueue(
    bool force,
    Future<void>? Function() slot,
    void Function(Future<void>?) setSlot,
    Future<void>? Function() forcedRun,
    void Function(Future<void>?) setForcedRun,
    Future<void> Function(bool) fetch,
  ) {
    final inFlight = slot();
    if (inFlight == null) {
      setForcedRun(null);
      late final Future<void> task;
      task = fetch(force).whenComplete(() {
        if (identical(slot(), task)) setSlot(null);
      });
      setSlot(task);
      return task;
    }
    if (!force) return inFlight;
    final pending = forcedRun();
    if (pending != null) return pending;
    final chained = _chainForced(inFlight, fetch, slot, setSlot, setForcedRun);
    setForcedRun(chained);
    return chained;
  }

  Future<void> _chainForced(
    Future<void> inFlight,
    Future<void> Function(bool) fetch,
    Future<void>? Function() slot,
    void Function(Future<void>?) setSlot,
    void Function(Future<void>?) setForcedRun,
  ) {
    final epoch = _generation;
    late final Future<void> run;
    run = inFlight.then((_) async {
      if (_disposed || epoch != _generation) return;
      late final Future<void> task;
      task = fetch(true).whenComplete(() {
        if (identical(slot(), task)) setSlot(null);
      });
      setSlot(task);
      await task;
    }).whenComplete(() => setForcedRun(null));
    return run;
  }

  Future<void> loadVenues({bool force = false}) => _enqueue(
    force,
    () => _venueTask,
    (task) => _venueTask = task,
    () => _venueForcedRun,
    (run) => _venueForcedRun = run,
    _fetchVenues,
  );

  Future<void> _fetchVenues(bool force) async {
    final epoch = _generation;
    loadingVenues = true;
    venueError = null;
    _publish();
    try {
      final result = await service.libraryVenues(forceRefresh: force);
      if (_generation != epoch) return;
      if (result.failure == null || result.stale) venues = result;
      venueError = result.failure == null
          ? null
          : failureMessage(result.failure);
    } catch (_) {
      if (_generation != epoch) return;
      venueError = failureMessage(null);
    } finally {
      loadingVenues = false;
      _publish();
    }
  }

  Future<void> loadBookings({bool force = false}) => _enqueue(
    force,
    () => _bookingTask,
    (task) => _bookingTask = task,
    () => _bookingForcedRun,
    (run) => _bookingForcedRun = run,
    _fetchBookings,
  );

  Future<void> _fetchBookings(bool force) async {
    final epoch = _generation;
    loadingBookings = true;
    bookingError = null;
    _publish();
    try {
      final result = await service.libraryBookings(forceRefresh: force);
      if (_generation != epoch) return;
      if (result.failure == null || result.stale) bookings = result;
      bookingError = result.failure == null
          ? null
          : failureMessage(result.failure);
    } catch (_) {
      if (_generation != epoch) return;
      bookingError = failureMessage(null);
    } finally {
      loadingBookings = false;
      _publish();
    }
  }

  /// A pre-write read must finish before the forced read can be published.
  /// All selection routes call this same queue, including after being popped.
  Future<void> reservationChanged() async {
    await _bookingTask;
    await loadBookings(force: true);
  }

  /// The page has already obtained explicit confirmation for this action.
  Future<void> perform(LibraryBooking booking, String action) async {
    final key = '${booking.id}/$action';
    if (submitting || uncertainActions.contains(key)) return;
    submitting = true;
    uncertainActions.add(key);
    _publish();
    final epoch = _generation;
    var message = '操作结果待核实，请刷新预约记录，勿重复提交';
    try {
      final result = await service.performLibraryAction(booking.id, action);
      // The write may have reached the school under the previous account:
      // keep the action blocked and leave confirmation to a fresh readback.
      if (_generation != epoch) {
        submitting = false;
        _publish();
        return;
      }
      message = result.message;
      if (result.state == 'notSubmitted' || result.state == 'rejected') {
        uncertainActions.remove(key);
      }
    } catch (_) {
      // The school may have received the request. Leave this action blocked.
    }
    mutationNotice = message;
    _publish();
    await reservationChanged();
    submitting = false;
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
