import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/career.dart';

/// Page-facing capabilities. Tests and alternative adapters need no native runtime.
abstract interface class MirrorService
    implements
        SessionGateway,
        AcademicGateway,
        CheckInGateway,
        LibraryGateway,
        CampusGateway,
        ShuttleGateway,
        LocalTaskGateway {}

abstract interface class CampusCardGateway implements MirrorEnvironment {
  Future<CampusCardBalanceResponse> campusCardBalance();
}

/// Public official destinations only; does not read or transmit account data.
abstract interface class StudentServiceLinksGateway {
  String? studentServiceUrl(String id);
}

/// Public career-calendar reads; no login and no background refresh.
abstract interface class CareerEventsGateway implements MirrorEnvironment {
  Future<CareerEventsRead> careerEvents({
    required String month,
    bool forceRefresh = false,
  });
}

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

abstract interface class LibrarySeatingGateway implements MirrorEnvironment {
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
}

abstract interface class LibraryCatalogGateway implements MirrorEnvironment {
  /// Public OPAC search. Anonymous and read-only; never personal records.
  /// `sort` is one of `relevance` / `pub_year` / `title`.
  Future<ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
    String sort,
    bool descending,
  });

  /// Public holdings for one bib id; the school's nested JSON stays in Rust.
  Future<ReadOnlyResponse> libraryHoldings(String bibId);
}

abstract interface class LibraryGateway
    implements LibrarySeatingGateway, LibraryCatalogGateway {}

abstract interface class ShuttleGateway implements MirrorEnvironment {
  /// Published shuttle timetable (official page). No live seats, no ticketing.
  Future<ReadOnlyResponse> shuttleTimetable();
}

abstract interface class BykcGateway implements MirrorEnvironment {
  Future<ReadOnlyResponse> bykcPart(BykcPart part, {bool forceRefresh = false});
}

abstract interface class GraduateGateway implements MirrorEnvironment {
  Future<ReadOnlyResponse> graduatePart({
    required bool report,
    required bool forceRefresh,
  });
}

abstract interface class NoticeGateway implements MirrorEnvironment {
  Future<ReadOnlyResponse> notices({bool forceRefresh = false});
}

abstract interface class CgyyGateway implements MirrorEnvironment {
  Future<ReadOnlyResponse> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  });
}

abstract interface class CampusGateway
    implements BykcGateway, GraduateGateway, NoticeGateway, CgyyGateway {}

abstract interface class LocalTaskGateway implements MirrorEnvironment {
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
