import 'package:shared_preferences/shared_preferences.dart';
import '../models/blind_settings.dart';

class SettingsService {
  static const String _settingsKey = 'blind_settings';
  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  Future<void> saveSettings(BlindSettings settings) async {
    await _prefs.setString(_settingsKey, settings.toJsonString());
  }

  BlindSettings getSettings() {
    final jsonString = _prefs.getString(_settingsKey);
    if (jsonString == null) {
      return BlindSettings.defaultSettings();
    }
    try {
      return BlindSettings.fromJsonString(jsonString);
    } catch (e) {
      return BlindSettings.defaultSettings();
    }
  }
}
