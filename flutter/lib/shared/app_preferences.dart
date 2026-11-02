import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';

enum AppAppearance {
  system('跟随系统', null),
  light('浅色', Brightness.light),
  dark('深色', Brightness.dark);

  const AppAppearance(this.label, this.brightness);
  final String label;
  final Brightness? brightness;
}

// Names are persisted in display-preferences-v1.json: keep existing names stable.
// Accent choices deliberately do not replace semantic warning/error colors.
enum AppAccent {
  green('银杏绿', AppleDesign.accent),
  blue('蓝色', AppleDesign.resourceBlue),
  purple('紫色', AppleDesign.resourcePurple),
  teal('湖水青', AppleDesign.resourceTeal),
  amber(
    '琥珀金',
    CupertinoDynamicColor.withBrightness(
      color: Color(0xff805500),
      darkColor: Color(0xffffce70),
    ),
  ),
  coral(
    '珊瑚橙',
    CupertinoDynamicColor.withBrightness(
      color: Color(0xffa64020),
      darkColor: Color(0xffffaa87),
    ),
  ),
  rose(
    '玫瑰红',
    CupertinoDynamicColor.withBrightness(
      color: Color(0xffac3058),
      darkColor: Color(0xffffa3c0),
    ),
  );

  const AppAccent(this.label, this.color);
  final String label;
  final Color color;
}

typedef PreferencesWriter = Future<void> Function(Map<String, Object> value);
typedef PreferencesReader = Future<Map<String, Object?>?> Function();

/// Device-wide display choices and the session-flow marker only. Credentials
/// and school data never enter this file. Serial writes prevent a slower old
/// choice overwriting a newer one.
class AppPreferences extends ChangeNotifier {
  /// Defaults to transient state for tests and isolated compositions. The
  /// production entry point injects the platform-backed file store.
  AppPreferences({PreferencesWriter? writer, PreferencesReader? reader})
    : _writer = writer ?? _discardWrite,
      _reader = reader ?? _emptyRead;
  static final shared = AppPreferences();
  final PreferencesWriter _writer;
  final PreferencesReader _reader;
  Future<void> _pending = Future.value();
  int _saveRevision = 0;
  bool _disposed = false;
  bool _readFailed = false;

  /// An unreadable settings file cannot establish the saved sign-out choice.
  bool get readFailed => _readFailed;
  AppAppearance appearance = AppAppearance.system;
  AppAccent accent = AppAccent.green;
  bool compactLists = false;
  bool reduceMotion = false;
  double textSize = 1;

  /// Set by an explicit sign-out and cleared by the next successful sign-in.
  /// While set, a later start shows the login page instead of auto-restoring,
  /// so a failed vault deletion can never resurrect a chosen signed-out state.
  bool explicitSignOut = false;
  String? saveError;
  String? _writeError;

  /// Last failed write, separate from a failed settings read.
  String? get writeError => _writeError;

  /// Chosen network route, kept so the login page and the next start use the
  /// same path instead of silently falling back to automatic.
  String routeMode = 'automatic';

  static Future<void> _discardWrite(Map<String, Object> _) async {}

  static Future<Map<String, Object?>?> _emptyRead() async => null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    if (_disposed) return;
    try {
      final value = await _reader();
      _readFailed = false;
      saveError = _writeError;
      if (value == null) {
        _notify();
        return;
      }
      if (value.containsKey('explicitSignOut') &&
          value['explicitSignOut'] is! bool) {
        throw const FormatException('Invalid sign-out marker');
      }
      if (value.containsKey('routeMode') &&
          !const {
            'automatic',
            'direct',
            'webVpn',
          }.contains(value['routeMode'])) {
        throw const FormatException('Invalid route preference');
      }
      appearance = AppAppearance.values.firstWhere(
        (item) => item.name == value['appearance'],
        orElse: () => AppAppearance.system,
      );
      accent = AppAccent.values.firstWhere(
        (item) => item.name == value['accent'],
        orElse: () => AppAccent.green,
      );
      compactLists = value['compactLists'] == true;
      reduceMotion = value['reduceMotion'] == true;
      final size = value['textSize'];
      textSize = size is num && [1, 1.15, 1.3].contains(size)
          ? size.toDouble()
          : 1;
      explicitSignOut = value['explicitSignOut'] == true;
      routeMode = value['routeMode'] is String
          ? value['routeMode'] as String
          : 'automatic';
      _notify();
    } catch (_) {
      _readFailed = true;
      saveError = '未能读取本机设置，请重试读取';
      _notify();
    }
  }

  Map<String, Object> _snapshot() => <String, Object>{
    'appearance': appearance.name,
    'accent': accent.name,
    'compactLists': compactLists,
    'reduceMotion': reduceMotion,
    'textSize': textSize,
    'explicitSignOut': explicitSignOut,
    'routeMode': routeMode,
  };

  Future<void> _scheduleSave(String failureMessage) {
    if (_disposed) return Future.value();
    final revision = ++_saveRevision;
    final snapshot = _snapshot();
    saveError = null;
    _writeError = null;
    final task = _pending.then((_) async {
      try {
        await _writer(snapshot);
        if (revision == _saveRevision && saveError != null) {
          saveError = null;
          _notify();
        }
      } catch (_) {
        if (revision == _saveRevision) {
          saveError = failureMessage;
          _writeError = failureMessage;
          _notify();
        }
      }
    });
    _pending = task;
    _notify();
    return task;
  }

  /// Retries the current local snapshot without changing any setting.
  Future<void> retrySave() => _scheduleSave('本机设置保存失败，请稍后重试');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> update({
    AppAppearance? appearance,
    AppAccent? accent,
    bool? compactLists,
    bool? reduceMotion,
    double? textSize,
  }) {
    this.appearance = appearance ?? this.appearance;
    this.accent = accent ?? this.accent;
    this.compactLists = compactLists ?? this.compactLists;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.textSize = textSize ?? this.textSize;
    return _scheduleSave('外观已应用，本机保存失败，请稍后重试');
  }

  /// Persists the network route chosen on the login page.
  Future<void> setRouteMode(String value) {
    routeMode = value;
    return _scheduleSave('网络路线已选择，本机保存失败，请稍后重试');
  }

  /// Records or clears the explicit sign-out marker with the same serialized
  /// write path as the display choices.
  Future<void> setExplicitSignOut(bool value) {
    explicitSignOut = value;
    return _scheduleSave(
      value ? '已退出登录，但本机退出标记保存失败，请重试保存' : '登录已完成，但本机设置保存失败，请重试保存',
    );
  }
}

class AppPreferencesScope extends InheritedNotifier<AppPreferences> {
  const AppPreferencesScope({
    super.key,
    required AppPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);

  static AppPreferences of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppPreferencesScope>()
          ?.notifier ??
      AppPreferences.shared;
}
