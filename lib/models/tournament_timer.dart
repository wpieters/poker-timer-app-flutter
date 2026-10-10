import 'dart:math' as math;

import 'blind_settings.dart';

enum TimerState { initial, running, paused }

/// The deadline is authoritative; callbacks only refresh the displayed state.
class TournamentTimer {
  TournamentTimer(BlindSettings settings)
    : settings = settings.copyWith(
        intervals: List.unmodifiable(settings.intervals),
        chipLevels: List.unmodifiable(settings.chipLevels),
      ) {
    if (settings.intervals.isEmpty ||
        settings.intervals.any((minutes) => minutes <= 0) ||
        settings.chipLevels.isEmpty) {
      throw ArgumentError(
        'A tournament needs positive intervals and chip levels.',
      );
    }
  }

  final BlindSettings settings;
  TimerState state = TimerState.initial;
  int levelIndex = 0;
  DateTime? _deadline;
  Duration _pausedRemaining = Duration.zero;

  int get intervalMinutes =>
      settings.intervals[math.min(levelIndex, settings.intervals.length - 1)];

  ChipLevel get currentLevel {
    final levels = settings.chipLevels;
    if (levelIndex < levels.length) return levels[levelIndex];
    return levels.last.copyWith(
      bigBlindMultiplier:
          levels.last.bigBlindMultiplier *
          math.pow(2, levelIndex - levels.length + 1).toInt(),
    );
  }

  int remainingSeconds(DateTime now) {
    final remaining = state == TimerState.running
        ? _deadline!.difference(now)
        : _pausedRemaining;
    return math.max(0, (remaining.inMicroseconds / 1000000).ceil());
  }

  void start(DateTime now) {
    if (state == TimerState.running) return;
    final remaining = state == TimerState.initial
        ? Duration(minutes: intervalMinutes)
        : _pausedRemaining;
    _deadline = now.add(remaining);
    state = TimerState.running;
  }

  void pause(DateTime now) {
    if (state != TimerState.running) return;
    synchronize(now);
    _pausedRemaining = _deadline!.difference(now);
    _deadline = null;
    state = TimerState.paused;
  }

  /// Returns completed levels, including ones missed during sleep.
  int synchronize(DateTime now) {
    if (state != TimerState.running) return 0;
    final previousLevel = levelIndex;
    while (!now.isBefore(_deadline!) &&
        levelIndex < settings.intervals.length - 1) {
      levelIndex++;
      _deadline = _deadline!.add(Duration(minutes: intervalMinutes));
    }
    if (!now.isBefore(_deadline!)) {
      final interval = Duration(minutes: intervalMinutes);
      final completed =
          now.difference(_deadline!).inMicroseconds ~/ interval.inMicroseconds +
          1;
      levelIndex += completed;
      _deadline = _deadline!.add(interval * completed);
    }
    return levelIndex - previousLevel;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'settings': settings.toJson(),
    'state': state.name,
    'levelIndex': levelIndex,
    'deadline': _deadline?.millisecondsSinceEpoch,
    'pausedMicroseconds': _pausedRemaining.inMicroseconds,
  };

  factory TournamentTimer.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown session version');
    }
    final timer = TournamentTimer(BlindSettings.fromJson(json['settings']));
    timer.state = TimerState.values.byName(json['state']);
    timer.levelIndex = json['levelIndex'] as int;
    timer._pausedRemaining = Duration(
      microseconds: json['pausedMicroseconds'] as int,
    );
    final deadline = json['deadline'] as int?;
    timer._deadline = deadline == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(deadline);
    if (timer.levelIndex < 0 ||
        timer._pausedRemaining.isNegative ||
        (timer.state == TimerState.running && timer._deadline == null)) {
      throw const FormatException('Invalid timer session');
    }
    return timer;
  }
}
