import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart' show failureMessage;
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

/// One library page owns its read snapshots and post-write readback queue.
/// Disposing the page suppresses notifications, never replays a write.
class LibraryController extends ChangeNotifier {
  LibraryController(
    this.service, {
    this.stallDeadline = const Duration(minutes: 3),
  });

  /// How long a read may stay in flight before the section stops waiting.
  /// A read that never settles would otherwise leave its loading flag set
  /// forever and keep the slot occupied.
  final Duration stallDeadline;

  final LibrarySeatingGateway service;
  LibraryBookingsResponse? bookings;
  LibraryVenuesResponse? venues;
  String? bookingError, venueError, mutationNotice;
  bool loadingBookings = false, loadingVenues = false, submitting = false;
  final Set<String> uncertainActions = {};
  Future<void>? _bookingTask, _venueTask;
  Future<void>? _bookingForcedRun, _venueForcedRun;
  bool _disposed = false;
  int _generation = 0;
  final Map<String, Timer> _stalls = {};
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
    run = inFlight
        .then((_) async {
          if (_disposed || epoch != _generation) return;
          late final Future<void> task;
          task = fetch(true).whenComplete(() {
            if (identical(slot(), task)) setSlot(null);
          });
          setSlot(task);
          await task;
        })
        .whenComplete(() => setForcedRun(null));
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
    // A read that never settles must not keep the venue section loading.
    _armStall('venues', epoch, () => loadingVenues = false, () {
      _venueTask = null;
      _venueForcedRun = null;
    });
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
      _clearStall('venues');
      if (epoch == _generation) {
        loadingVenues = false;
        _publish();
      }
    }
  }

  /// Stop waiting for one section once [stallDeadline] passes. The abandoned
  /// read is discarded through the generation, exactly like [invalidate].
  void _armStall(
    String key,
    int epoch,
    void Function() stopLoading,
    void Function() resetSlot,
  ) {
    _clearStall(key);
    _stalls[key] = Timer(stallDeadline, () {
      if (_disposed || epoch != _generation) return;
      _generation++;
      stopLoading();
      // The abandoned read can never clear its own slot, so free it here;
      // otherwise every later refresh would queue behind it forever.
      resetSlot();
      if (key == 'venues') {
        venueError = failureMessage(null);
      } else {
        bookingError = failureMessage(null);
      }
      _stalls.remove(key);
      _publish();
    });
  }

  void _clearStall(String key) {
    _stalls.remove(key)?.cancel();
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
    // A read that never settles must not keep the booking section loading.
    _armStall('bookings', epoch, () => loadingBookings = false, () {
      _bookingTask = null;
      _bookingForcedRun = null;
    });
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
      _clearStall('bookings');
      if (epoch == _generation) {
        loadingBookings = false;
        _publish();
      }
    }
  }

  /// A pre-write read must finish before the forced read can be published.
  /// All selection routes call this same queue, including after being popped.
  Future<void> reservationChanged() async {
    // Wait for whichever read currently owns the booking slot. `_bookingTask`
    // alone is not enough: a chained forced read clears it before installing
    // its replacement, and awaiting during that gap would start a second
    // overlapping read.
    await (_bookingForcedRun ?? _bookingTask);
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
      // Only an unconfirmed result keeps the action blocked. `accepted` is a
      // confirmed write: the readback below refreshes the booking, and the page
      // re-derives what is allowed from that fresh snapshot. Leaving it blocked
      // would disable the button for the rest of the page's life with no way
      // for the user to clear it.
      if (result.state != 'uncertain') {
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
    for (final stall in _stalls.values) {
      stall.cancel();
    }
    _stalls.clear();
    super.dispose();
  }
}
