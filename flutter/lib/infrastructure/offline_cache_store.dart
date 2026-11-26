import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ginkgo_mirror/application/contracts.dart';

/// Lightweight pointer to the last signed-in account for 0ms offline-first
/// startup. Never stores credentials, cookies, or tokens.
class OfflineSessionHint {
  const OfflineSessionHint({
    required this.account,
    this.name,
    this.route,
  });

  final String account;
  final String? name;
  final RouteChoice? route;

  SessionResponse toPlaceholderSession() => SessionResponse(
    state: SessionState.signedIn,
    account: account,
    name: name,
    remembered: true,
    route: route,
  );
}

/// Account-isolated read-only disk cache for core daily snapshots (schedule,
/// today courses, homework). Kept intentionally compact and best-effort:
/// corrupt or unreadable files simply fall back to empty cache.
class OfflineCacheStore {
  OfflineCacheStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static final shared = OfflineCacheStore();

  static const int _maxCachedWeeks = 4;

  final Future<Directory> Function() _supportDirectory;
  Future<void> _serial = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() work) {
    final next = _serial.then((_) => work());
    _serial = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<Directory> _cacheDir() async {
    final root = await _supportDirectory();
    return Directory('${root.path}/offline-cache-v1');
  }

  String _accountDigest(String account) =>
      sha256.convert(utf8.encode(account.trim().toLowerCase())).toString().substring(0, 24);

  Future<File> _hintFile() async => File('${(await _cacheDir()).path}/session-hint-v1.json');

  Future<File> _accountFile(String account) async =>
      File('${(await _cacheDir()).path}/acct-${_accountDigest(account)}.json');

  Future<void> _atomicWrite(File file, Map<String, Object?> data) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(file.path);
  }

  Future<Map<String, Object?>?> _readJson(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      // Corrupt cache is ignored rather than blocking app startup.
    }
    return null;
  }

  Future<OfflineSessionHint?> readSessionHint() async {
    try {
      final map = await _readJson(await _hintFile());
      if (map == null) return null;
      final account = map['account'];
      if (account is! String || account.trim().isEmpty) return null;
      final name = map['name'];
      final routeName = map['route'];
      final route = switch (routeName) {
        'direct' => RouteChoice.direct,
        'webVpn' => RouteChoice.webVpn,
        'automatic' => RouteChoice.automatic,
        _ => null,
      };
      return OfflineSessionHint(
        account: account,
        name: name is String && name.isNotEmpty ? name : null,
        route: route,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSessionHint(OfflineSessionHint hint) => _enqueue(() async {
    if (hint.account.trim().isEmpty) return;
    try {
      await _atomicWrite(await _hintFile(), {
        'v': 1,
        'account': hint.account,
        'name': hint.name,
        'route': hint.route?.name,
      });
    } catch (_) {}
  });

  Future<void> clearSessionHint() => _enqueue(() async {
    try {
      final file = await _hintFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  });

  Future<void> clearAccount(String? account) => _enqueue(() async {
    try {
      if (account != null && account.trim().isNotEmpty) {
        final file = await _accountFile(account);
        if (await file.exists()) await file.delete();
      } else {
        final dir = await _cacheDir();
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Future<void> saveToday(String account, TodayResponse value) => _enqueue(() async {
    if (account.trim().isEmpty || value.failure != null || value.date.isEmpty) {
      return;
    }
    try {
      final file = await _accountFile(account);
      final root = await _readJson(file) ?? <String, Object?>{'v': 1};
      root['today'] = _encodeToday(value);
      await _atomicWrite(file, root);
    } catch (_) {}
  });

  Future<TodayResponse?> readToday(
    String account, {
    FailureCode? attachFailure,
  }) async {
    if (account.trim().isEmpty) return null;
    try {
      final root = await _readJson(await _accountFile(account));
      final raw = root?['today'];
      if (raw is! Map) return null;
      return _decodeToday(raw, attachFailure);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSchedule(
    String account,
    ScheduleResponse value, {
    String? requestedTermId,
    int? requestedWeek,
  }) => _enqueue(() async {
    if (account.trim().isEmpty || value.failure != null || value.termId.isEmpty) {
      return;
    }
    try {
      final file = await _accountFile(account);
      final root = await _readJson(file) ?? <String, Object?>{'v': 1};
      final encoded = _encodeSchedule(value);
      if (requestedTermId == null && requestedWeek == null) {
        root['scheduleDefault'] = encoded;
      }
      final weeksRaw = root['scheduleWeeks'];
      final weeks = weeksRaw is Map
          ? Map<String, Object?>.from(weeksRaw)
          : <String, Object?>{};
      final key = '${value.termId}:${value.weekNumber}';
      weeks.remove(key);
      weeks[key] = encoded;
      while (weeks.length > _maxCachedWeeks) {
        weeks.remove(weeks.keys.first);
      }
      root['scheduleWeeks'] = weeks;
      await _atomicWrite(file, root);
    } catch (_) {}
  });

  Future<ScheduleResponse?> readSchedule(
    String account, {
    String? termId,
    int? week,
    FailureCode? attachFailure,
  }) async {
    if (account.trim().isEmpty) return null;
    try {
      final root = await _readJson(await _accountFile(account));
      if (root == null) return null;
      if (termId == null && week == null) {
        final raw = root['scheduleDefault'];
        if (raw is Map) return _decodeSchedule(raw, attachFailure);
      }
      final weeks = root['scheduleWeeks'];
      if (weeks is Map) {
        if (termId != null && week != null) {
          final hit = weeks['$termId:$week'];
          if (hit is Map) return _decodeSchedule(hit, attachFailure);
        } else if (week != null) {
          for (final entry in weeks.entries) {
            if (entry.key.toString().endsWith(':$week') && entry.value is Map) {
              return _decodeSchedule(entry.value as Map, attachFailure);
            }
          }
        }
        if (termId == null && week == null && weeks.isNotEmpty) {
          final last = weeks.values.last;
          if (last is Map) return _decodeSchedule(last, attachFailure);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHomework(String account, HomeworkResponse value) =>
      _enqueue(() async {
        if (account.trim().isEmpty ||
            value.failure != null ||
            value.termCode.isEmpty) {
          return;
        }
        try {
          final file = await _accountFile(account);
          final root = await _readJson(file) ?? <String, Object?>{'v': 1};
          root['homework'] = _encodeHomework(value);
          await _atomicWrite(file, root);
        } catch (_) {}
      });

  Future<HomeworkResponse?> readHomework(
    String account, {
    FailureCode? attachFailure,
  }) async {
    if (account.trim().isEmpty) return null;
    try {
      final root = await _readJson(await _accountFile(account));
      final raw = root?['homework'];
      if (raw is! Map) return null;
      return _decodeHomework(raw, attachFailure);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _encodeToday(TodayResponse v) => {
    'date': v.date,
    'fetchedAt': v.fetchedAt,
    'courses': [
      for (final c in v.courses)
        {
          'name': c.name,
          'place': c.place,
          'time': c.time,
          'shortName': c.shortName,
        },
    ],
  };

  static TodayResponse _decodeToday(Map<dynamic, dynamic> raw, FailureCode? failure) {
    final list = raw['courses'] is List ? raw['courses'] as List : const [];
    return TodayResponse(
      date: raw['date']?.toString() ?? '',
      fetchedAt: raw['fetchedAt'] as String?,
      courses: [
        for (final item in list)
          if (item is Map)
            TodayCourse(
              name: item['name']?.toString() ?? '',
              place: item['place'] as String?,
              time: item['time'] as String?,
              shortName: item['shortName'] as String?,
            ),
      ],
      failure: failure,
    );
  }

  static Map<String, Object?> _encodeSchedule(ScheduleResponse v) => {
    'termId': v.termId,
    'weekNumber': v.weekNumber,
    'fetchedAt': v.fetchedAt,
    'terms': [
      for (final t in v.terms) {'id': t.id, 'name': t.name, 'selected': t.selected},
    ],
    'weeks': [
      for (final w in v.weeks)
        {
          'number': w.number,
          'startDate': w.startDate,
          'endDate': w.endDate,
          'current': w.current,
        },
    ],
    'courses': [
      for (final c in v.courses)
        {
          'id': c.id,
          'name': c.name,
          'day': c.day,
          'startSection': c.startSection,
          'endSection': c.endSection,
          'startTime': c.startTime,
          'endTime': c.endTime,
          'place': c.place,
          'teacher': c.teacher,
          'color': c.color,
        },
    ],
    'exams': [
      for (final e in v.exams)
        {
          'id': e.id,
          'courseName': e.courseName,
          'courseNo': e.courseNo,
          'examTimeDescription': e.examTimeDescription,
          'examDate': e.examDate,
          'startTime': e.startTime,
          'endTime': e.endTime,
          'examPlace': e.examPlace,
          'examSeatNo': e.examSeatNo,
          'week': e.week,
          'examStatus': e.examStatus,
          'examType': e.examType,
        },
    ],
  };

  static ScheduleResponse _decodeSchedule(
    Map<dynamic, dynamic> raw,
    FailureCode? failure,
  ) {
    final termsRaw = raw['terms'] is List ? raw['terms'] as List : const [];
    final weeksRaw = raw['weeks'] is List ? raw['weeks'] as List : const [];
    final coursesRaw = raw['courses'] is List ? raw['courses'] as List : const [];
    final examsRaw = raw['exams'] is List ? raw['exams'] as List : const [];
    return ScheduleResponse(
      termId: raw['termId']?.toString() ?? '',
      weekNumber: (raw['weekNumber'] as num?)?.toInt() ?? 1,
      fetchedAt: raw['fetchedAt'] as String?,
      terms: [
        for (final t in termsRaw)
          if (t is Map)
            ScheduleTerm(
              id: t['id']?.toString() ?? '',
              name: t['name']?.toString() ?? '',
              selected: t['selected'] == true,
            ),
      ],
      weeks: [
        for (final w in weeksRaw)
          if (w is Map)
            ScheduleWeek(
              number: (w['number'] as num?)?.toInt() ?? 1,
              startDate: w['startDate']?.toString() ?? '',
              endDate: w['endDate']?.toString() ?? '',
              current: w['current'] == true,
            ),
      ],
      courses: [
        for (final c in coursesRaw)
          if (c is Map)
            ScheduleCourse(
              id: c['id']?.toString() ?? '',
              name: c['name']?.toString() ?? '',
              day: (c['day'] as num?)?.toInt() ?? 1,
              startSection: (c['startSection'] as num?)?.toInt() ?? 1,
              endSection: (c['endSection'] as num?)?.toInt() ?? 1,
              startTime: c['startTime'] as String?,
              endTime: c['endTime'] as String?,
              place: c['place'] as String?,
              teacher: c['teacher'] as String?,
              color: c['color'] as String?,
            ),
      ],
      exams: [
        for (final e in examsRaw)
          if (e is Map)
            ScheduleExam(
              id: e['id']?.toString() ?? '',
              courseName: e['courseName']?.toString() ?? '',
              courseNo: e['courseNo'] as String?,
              examTimeDescription: e['examTimeDescription'] as String?,
              examDate: e['examDate'] as String?,
              startTime: e['startTime'] as String?,
              endTime: e['endTime'] as String?,
              examPlace: e['examPlace'] as String?,
              examSeatNo: e['examSeatNo'] as String?,
              week: (e['week'] as num?)?.toInt(),
              examStatus: e['examStatus'] as String?,
              examType: e['examType'] as String?,
            ),
      ],
      failure: failure,
    );
  }

  static Map<String, Object?> _encodeHomework(HomeworkResponse v) => {
    'termName': v.termName,
    'termCode': v.termCode,
    'fetchedAt': v.fetchedAt,
    'rolesComplete': v.rolesComplete,
    'items': [
      for (final i in v.items)
        {
          'courseRole': i.courseRole,
          'teacherName': i.teacherName,
          'id': i.id,
          'courseId': i.courseId,
          'courseName': i.courseName,
          'title': i.title,
          'publishedAt': i.publishedAt,
          'dueAt': i.dueAt,
          'status': i.status.name,
          'statusDetail': i.statusDetail,
          'score': i.score,
        },
    ],
  };

  static HomeworkResponse _decodeHomework(
    Map<dynamic, dynamic> raw,
    FailureCode? failure,
  ) {
    final itemsRaw = raw['items'] is List ? raw['items'] as List : const [];
    return HomeworkResponse(
      termName: raw['termName']?.toString() ?? '',
      termCode: raw['termCode']?.toString() ?? '',
      fetchedAt: raw['fetchedAt'] as String?,
      rolesComplete: raw['rolesComplete'] as bool?,
      items: [
        for (final i in itemsRaw)
          if (i is Map)
            HomeworkItem(
              courseRole: i['courseRole'] as String?,
              teacherName: i['teacherName'] as String?,
              id: i['id']?.toString() ?? '',
              courseId: i['courseId'] as String?,
              courseName: i['courseName']?.toString() ?? '',
              title: i['title']?.toString() ?? '',
              publishedAt: i['publishedAt'] as String?,
              dueAt: i['dueAt'] as String?,
              status: switch (i['status']) {
                'submitted' => HomeworkStatus.submitted,
                'pending' => HomeworkStatus.pending,
                _ => HomeworkStatus.unknown,
              },
              statusDetail: i['statusDetail'] as String?,
              score: i['score'] as String?,
            ),
      ],
      failure: failure,
    );
  }
}
