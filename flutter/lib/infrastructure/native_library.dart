import '../application/contracts.dart';
import '../application/library_books.dart';
import '../application/library_holdings.dart';
import '../application/library_stats.dart';
import '../application/service_health.dart';
import '../src/rust/api/live.dart' as live;
import 'library_books_decode.dart';
import 'library_holdings_decode.dart';
import 'library_stats_decode.dart';
import 'native_command.dart';

/// Library catalog, holdings, real-time occupancy, and seat-booking reads.
mixin NativeLibrary {
  Future<LibraryStatsRead> libraryStats({bool forceRefresh = false}) =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.libraryStats,
        () async => decodeLibraryStats(
          await boundedNativeRead(
            () => live.loadLibraryStats(forceRefresh: forceRefresh),
          ),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.failure != null && r.data != null,
      );

  Future<BookPageRead> libraryBooks({
    required String query,
    required int page,
    String sort = 'relevance',
    bool descending = true,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.libraryBooks,
    () async => decodeBookPage(
      await boundedNativeRead(
        () => live.loadLibraryBooks(
          query: query,
          page: page,
          sort: sort,
          descending: descending,
        ),
      ),
    ),
    failureOf: (r) => r.failure,
    staleOf: (r) => r.failure != null && r.data != null,
  );

  Future<BookHoldingsRead> libraryHoldings(String bibId) async =>
      decodeBookHoldings(
        await boundedNativeRead(() => live.loadLibraryHoldings(bibId: bibId)),
      );

  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) =>
      ServiceHealthTracker.shared.observe(
        ServiceEndpointId.libraryVenues,
        () => boundedNativeRead(
          () => live.loadLibraryVenues(forceRefresh: forceRefresh),
        ),
        failureOf: (r) => r.failure,
        staleOf: (r) => r.stale,
        cachedOf: (r) => r.fromCache,
      );

  Future<LibraryAreasResponse> libraryAreas(String libraryId) =>
      boundedNativeRead(() => live.loadLibraryAreas(libraryId: libraryId));

  Future<LibrarySlotsResponse> librarySlots(String areaId) =>
      boundedNativeRead(() => live.loadLibrarySlots(areaId: areaId));

  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) => boundedNativeRead(
    () => live.loadLibrarySeats(
      areaId: areaId,
      slotId: slot.id,
      day: slot.day,
      start: slot.start,
      end: slot.end,
    ),
  );

  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) => ServiceHealthTracker.shared.observe(
    ServiceEndpointId.libraryVenues,
    () => boundedNativeRead(
      () => live.loadLibraryBookings(forceRefresh: forceRefresh),
    ),
    failureOf: (r) => r.failure,
    staleOf: (r) => r.stale,
    cachedOf: (r) => r.fromCache,
  );

  Future<live.LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) => boundedNativeRead(
    () => live.loadLibraryHistory(page: page, forceRefresh: forceRefresh),
  );
}
