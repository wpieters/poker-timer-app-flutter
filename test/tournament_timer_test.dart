import 'package:flutter_test/flutter_test.dart';
import 'package:poker_timer/models/blind_settings.dart';
import 'package:poker_timer/models/tournament_timer.dart';

void main() {
  final start = DateTime.utc(2026, 10, 10, 18);
  TournamentTimer timer([List<int> intervals = const [1, 2, 1]]) =>
      TournamentTimer(
        BlindSettings.defaultSettings().copyWith(intervals: intervals),
      );

  test('late ticks use the deadline, with one completion per level', () {
    final game = timer()..start(start);
    expect(game.remainingSeconds(start.add(const Duration(seconds: 5))), 55);
    expect(game.synchronize(start.add(const Duration(seconds: 65))), 1);
    expect(game.remainingSeconds(start.add(const Duration(seconds: 65))), 115);
    expect(game.synchronize(start.add(const Duration(seconds: 65))), 0);
    expect(game.levelIndex, 1);
  });

  test('sleep catches up every missed level and retains overflow time', () {
    final game = timer()..start(start);
    expect(game.synchronize(start.add(const Duration(seconds: 310))), 4);
    expect(game.levelIndex, 4);
    expect(game.intervalMinutes, 1);
    expect(game.remainingSeconds(start.add(const Duration(seconds: 310))), 50);
  });

  test('foreground time is not added back on resume', () {
    final game = timer([45])..start(start);
    game.synchronize(start.add(const Duration(minutes: 20)));
    game.synchronize(start.add(const Duration(minutes: 25)));
    expect(
      game.remainingSeconds(start.add(const Duration(minutes: 25))),
      20 * 60,
    );
  });

  test('pause preserves subsecond remainder and ignores time spent paused', () {
    final game = timer()..start(start);
    game.pause(start.add(const Duration(milliseconds: 1500)));
    game.start(start.add(const Duration(hours: 1)));
    expect(
      game.synchronize(start.add(const Duration(hours: 1, seconds: 58))),
      0,
    );
    expect(
      game.remainingSeconds(start.add(const Duration(hours: 1, seconds: 58))),
      1,
    );
    expect(
      game.synchronize(
        start.add(const Duration(hours: 1, milliseconds: 58500)),
      ),
      1,
    );
  });

  test('running session survives reload and catches up', () {
    final game = timer()..start(start);
    final restored = TournamentTimer.fromJson(game.toJson());
    expect(restored.synchronize(start.add(const Duration(seconds: 190))), 2);
    expect(
      restored.remainingSeconds(start.add(const Duration(seconds: 190))),
      50,
    );
  });

  test('paused session survives reload without advancing', () {
    final game = timer()..start(start);
    game.pause(start.add(const Duration(seconds: 10)));
    final restored = TournamentTimer.fromJson(game.toJson());
    expect(restored.synchronize(start.add(const Duration(days: 1))), 0);
    expect(restored.remainingSeconds(start.add(const Duration(days: 1))), 50);
    expect(restored.state, TimerState.paused);
  });

  test('blinds double beyond the predefined levels', () {
    final game = timer([1])..start(start);
    game.synchronize(start.add(const Duration(minutes: 6)));
    expect(game.currentLevel.bigBlindMultiplier, 8);
  });

  test('invalid intervals cannot cause an infinite catch-up loop', () {
    expect(() => timer([]), throwsArgumentError);
    expect(() => timer([0]), throwsArgumentError);
    expect(() => timer([-1]), throwsArgumentError);
  });
}
