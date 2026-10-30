import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/shuttle.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_page.dart';

// Only this read capability is implemented. Unexpected calls fail rather than
// reaching native bindings, demo initialization, or a school network.
class _ShuttleService extends Fake implements MirrorService {
  final requests = <Completer<ShuttleTimetableRead>>[];

  @override
  bool get isDemo => false;

  @override
  Future<ShuttleTimetableRead> shuttleTimetable() {
    final request = Completer<ShuttleTimetableRead>();
    requests.add(request);
    return request.future;
  }
}

const _source = 'https://shuttle.example.test/published-timetable';
const _loading = '正在读取校车时刻表…';
const _error = '时刻表读取未完成，请稍后重试';
const _unavailable = '学校服务暂时不可用，请稍后重试';
const _offline = '无法连接网络，请检查手机网络或校园网后重试';
const _empty = '暂时没有可显示的时刻表';
const _refresh = Key('shuttle-refresh');
const _official = Key('shuttle-official');
const _plan = Key('shuttle-plan');

// Beijing wall time, injected so plan selection never depends on the host
// clock or the machine timezone. Late Monday: the sample runs have departed.
final _defaultNow = DateTime.utc(2026, 10, 26, 23, 30);

List<Map<String, dynamic>> _weekdayRuns() => [
  {'index': '1', 'time': '07:20', 'capacity': '45'},
  {'index': '2', 'time': '09:00', 'capacity': '49'},
  {'index': '3', 'time': '12:35', 'capacity': '50'},
  {'index': '4', 'time': '18:10', 'capacity': '52'},
];

/// The page tests are about presentation, so fixtures stay JSON-shaped and are
/// lifted here. Decoding itself is covered by the bridge mapping test and
/// `public_read_contract_test`.
ShuttleTimetableRead _read(Map<String, dynamic> json) => ShuttleTimetableRead(
  data: ShuttleTimetable(
    source: json['source'] as String? ?? '',
    liveSource: json['liveSource'] as String? ?? '',
    tables: [
      for (final table in _maps(json['tables']))
        ShuttleTable(
          left: table['left'] as String? ?? '',
          right: table['right'] as String? ?? '',
          sections: [
            for (final section in _maps(table['sections']))
              ShuttleSection(
                label: section['label'] as String? ?? '',
                left: _runs(section['left']),
                right: _runs(section['right']),
              ),
          ],
        ),
    ],
  ),
);

List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>();

List<ShuttleRun> _runs(Object? value) => [
  for (final run in _maps(value))
    ShuttleRun(
      index: run['index'] as String? ?? '',
      time: run['time'] as String? ?? '',
      capacity: run['capacity'] as String? ?? '',
    ),
];

ShuttleTimetableRead _timetable({
  String source = _source,
  String liveSource = '',
  String time = '07:20',
  bool empty = false,
  List<Map<String, dynamic>>? sections,
}) => _read({
  'source': source,
  'liveSource': liveSource,
  'tables': empty
      ? []
      : [
          {
            'left': '合成甲校区 → 合成乙校区',
            'right': '合成乙校区 → 合成甲校区',
            'sections':
                sections ??
                [
                  {
                    'label': '合成工作日',
                    'left': [
                      {'index': '1', 'time': time, 'capacity': '45'},
                      {'index': '2', 'time': '12:35', 'capacity': ''},
                    ],
                    'right': [
                      {'index': '1', 'time': '18:10', 'capacity': '50'},
                    ],
                  },
                ],
          },
        ],
});

Widget _app(Widget home, {double scale = 1, Brightness? brightness}) =>
    CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: home,
    );

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _show(
  WidgetTester tester,
  _ShuttleService service, {
  DateTime? now,
}) => tester.pumpWidget(
  _app(ShuttlePage(service: service, now: now ?? _defaultNow)),
);

/// The refresh control is the glass header button; its press state lives on the
/// CupertinoButton it renders, so the key must be resolved to that descendant.
VoidCallback? _refreshAction(WidgetTester tester) => tester
    .widget<CupertinoButton>(
      find.descendant(
        of: find.byKey(_refresh),
        matching: find.byType(CupertinoButton),
      ),
    )
    .onPressed;

List<MethodCall> _mockLauncher(
  WidgetTester tester, {
  bool result = true,
  bool throws = false,
}) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    calls.add(call);
    if (throws) throw PlatformException(code: 'synthetic-launch-failure');
    return result;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return calls;
}

void main() {
  testWidgets(
    'first load is pending, refresh is coalesced, and both directions render',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service);
      expect(service.requests, hasLength(1));
      expect(find.text(_loading), findsOneWidget);
      expect(find.text(_empty), findsNothing);
      expect(find.text(_error), findsNothing);
      expect(_refreshAction(tester), isNull);
      await tester.tap(find.byKey(_refresh));
      await tester.pump();
      expect(service.requests, hasLength(1));

      service.requests.single.complete(_timetable());
      await tester.pumpAndSettle();
      expect(find.text(_loading), findsNothing);
      expect(find.text('07:20 · 45座'), findsOneWidget);
      expect(find.text('12:35'), findsOneWidget);
      expect(find.text('18:10 · 50座'), findsOneWidget);
      expect(find.text('12:35 · 座'), findsNothing);
      expect(find.text('合成工作日'), findsOneWidget);
      expect(
        find.byKey(const Key('shuttle-directions-columns')),
        findsOneWidget,
      );
      expect(_refreshAction(tester), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful empty is distinct from failure and can be refreshed',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service);
      service.requests.single.complete(_timetable(empty: true));
      await tester.pumpAndSettle();
      expect(find.text(_empty), findsOneWidget);
      expect(find.text(_loading), findsNothing);
      expect(find.text(_error), findsNothing);
      await tester.tap(find.byKey(_refresh));
      await tester.pump();
      expect(service.requests, hasLength(2));
      service.requests.last.complete(_timetable());
      await tester.pumpAndSettle();
      expect(find.text(_empty), findsNothing);
      expect(find.text('07:20 · 45座'), findsOneWidget);
    },
  );

  testWidgets(
    'typed failure and thrown error allow an explicit successful retry',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service);
      service.requests.single.complete(
        const ShuttleTimetableRead(failure: FailureCode.serviceUnavailable),
      );
      await tester.pumpAndSettle();
      // A typed code must reach the reader instead of the generic shuttle copy.
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.text(_error), findsNothing);
      expect(find.text(_empty), findsNothing);
      await tester.tap(find.byKey(_refresh));
      await tester.pump();
      expect(find.text(_unavailable), findsNothing);
      expect(find.text(_loading), findsOneWidget);
      service.requests.last.completeError(StateError('synthetic read failure'));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsOneWidget);
      await tester.tap(find.byKey(_refresh));
      service.requests.last.complete(_timetable());
      await tester.pumpAndSettle();
      expect(service.requests, hasLength(3));
      expect(find.text(_error), findsNothing);
      expect(find.text('07:20 · 45座'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an offline read blames the connection, not the school', (
    tester,
  ) async {
    final service = _ShuttleService();
    await _show(tester, service);
    service.requests.single.complete(
      const ShuttleTimetableRead(failure: FailureCode.networkUnreachable),
    );
    await tester.pumpAndSettle();
    expect(find.text(_offline), findsOneWidget);
    expect(find.text(_unavailable), findsNothing);
    expect(find.text(_error), findsNothing);
  });

  testWidgets(
    'refresh keeps the last timetable through pending and failed reads; empty clears it',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service);
      service.requests.single.complete(_timetable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_refresh));
      await tester.pump();
      expect(find.text('07:20 · 45座'), findsOneWidget);
      expect(find.text(_loading), findsNothing);
      service.requests.last.completeError(
        StateError('synthetic refresh failure'),
      );
      await tester.pumpAndSettle();
      expect(find.text('07:20 · 45座'), findsOneWidget);
      expect(find.text(_error), findsOneWidget);
      await tester.tap(find.byKey(_refresh));
      service.requests.last.complete(_timetable(time: '08:40'));
      await tester.pumpAndSettle();
      expect(find.text('07:20 · 45座'), findsNothing);
      expect(find.text('08:40 · 45座'), findsOneWidget);
      expect(find.text(_error), findsNothing);
      await tester.tap(find.byKey(_refresh));
      service.requests.last.complete(_timetable(empty: true));
      await tester.pumpAndSettle();
      expect(find.text('08:40 · 45座'), findsNothing);
      expect(find.text(_empty), findsOneWidget);
    },
  );

  testWidgets(
    'first-screen plan picks the next trip plus at most two follow-ups before the timetable',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service, now: DateTime.utc(2026, 10, 26, 8, 30));
      service.requests.single.complete(
        _timetable(
          sections: [
            {
              'label': '星期一至星期五',
              'left': _weekdayRuns(),
              'right': [
                {'index': '1', 'time': '10:15', 'capacity': '48'},
              ],
            },
          ],
        ),
      );
      await tester.pumpAndSettle();

      final plan = find.byKey(_plan);
      expect(plan, findsOneWidget);
      expect(find.text('下一班计划'), findsOneWidget);
      expect(find.text('静态时刻表'), findsOneWidget);
      expect(
        find.descendant(of: plan, matching: find.text('09:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan, matching: find.text('计划 49 座')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shuttle-plan-next')),
          matching: find.text('合成甲校区 → 合成乙校区'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shuttle-plan-following-0')), findsOneWidget);
      expect(find.byKey(const Key('shuttle-plan-following-1')), findsOneWidget);
      expect(find.byKey(const Key('shuttle-plan-following-2')), findsNothing);
      expect(
        find.descendant(of: plan, matching: find.text('10:15')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan, matching: find.text('12:35')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan, matching: find.text('合成乙校区 → 合成甲校区')),
        findsOneWidget,
      );
      // The fourth run belongs to the full timetable, not to the summary.
      expect(
        find.descendant(of: plan, matching: find.text('18:10')),
        findsNothing,
      );
      // Planned capacity is not a remaining-seat claim.
      expect(
        find.descendant(of: plan, matching: find.textContaining('余票')),
        findsNothing,
      );
      expect(
        tester.getTopLeft(plan).dy,
        lessThan(tester.getTopLeft(find.text('星期一至星期五')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a departure at the current minute is still next; missing capacity stays unpublished',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service, now: DateTime.utc(2026, 10, 26, 9, 0));
      service.requests.single.complete(
        _timetable(
          sections: [
            {
              'label': '星期一至星期五',
              'left': [
                {'index': '1', 'time': '09:00', 'capacity': ''},
                {'index': '2', 'time': '09:01', 'capacity': '45'},
              ],
              'right': const [],
            },
          ],
        ),
      );
      await tester.pumpAndSettle();

      final plan = find.byKey(_plan);
      expect(
        find.descendant(of: plan, matching: find.text('09:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan, matching: find.text('计划容量未公布')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan, matching: find.textContaining('0 座')),
        findsNothing,
      );
      expect(
        find.descendant(of: plan, matching: find.textContaining('余票')),
        findsNothing,
      );
      expect(find.byKey(const Key('shuttle-plan-following-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plan honours weekday and weekend validity labels using Beijing time',
    (tester) async {
      final service = _ShuttleService();
      await _show(tester, service, now: DateTime.utc(2026, 10, 31, 8, 0));
      service.requests.single.complete(
        _timetable(
          sections: [
            {
              'label': '星期一至星期五',
              'left': [
                {'index': '1', 'time': '09:00', 'capacity': '45'},
              ],
              'right': [
                {'index': '1', 'time': '09:10', 'capacity': '45'},
              ],
            },
            {
              'label': '双休日、节假日',
              'left': [
                {'index': '1', 'time': '09:30', 'capacity': '40'},
              ],
              'right': [
                {'index': '1', 'time': '09:40', 'capacity': '40'},
              ],
            },
          ],
        ),
      );
      await tester.pumpAndSettle();

      final plan = find.byKey(_plan);
      expect(
        find.descendant(of: plan, matching: find.text('09:30')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('shuttle-plan-next')),
          matching: find.text('计划 40 座'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: plan, matching: find.text('09:00')),
        findsNothing,
      );
      expect(
        find.descendant(of: plan, matching: find.text('09:10')),
        findsNothing,
      );
      // The full timetable still lists both validity groups.
      expect(find.text('09:00 · 45座'), findsOneWidget);
      expect(find.text('09:30 · 40座'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('plan is explicit when no published run applies today', (
    tester,
  ) async {
    final service = _ShuttleService();
    await _show(tester, service, now: DateTime.utc(2026, 10, 26, 8, 0));
    service.requests.single.complete(
      _timetable(
        sections: [
          {
            'label': '双休日、节假日',
            'left': [
              {'index': '1', 'time': '09:00', 'capacity': '45'},
            ],
            'right': const [],
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_plan), findsOneWidget);
    expect(find.text('今日无计划班次'), findsOneWidget);
    expect(find.text('今日计划班次已结束'), findsNothing);
    expect(find.byKey(const Key('shuttle-plan-next')), findsNothing);
    expect(find.byKey(const Key('shuttle-plan-following-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan reports the end of today after the last published run', (
    tester,
  ) async {
    final service = _ShuttleService();
    await _show(tester, service, now: DateTime.utc(2026, 10, 26, 23, 30));
    service.requests.single.complete(
      _timetable(
        sections: [
          {'label': '星期一至星期五', 'left': _weekdayRuns(), 'right': const []},
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日计划班次已结束'), findsOneWidget);
    expect(find.text('今日无计划班次'), findsNothing);
    expect(find.byKey(const Key('shuttle-plan-next')), findsNothing);
    expect(
      find.descendant(of: find.byKey(_plan), matching: find.text('18:10')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no plan is claimed without a successful timetable read', (
    tester,
  ) async {
    final emptyService = _ShuttleService();
    await _show(tester, emptyService);
    emptyService.requests.single.complete(_timetable(empty: true));
    await tester.pumpAndSettle();
    expect(find.byKey(_plan), findsNothing);
    expect(find.text('今日无计划班次'), findsNothing);
    expect(find.text('今日计划班次已结束'), findsNothing);

    final failedService = _ShuttleService();
    await _show(tester, failedService);
    failedService.requests.single.complete(
      const ShuttleTimetableRead(failure: FailureCode.serviceUnavailable),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_plan), findsNothing);
    expect(find.text('今日无计划班次'), findsNothing);
    expect(find.text('今日计划班次已结束'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending refresh keeps the last plan visible', (tester) async {
    final service = _ShuttleService();
    await _show(tester, service, now: DateTime.utc(2026, 10, 26, 8, 30));
    service.requests.single.complete(
      _timetable(
        sections: [
          {'label': '星期一至星期五', 'left': _weekdayRuns(), 'right': const []},
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(_plan), matching: find.text('09:00')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_refresh));
    await tester.pump();
    expect(
      find.descendant(of: find.byKey(_plan), matching: find.text('09:00')),
      findsOneWidget,
    );
    service.requests.last.completeError(
      StateError('synthetic refresh failure'),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(_plan), matching: find.text('09:00')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replacing a pending gateway ignores its late response and unlocks new refreshes',
    (tester) async {
      final old = _ShuttleService();
      final current = _ShuttleService();
      await _show(tester, old);
      await _show(tester, current);
      expect(current.requests, hasLength(1));
      current.requests.single.complete(_timetable(time: '09:30'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_refresh));
      await tester.pump();
      old.requests.single.complete(_timetable(time: '06:00'));
      await tester.pump();
      expect(find.text('09:30 · 45座'), findsOneWidget);
      expect(find.text('06:00 · 45座'), findsNothing);
      expect(_refreshAction(tester), isNull);
      current.requests.last.complete(_timetable(time: '10:00'));
      await tester.pumpAndSettle();
      expect(find.text('10:00 · 45座'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gateway replacement clears old data/source and ignores late errors',
    (tester) async {
      final calls = _mockLauncher(tester);
      final old = _ShuttleService();
      await _show(tester, old);
      old.requests.single.complete(_timetable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_refresh));
      final current = _ShuttleService();
      await _show(tester, current);
      expect(find.text('07:20 · 45座'), findsNothing);
      expect(find.text(_loading), findsOneWidget);
      await tester.tap(find.byKey(_official));
      // The current read is deliberately pending, so its spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, isEmpty);
      expect(find.text('官方页面暂不可用'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      old.requests.last.completeError(
        StateError('synthetic old provider error'),
      );
      await tester.pump();
      expect(find.text(_error), findsNothing);
      current.requests.single.complete(_timetable(empty: true));
      await tester.pumpAndSettle();
      expect(find.text(_empty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposing during a read ignores completion', (tester) async {
    final service = _ShuttleService();
    await _show(tester, service);
    await tester.pumpWidget(_app(const SizedBox()));
    service.requests.single.complete(_timetable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live action delegates the DTO authentication entry to the external browser',
    (tester) async {
      const login = 'https://shuttle.example.test/official-authentication';
      final calls = _mockLauncher(tester);
      final service = _ShuttleService();
      await _show(tester, service);
      service.requests.single.complete(_timetable(liveSource: login));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shuttle-live-official')));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.arguments['url'], login);
      expect(calls.single.arguments['useWebView'], isFalse);
      expect(calls.single.arguments['useSafariVC'], isFalse);
      expect(service.requests, hasLength(1));
      expect(find.text('前往官方认证并查看余票'), findsOneWidget);
      expect(find.textContaining('应用内尚未接通实时余票会话'), findsOneWidget);
    },
  );

  test('demo also exposes the official authentication entry', () async {
    final response = await const DemoMirrorService().shuttleTimetable();
    expect(
      response.data?.liveSource,
      'https://zhihuixiaoche.buaa.edu.cn/wechat/CASLogin',
    );
  });

  testWidgets(
    'official action launches only the DTO source externally, never a real browser',
    (tester) async {
      final calls = _mockLauncher(tester);
      final service = _ShuttleService();
      await _show(tester, service);
      service.requests.single.complete(_timetable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_official));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      expect(calls.single.arguments['url'], _source);
      expect(calls.single.arguments['useWebView'], isFalse);
      expect(calls.single.arguments['useSafariVC'], isFalse);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    },
  );

  for (final source in [
    '',
    'http://shuttle.example.test/',
    'https:///missing-host',
    'https://user:secret@shuttle.example.test/',
    'https://[invalid',
  ]) {
    testWidgets(
      'unavailable or unsafe official source is not launched: $source',
      (tester) async {
        final calls = _mockLauncher(tester);
        final service = _ShuttleService();
        await _show(tester, service);
        service.requests.single.complete(
          _timetable(source: source, empty: true),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_official));
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        expect(find.text('官方页面暂不可用'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final throws in [false, true]) {
    testWidgets(
      'browser refusal/exception leaves a selectable source (throws=$throws)',
      (tester) async {
        final calls = _mockLauncher(tester, result: false, throws: throws);
        final service = _ShuttleService();
        await _show(tester, service);
        service.requests.single.complete(_timetable());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_official));
        await tester.pumpAndSettle();
        expect(calls, hasLength(1));
        expect(find.text('未能打开浏览器'), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          contains(_source),
        );
        await tester.tap(find.text('知道了'));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(find.text('07:20 · 45座'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Android fallback link supports a real copy menu', (
    tester,
  ) async {
    _mockLauncher(tester, result: false);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final service = _ShuttleService();
    await _show(tester, service);
    service.requests.single.complete(_timetable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_official));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(copied, isNotEmpty);
    expect('请手动访问：\n$_source', contains(copied!));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '320dp, 2x text timetable remains scrollable in ${brightness.name}',
      (tester) async {
        _viewport(tester, const Size(320, 900));
        final service = _ShuttleService();
        await tester.pumpWidget(
          _app(
            ShuttlePage(service: service, now: _defaultNow),
            scale: 2,
            brightness: brightness,
          ),
        );
        service.requests.single.complete(_timetable());
        await tester.pumpAndSettle();
        expect(find.byKey(_plan), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('18:10 · 50座'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('18:10 · 50座'), findsOneWidget);
        expect(find.text('12:35'), findsOneWidget);
        expect(
          find.byKey(const Key('shuttle-directions-stacked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('shuttle-directions-columns')),
          findsNothing,
        );
        expect(
          tester.getTopLeft(find.text('合成乙校区 → 合成甲校区')).dy,
          greaterThan(tester.getTopLeft(find.text('合成甲校区 → 合成乙校区')).dy),
        );
        // Widget tests use Ahem, not the device CJK font. Assert reclaimed
        // width here; actual run wrapping is checked in Android screenshots.
        expect(
          tester.getSize(find.text('18:10 · 50座')).width,
          greaterThan(200),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '320dp, 2x text plan summary stays readable in ${brightness.name}',
      (tester) async {
        _viewport(tester, const Size(320, 900));
        final service = _ShuttleService();
        await tester.pumpWidget(
          _app(
            ShuttlePage(
              service: service,
              now: DateTime.utc(2026, 10, 26, 8, 30),
            ),
            scale: 2,
            brightness: brightness,
          ),
        );
        service.requests.single.complete(
          _timetable(
            sections: [
              {
                'label': '星期一至星期五',
                'left': _weekdayRuns(),
                'right': [
                  {'index': '1', 'time': '10:15', 'capacity': '48'},
                ],
              },
            ],
          ),
        );
        await tester.pumpAndSettle();
        final plan = find.byKey(_plan);
        expect(
          find.descendant(of: plan, matching: find.text('下一班计划')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: plan, matching: find.text('静态时刻表')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: plan, matching: find.text('计划 49 座')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: plan, matching: find.text('09:00')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('shuttle-plan-following-1')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'service directory forwards its injected gateway to the shuttle route',
    (tester) async {
      final service = _ShuttleService();
      await tester.pumpWidget(
        _app(
          CupertinoPageScaffold(
            child: ListView(
              children: [
                ServiceDirectory(
                  service: service,
                  destinations: workspaceDestinations,
                  onSignOut: () async {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.requests, isEmpty);
      await tester.tap(find.text('校车时刻表'));
      await tester.pump();
      expect(service.requests, hasLength(1));
      service.requests.single.complete(_timetable());
      await tester.pumpAndSettle();
      expect(find.text('07:20 · 45座'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
