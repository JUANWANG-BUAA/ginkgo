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
  bool _disposed = false;
  bool get busy => loadingBookings || loadingVenues;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool force = false}) =>
      Future.wait([loadVenues(force: force), loadBookings(force: force)]);

  Future<void> loadVenues({bool force = false}) =>
      _venueTask ??= _fetchVenues(force).whenComplete(() => _venueTask = null);

  Future<void> _fetchVenues(bool force) async {
    loadingVenues = true;
    venueError = null;
    _publish();
    try {
      final result = await service.libraryVenues(forceRefresh: force);
      if (result.failure == null || result.stale) venues = result;
      venueError = result.failure == null
          ? null
          : failureMessage(result.failure);
    } catch (_) {
      venueError = failureMessage(null);
    } finally {
      loadingVenues = false;
      _publish();
    }
  }

  Future<void> loadBookings({bool force = false}) =>
      _bookingTask ??= _fetchBookings(force)
          .whenComplete(() => _bookingTask = null);

  Future<void> _fetchBookings(bool force) async {
    loadingBookings = true;
    bookingError = null;
    _publish();
    try {
      final result = await service.libraryBookings(forceRefresh: force);
      if (result.failure == null || result.stale) bookings = result;
      bookingError = result.failure == null
          ? null
          : failureMessage(result.failure);
    } catch (_) {
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
    var message = '操作结果待核实，请刷新预约记录，勿重复提交';
    try {
      final result = await service.performLibraryAction(booking.id, action);
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
