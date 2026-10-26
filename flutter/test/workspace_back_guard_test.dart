import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/workspace_back_guard.dart';

/// The Android double-back exit is the only place where a stray extra press
/// closes the app, so its time window is pinned here with fake time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  bool popped() => platformCalls.any((call) => call.method == 'SystemNavigator.pop');

  testWidgets('a single back press only arms the exit hint', (tester) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);
    var wentToWorkspace = 0;

    controller.back(atWorkspace: true, goToWorkspace: () => wentToWorkspace++);

    expect(controller.exitArmed, isTrue);
    expect(wentToWorkspace, 0);
    expect(popped(), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a second press inside the window exits the app', (tester) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);

    controller.back(atWorkspace: true, goToWorkspace: () {});
    controller.back(atWorkspace: true, goToWorkspace: () {});

    expect(popped(), isTrue);
    expect(controller.exitArmed, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a second press after the window only re-arms', (tester) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);

    controller.back(atWorkspace: true, goToWorkspace: () {});
    await tester.pump(const Duration(seconds: 3));
    expect(controller.exitArmed, isFalse);

    controller.back(atWorkspace: true, goToWorkspace: () {});
    expect(controller.exitArmed, isTrue);
    expect(popped(), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('leaving the workspace navigates instead of arming exit', (
    tester,
  ) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);
    var wentToWorkspace = 0;

    controller.back(atWorkspace: false, goToWorkspace: () => wentToWorkspace++);

    expect(wentToWorkspace, 1);
    expect(controller.exitArmed, isFalse);
    expect(popped(), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('disarming drops the window so the next press only re-arms', (
    tester,
  ) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);

    controller.back(atWorkspace: true, goToWorkspace: () {});
    controller.disarm();
    expect(controller.exitArmed, isFalse);

    controller.back(atWorkspace: true, goToWorkspace: () {});
    expect(popped(), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('pausing the app cancels the exit window', (tester) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);

    controller.back(atWorkspace: true, goToWorkspace: () {});
    expect(controller.exitArmed, isTrue);

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(controller.exitArmed, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('entering the workspace from a detail route also disarms', (
    tester,
  ) async {
    final controller = WorkspaceBackController();
    addTearDown(controller.dispose);
    var wentToWorkspace = 0;

    controller.back(atWorkspace: true, goToWorkspace: () {});
    expect(controller.exitArmed, isTrue);

    // A detail route's back press routes to the workspace, not to exit.
    controller.back(atWorkspace: false, goToWorkspace: () => wentToWorkspace++);
    expect(wentToWorkspace, 1);
    expect(controller.exitArmed, isFalse);
    expect(popped(), isFalse);
    await tester.pump(const Duration(seconds: 3));
  });
}
