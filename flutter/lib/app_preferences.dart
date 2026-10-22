import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import 'apple_design.dart';

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
typedef PreferencesReader = Future<Map<String, dynamic>?> Function();

/// Device-wide display choices only. Credentials and school data never enter
/// this file. Serial writes prevent a slower old choice overwriting a new one.
class AppPreferences extends ChangeNotifier {
  AppPreferences({PreferencesWriter? writer, PreferencesReader? reader})
    : _writer = writer ?? _write,
      _reader = reader ?? _read;
  static final shared = AppPreferences();
  final PreferencesWriter _writer;
  final PreferencesReader _reader;
  Future<void> _pending = Future.value();
  AppAppearance appearance = AppAppearance.system;
  AppAccent accent = AppAccent.green;
  bool compactLists = false;
  bool reduceMotion = false;
  double textSize = 1;
  String? saveError;

  static Future<File> _file() async {
    final root = await getApplicationSupportDirectory();
    return File('${root.path}/display-preferences-v1.json');
  }

  static Future<void> _write(Map<String, Object> value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }

  static Future<Map<String, dynamic>?> _read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> restore() async {
    try {
      final value = await _reader();
      if (value == null) return;
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
      notifyListeners();
    } catch (_) {
      saveError = '未能读取外观偏好，已使用默认设置';
      notifyListeners();
    }
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
    saveError = null;
    final value = <String, Object>{
      'appearance': this.appearance.name,
      'accent': this.accent.name,
      'compactLists': this.compactLists,
      'reduceMotion': this.reduceMotion,
      'textSize': this.textSize,
    };
    notifyListeners();
    _pending = _pending.then((_) => _writer(value)).catchError((Object _) {
      saveError = '外观已应用，本机保存失败，请稍后重试';
      notifyListeners();
    });
    return _pending;
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
