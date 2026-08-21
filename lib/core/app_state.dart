import 'package:flutter/material.dart';
import 'prefs.dart';
import 'haptics.dart';

class AppState extends ChangeNotifier {
  bool _hapticsEnabled = true;
  ThemeMode _themeMode = ThemeMode.dark;

  bool get hapticsEnabled => _hapticsEnabled;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    _hapticsEnabled = Prefs.hapticsEnabled;
    HapticsService.setEnabled(_hapticsEnabled);
    final mode = Prefs.themeMode;
    _themeMode = mode == 'light'
        ? ThemeMode.light
        : mode == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    HapticsService.setEnabled(value);
    await Prefs.setHapticsEnabled(value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final str = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    await Prefs.setThemeMode(str);
    notifyListeners();
  }
}
