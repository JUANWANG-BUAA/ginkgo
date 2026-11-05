import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/campus_activities.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';

/// Deliberately never delegates to the native service or any network adapter.
/// `Future<Never>` is valid for every async result type in MirrorService.
class VisualReadState
    implements
        MirrorService,
        LearningCourseGateway,
        CareerEventsGateway,
        CampusActivitiesGateway {
  VisualReadState({required this.pending});
  final bool pending;
  @override
  bool get isDemo => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => pending
      ? Completer<Never>().future
      : Future<Never>.error(StateError('合成服务暂不可用'));
}

List<({String id, Widget Function() build})> failureVisualRoutes() => [
  for (final pending in [false, true]) ..._routes(pending),
];

List<({String id, Widget Function() build})> _routes(bool pending) {
  final context = WorkspaceContext(
    service: VisualReadState(pending: pending),
    platformActions: const PlatformActions(),
    mobile: true,
    accountId: '__visual_failure__',
    accountName: '合成检查',
    openFeature: (_) {},
    openSettings: () {},
    onSignOut: () async {},
  );
  // Static screens and explicit private reads have no automatic read state.
  const readPages = {
    'today',
    'checkin',
    'schedule',
    'grades',
    'homework',
    'learning',
    'bykc',
    'graduate',
    'library',
    'cgyy',
    'classroom',
    'notices',
    'shuttle',
    'career-events',
    'campus-activities',
  };
  return [
    for (final destination in workspaceDestinations)
      if (readPages.contains(destination.id))
        (
          id: '${pending ? 'loading' : 'failure'}-${destination.id}',
          build: () => destination.build(context),
        ),
  ];
}
