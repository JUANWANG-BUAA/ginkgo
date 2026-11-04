import 'package:ginkgo_mirror/application/mirror_service.dart';

/// Safe extension for gradual Demo isolation refactoring
/// Allows pages to call demoMode methods without immediate refactoring
///
/// Usage pattern (for future migration):
/// Old: if (widget.service.isDemo) { ... }
/// New: if (service.demo.shouldShow('page-name')) { ... }
extension DemoAwareness on AcademicGateway {
  /// Temporary bridge - will be removed after full DemoMode integration
  ///
  /// Should NOT create new DemoMode instances; wait for service injection
  bool get isDemoSafe => isDemo;

  /// Semantic check: Should demo indicator show on this page?
  bool shouldShowDemo(String pageName) {
    if (!isDemo) return false;

    // Page whitelist: only show indicator on demo-aware pages
    const demoPages = {'today', 'homework', 'schedule'};
    return demoPages.contains(pageName);
  }

  /// Semantic check: Demo warning text for context
  String? demoWarning(String context) {
    if (!isDemo) return null;

    return switch (context) {
      'login' => '离线演示 · 已使用演示账号登录',
      'schedule' => '离线演示 · 本周课表为合成数据',
      'homework' => '离线演示 · 作业列表为样例数据',
      'grades' => '离线演示 · 成绩不可用',
      'settings' => '离线演示模式',
      _ => null,
    };
  }

  /// Demo action constraint: Is this action allowed in demo mode?
  bool canPerformAction(String action) {
    if (!isDemo) return true;

    // Actions not allowed in demo
    const demoProhibited = {'submitHomework', 'executeSignIn', 'writeReservation'};
    return !demoProhibited.contains(action);
  }
}

/// Usage example (documentation for future pages):
/*

// BEFORE (current state - safe, works)
class SettingsPage {
  if (widget.service.isDemo) {
    return Text('离线演示不进行网络检查');
  }
}

// AFTER (Phase 3 future - decoupled)
class SettingsPage {
  final DemoMode demoMode;  // Injected

  final warning = demoMode.maybeDemoWarning('settings');
  if (warning != null) {
    return Text(warning);
  }
}

// DURING MIGRATION (safe transition)
class SettingsPage {
  // Use extension temporarily
  if (widget.service.demoWarning('settings') != null) {
    return Text(widget.service.demoWarning('settings')!);
  }

  // After full integration, remove extension and switch to injected DemoMode
}

*/
