import 'package:ginkgo_mirror/application/contracts.dart';

/// Centralizes demo mode detection and prevents scattered `if (isDemo)` checks.
///
/// Before: 23+ places checking `service.isDemo` or `data.demo`
/// After: Single service injection, pages unaware of demo/live mode
abstract interface class DemoMode {
  bool get isEnabled;

  /// Whether to show demo-specific UI elements
  bool shouldShowDemoIndicator(String page);

  /// Whether to apply demo-specific data transformations
  bool shouldTransformData(String entity);

  /// Demo-safe error messages (sanitized)
  String? maybeDemoWarning(String context);
}

/// Concrete implementation: wraps service.isDemo into structured decisions
class LiveDemoMode implements DemoMode {
  const LiveDemoMode(this.service);

  final AcademicGateway service;

  @override
  bool get isEnabled => service.isDemo;

  @override
  bool shouldShowDemoIndicator(String page) {
    // Only show indicator on specific pages where user should know it's demo
    const demoIndicatorPages = {'today', 'homework', 'schedule'};
    return isEnabled && demoIndicatorPages.contains(page);
  }

  @override
  bool shouldTransformData(String entity) {
    // Some entities always show demo data; others are hidden in demo
    const hiddenInDemo = {'grades', 'gpa', 'transcript'};
    return isEnabled && !hiddenInDemo.contains(entity);
  }

  @override
  String? maybeDemoWarning(String context) {
    if (!isEnabled) return null;

    return switch (context) {
      'schedule' => '离线演示 · 本周课表为合成数据',
      'homework' => '离线演示 · 作业列表为样例数据',
      'grades' => '离线演示 · 成绩不可用',
      _ => null,
    };
  }
}
