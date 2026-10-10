import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_timer/main.dart';
import 'package:poker_timer/models/blind_settings.dart';
import 'package:poker_timer/services/alert_audio.dart';
import 'package:poker_timer/services/screen_lock.dart';
import 'package:poker_timer/services/settings_service.dart';
import 'package:poker_timer/services/wake_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestLock implements ScreenLock {
  @override
  void Function() onRelease = () {};
  bool released = false;
  @override
  Future<void> release() async {
    released = true;
    onRelease();
  }
}

class TestLockDriver implements ScreenLockDriver {
  final locks = <TestLock>[];
  @override
  Future<ScreenLock> request() async {
    final lock = TestLock();
    locks.add(lock);
    return lock;
  }
}

class TestAudio implements AlertAudio {
  int announcements = 0;
  int completions = 0;
  bool fail = false;
  @override
  Future<void> activate(double volume, {bool announce = false}) async {
    if (announce) announcements++;
  }

  @override
  Future<void> complete(double volume) async {
    if (fail) throw StateError('Audio suspended');
    completions++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'one alert per boundary, pause/resume, and reset persisted game',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.create();
      await settings.saveSettings(
        BlindSettings.defaultSettings().copyWith(intervals: [1]),
      );
      var now = DateTime.utc(2026, 10, 10);
      final audio = TestAudio();
      final driver = TestLockDriver();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: TimerHomePage(
            settingsService: settings,
            audio: audio,
            wakeLockService: WakeLockService(driver: driver),
            now: () => now,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Screen stays awake while this app is visible.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('1:00'), findsOneWidget);
      expect(audio.announcements, 1);
      now = now.add(const Duration(seconds: 65));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:55'), findsOneWidget);
      expect(audio.completions, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(audio.completions, 1);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:55'), findsOneWidget);
      expect(driver.locks.single.released, isFalse);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(audio.announcements, 1);
      now = now.add(const Duration(seconds: 55));
      await tester.pump(const Duration(seconds: 1));
      expect(audio.completions, 2);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('--:--'), findsOneWidget);
      expect(settings.restoreTimer(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(driver.locks.single.released, isTrue);
    },
  );

  testWidgets('hidden app catches up once and requests a fresh screen lock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    await settings.saveSettings(
      BlindSettings.defaultSettings().copyWith(intervals: [1]),
    );
    var now = DateTime.utc(2026, 10, 10);
    final audio = TestAudio();
    final driver = TestLockDriver();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: TimerHomePage(
          settingsService: settings,
          audio: audio,
          wakeLockService: WakeLockService(driver: driver),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    now = now.add(const Duration(seconds: 190));
    await tester.pump(const Duration(seconds: 1));
    expect(audio.completions, 0);
    expect(driver.locks.single.released, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('0:50'), findsOneWidget);
    expect(find.text('Blinds increased. Level 4.'), findsOneWidget);
    expect(audio.completions, 1);
    expect(driver.locks.length, 2);
    audio.fail = true;
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enable sound'), findsOneWidget);
    expect(find.text('Blinds increased. Level 5.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
