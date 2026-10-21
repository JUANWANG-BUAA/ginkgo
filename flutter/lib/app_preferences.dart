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

enum AppAccent {
  green('银杏绿', AppleDesign.accent),
  blue('蓝色', AppleDesign.resourceBlue),
  purple('紫色', AppleDesign.resourcePurple);

  const AppAccent(this.label, this.color);
  final String label;
  final Color color;
}

typedef PreferencesWriter = Future<void> Function(Map<String, Object> value);

/// Device-wide display choices only. Credentials and school data never enter
/// this file. Serial writes prevent a slower old choice overwriting a new one.
class AppPreferences extends ChangeNotifier {
  AppPreferences({PreferencesWriter? writer}) : _writer = writer ?? _write;
  static final shared = AppPreferences();
  final PreferencesWriter _writer;
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

  Future<void> restore() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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
