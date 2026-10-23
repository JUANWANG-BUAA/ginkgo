import 'contracts.dart';

/// Page-facing capabilities. Tests and alternative adapters need no native runtime.
abstract interface class MirrorService
    implements
        SessionGateway,
        AcademicGateway,
        CheckInGateway,
        LibraryGateway,
        CampusGateway {}

abstract interface class MirrorEnvironment {
  bool get isDemo;
}

abstract interface class SessionGateway implements MirrorEnvironment {
  Future<SessionResponse> restoreSession();

  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  });

  Future<SessionResponse> signOut();

  Future<SessionResponse> setRoute(RouteChoice route);

  Future<bool> clearCache();

  Future<bool> verifyBridgeContract();
}

abstract interface class AcademicGateway implements MirrorEnvironment {
  Future<QueryDates> dates(String instant);

  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);

  Future<RuleExamples> rules();

  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  });

  Future<GradeTermsResponse> gradeTerms();

  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false});

  Future<TodayResponse> today({bool forceRefresh = false});

  Future<HomeworkResponse> homework({bool forceRefresh = false});

  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  });
}

abstract interface class CheckInGateway implements MirrorEnvironment {
  Future<CheckInResponse> checkin({bool forceRefresh = false});

  Future<CheckInResponse> checkinOnDate(
    String date, {
    bool forceRefresh = false,
  });

  Future<MutationResponse> submitCheckin(String courseId);

  Future<ReadOnlyResponse> checkinProgress();
}

abstract interface class LibraryGateway implements MirrorEnvironment {
  Future<ReadOnlyResponse> libraryStats({bool forceRefresh = false});

  Future<MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  });

  Future<MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  );

  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false});

  Future<LibraryAreasResponse> libraryAreas(String libraryId);

  Future<LibrarySlotsResponse> librarySlots(String areaId);

  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  });

  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false});

  Future<LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  });

  /// Public OPAC search. Anonymous and read-only; never personal records.
  Future<ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
  });

  /// Public holdings for one bib id; the school's nested JSON stays in Rust.
  Future<ReadOnlyResponse> libraryHoldings(String bibId);
}

abstract interface class CampusGateway {
  Future<ReadOnlyResponse> bykcPart(BykcPart part, {bool forceRefresh = false});

  Future<ReadOnlyResponse> graduatePart({
    required bool report,
    required bool forceRefresh,
  });

  Future<ReadOnlyResponse> notices({bool forceRefresh = false});

  Future<ReadOnlyResponse> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  });

  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  });
}

/// Separate capability: read-only adapters never gain writes implicitly.
abstract interface class CgyyBookingGateway {
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command);
}

enum BykcPart { catalog, chosen, statistics }
