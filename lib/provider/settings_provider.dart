import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:hot_live/model/liveroom.dart';
import 'package:hot_live/utils/pref_util.dart';

class SettingsProvider with ChangeNotifier {
  SettingsProvider() {
    // 设置电量监听
    initBattery();
    _loadFromPref();
  }

  // 电量状态监听
  final Battery _battery = Battery();
  int batteryLevel = 100;
  void initBattery() {
    _battery.batteryLevel.then((value) => batteryLevel = value);
    _battery.onBatteryStateChanged.listen((state) async {
      batteryLevel = await _battery.batteryLevel;
      notifyListeners();
    });
  }

  void _loadFromPref() async {
    _themeModeName = PrefUtil.getString('themeMode') ?? "System";
    _themeColorName = PrefUtil.getString('themeColor') ?? "Crimson";
    _languageName = PrefUtil.getString('language') ?? "简体中文";
    _enableAutoCheckUpdate = PrefUtil.getBool('enableAutoCheckUpdate') ?? true;
    _enableDenseFavorites = PrefUtil.getBool('enableDenseFavorites') ?? false;
    _bilibiliCustomCookie = PrefUtil.getString('bilibiliCustomCookie') ?? '';
    _danmakuArea = PrefUtil.getDouble('danmakuArea') ?? 0.5;
    _danmakuSpeed = PrefUtil.getDouble('danmakuSpeed') ?? 8;
    _danmakuFontBorder = PrefUtil.getDouble('danmakuFontBorder') ?? 0.5;
    _danmakuFontSize = PrefUtil.getDouble('danmakuFontSize') ?? 16;
    _danmakuOpacity = PrefUtil.getDouble('danmakuOpcity') ?? 1.0;
  }

  void _saveToPref() {
    PrefUtil.setString('themeMode', _themeModeName);
    PrefUtil.setString('themeColor', _themeColorName);
    PrefUtil.setString('language', _languageName);
    PrefUtil.setBool('enableDenseFavorites', _enableDenseFavorites);
    PrefUtil.setBool('enableAutoCheckUpdate', _enableAutoCheckUpdate);
    PrefUtil.setString('bilibiliCustomCookie', _bilibiliCustomCookie);
    PrefUtil.setDouble('danmakuArea', _danmakuArea);
    PrefUtil.setDouble('danmakuSpeed', _danmakuSpeed);
    PrefUtil.setDouble('danmakuFontBorder', _danmakuFontBorder);
    PrefUtil.setDouble('danmakuFontSize', _danmakuFontSize);
    PrefUtil.setDouble('danmakuOpcity', _danmakuOpacity);
  }

  // Theme settings
  static Map<String, ThemeMode> themeModes = {
    "System": ThemeMode.system,
    "Dark": ThemeMode.dark,
    "Light": ThemeMode.light,
  };

  String _themeModeName = "System";
  get themeMode => SettingsProvider.themeModes[_themeModeName]!;
  get themeModeName => _themeModeName;
  void changeThemeMode(String mode) {
    _themeModeName = mode;
    notifyListeners();
    PrefUtil.setString('themeMode', _themeModeName);
  }

  static Map<String, Color> themeColors = {
    "Crimson": const Color.fromARGB(255, 220, 20, 60),
    "Orange": Colors.orange,
    "Chrome": const Color.fromARGB(255, 230, 184, 0),
    "Grass": Colors.lightGreen,
    "Teal": Colors.teal,
    "SeaFoam": const Color.fromARGB(255, 112, 193, 207),
    "Ice": const Color.fromARGB(255, 115, 155, 208),
    "Blue": Colors.blue,
    "Indigo": Colors.indigo,
    "Violet": Colors.deepPurple,
    "Orchid": const Color.fromARGB(255, 218, 112, 214),
  };

  String _themeColorName = "Blue";
  get themeColor => SettingsProvider.themeColors[_themeColorName]!;
  get themeColorName => _themeColorName;
  void changeThemeColor(String color) {
    _themeColorName = color;
    notifyListeners();
    PrefUtil.setString('themeColor', _themeColorName);
  }

  static Map<String, Locale> languages = {
    "English": const Locale.fromSubtags(languageCode: 'en'),
    "简体中文": const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
  };
  String _languageName = "English";
  get language => SettingsProvider.languages[_languageName]!;
  get languageName => _languageName;
  void changeLanguage(String value) {
    _languageName = value;
    notifyListeners();
    PrefUtil.setString('language', _languageName);
  }

  // Custom settings
  bool _enableDenseFavorites = false;
  bool get enableDenseFavorites => _enableDenseFavorites;
  set enableDenseFavorites(bool value) {
    _enableDenseFavorites = value;
    notifyListeners();
    PrefUtil.setBool('enableDenseFavorites', _enableDenseFavorites);
  }

  bool _enableAutoCheckUpdate = true;
  bool get enableAutoCheckUpdate => _enableAutoCheckUpdate;
  set enableAutoCheckUpdate(bool value) {
    _enableAutoCheckUpdate = value;
    notifyListeners();
    PrefUtil.setBool('enableAutoCheckUpdate', _enableAutoCheckUpdate);
  }

  String _bilibiliCustomCookie = '';
  String get bilibiliCustomCookie => _bilibiliCustomCookie;
  set bilibiliCustomCookie(String value) {
    _bilibiliCustomCookie = value;
    PrefUtil.setString('bilibiliCustomCookie', _bilibiliCustomCookie);
    notifyListeners();
  }

  // Danmaku settings
  double _danmakuArea = 0.5;
  double _danmakuSpeed = 8;
  double _danmakuFontBorder = 0.5;
  double _danmakuFontSize = 16;
  double _danmakuOpacity = 1;

  double get danmakuArea => _danmakuArea;
  set danmakuArea(value) {
    if (value < 0 || value > 1) return;
    _danmakuArea = value;
    notifyListeners();
    PrefUtil.setDouble('danmakuArea', _danmakuArea);
  }

  double get danmakuSpeed => _danmakuSpeed;
  set danmakuSpeed(value) {
    if (value < 1 || value > 20) return;
    _danmakuSpeed = value;
    notifyListeners();
    PrefUtil.setDouble('danmakuSpeed', _danmakuSpeed);
  }

  double get danmakuFontBorder => _danmakuFontBorder;
  set danmakuFontBorder(value) {
    if (value < 0 || value > 2.5) return;
    _danmakuFontBorder = value;
    notifyListeners();
    PrefUtil.setDouble('danmakuFontBorder', _danmakuFontBorder);
  }

  double get danmakuFontSize => _danmakuFontSize;
  set danmakuFontSize(value) {
    if (value < 10 || value > 30) return;
    _danmakuFontSize = value;
    notifyListeners();
    PrefUtil.setDouble('danmakuFontSize', _danmakuFontSize);
  }

  double get danmakuOpacity => _danmakuOpacity;
  set danmakuOpacity(value) {
    if (value < 0 || value > 1) return;
    _danmakuOpacity = value;
    notifyListeners();
    PrefUtil.setDouble('danmakuOpcity', _danmakuOpacity);
  }

  // for backup storage
  List<RoomInfo> _favorites = [];

  void fromJson(Map<String, dynamic> json) {
    List<String> prefs = (json['favorites'] ?? []) as List<String>;
    _favorites =
        prefs.map<RoomInfo>((e) => RoomInfo.fromJson(jsonDecode(e))).toList();
    _themeModeName = json['themeMode'] ?? "System";
    _themeColorName = json['themeColor'] ?? "Crimson";
    _enableDenseFavorites = json['enableDenseFavorites'] ?? false;
    _enableAutoCheckUpdate = json['enableAutoCheckUpdate'] ?? true;
    _bilibiliCustomCookie = json['bilibiliCustomCookie'] ?? '';
    _danmakuArea = json['danmakuArea'] ?? 0.5;
    _danmakuSpeed = json['danmakuSpeed'] ?? 8;
    _danmakuFontBorder = json['danmakuFontBorder'] ?? 0.8;
    _danmakuFontSize = json['danmakuFontSize'] ?? 16;
    _danmakuOpacity = json['danmakuOpcity'] ?? 1.0;
    _saveToPref();
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['favorites'] =
        _favorites.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['themeMode'] = _themeModeName;
    json['themeColor'] = _themeColorName;
    json['enableDenseFavorites'] = _enableDenseFavorites;
    json['enableAutoCheckUpdate'] = _enableAutoCheckUpdate;
    json['bilibiliCustomCookie'] = _bilibiliCustomCookie;
    json['danmakuArea'] = _danmakuArea;
    json['danmakuSpeed'] = _danmakuSpeed;
    json['danmakuFontBorder'] = _danmakuFontBorder;
    json['danmakuFontSize'] = _danmakuFontSize;
    json['danmakuOpcity'] = _danmakuOpacity;
    return json;
  }
}
