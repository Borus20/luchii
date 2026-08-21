import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get hapticsEnabled => _prefs.getBool('haptics_enabled') ?? true;
  static Future<void> setHapticsEnabled(bool v) => _prefs.setBool('haptics_enabled', v);

  static String get themeMode => _prefs.getString('theme_mode') ?? 'dark';
  static Future<void> setThemeMode(String v) => _prefs.setString('theme_mode', v);

  static String get saveDir => _prefs.getString('save_dir') ?? '';
  static Future<void> setSaveDir(String v) => _prefs.setString('save_dir', v);
}
