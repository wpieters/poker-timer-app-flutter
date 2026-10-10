import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/blind_settings.dart';
import '../models/tournament_timer.dart';

class SettingsService {
  static const String _settingsKey = 'blind_settings';
  final SharedPreferences _prefs;
  Future<void> _pendingSave = Future.value();

  SettingsService(this._prefs);

  TournamentTimer? restoreTimer() {
    final saved = _prefs.getString('tournament_session');
    if (saved == null) return null;
    try {
      return TournamentTimer.fromJson(jsonDecode(saved));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTimer(TournamentTimer timer) {
    final snapshot = timer.state == TimerState.initial
        ? null
        : jsonEncode(timer.toJson());
    final save = _pendingSave.then((_) async {
      if (snapshot == null) {
        await _prefs.remove('tournament_session');
      } else {
        await _prefs.setString('tournament_session', snapshot);
      }
    });
    _pendingSave = save.catchError((Object _) {});
    return save;
  }

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
