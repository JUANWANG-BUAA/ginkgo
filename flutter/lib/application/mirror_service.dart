import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/career.dart';
import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/application/checkin_progress.dart';
import 'package:ginkgo_mirror/application/library_holdings.dart';
import 'package:ginkgo_mirror/application/library_stats.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';

export 'package:ginkgo_mirror/application/local_tasks.dart'
    show LocalTaskGateway;
import 'package:ginkgo_mirror/application/environment.dart';
import 'package:ginkgo_mirror/application/notices.dart';
import 'package:ginkgo_mirror/application/shuttle.dart';
import 'package:ginkgo_mirror/application/library_books.dart';
import 'package:ginkgo_mirror/application/graduate.dart';
import 'package:ginkgo_mirror/application/bykc.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';

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

  Future<CheckinProgressRead> checkinProgress();
}

abstract interface class LibrarySeatingGateway implements MirrorEnvironment {
  Future<LibraryStatsRead> libraryStats({bool forceRefresh = false});

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
  Future<BookPageRead> libraryBooks({
    required String query,
    required int page,
    String sort,
    bool descending,
  });

  /// Public holdings for one bib id; the school's nested JSON stays in Rust.
  Future<BookHoldingsRead> libraryHoldings(String bibId);
}

abstract interface class LibraryGateway
    implements LibrarySeatingGateway, LibraryCatalogGateway {}

abstract interface class BykcGateway implements MirrorEnvironment {
  Future<BykcPartRead> bykcPart(BykcPart part, {bool forceRefresh = false});
}

abstract interface class GraduateGateway implements MirrorEnvironment {
  Future<GraduateRead> graduatePart({
    required bool report,
    required bool forceRefresh,
  });
}

abstract interface class NoticeGateway implements MirrorEnvironment {
  Future<NoticesRead> notices({bool forceRefresh = false});
}

abstract interface class CgyyGateway implements MirrorEnvironment {
  Future<CgyyLoadRead> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  });
}

abstract interface class CampusGateway
    implements BykcGateway, GraduateGateway, NoticeGateway, CgyyGateway {}

/// Separate capability: read-only adapters never gain writes implicitly.
abstract interface class CgyyBookingGateway {
  Future<CgyyActionResult> executeCgyy(CgyyCommand command);
}

enum BykcPart { catalog, chosen, statistics }
