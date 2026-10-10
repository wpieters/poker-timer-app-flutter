import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_timer/services/screen_lock.dart';
import 'package:poker_timer/services/wake_lock_service.dart';

class FakeLock implements ScreenLock {
  @override
  void Function() onRelease = () {};
  bool released = false;
  @override
  Future<void> release() async {
    released = true;
    onRelease();
  }
}

class FakeDriver implements ScreenLockDriver {
  final requests = <Completer<ScreenLock>>[];
  @override
  Future<ScreenLock> request() {
    final pending = Completer<ScreenLock>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  test(
    'releases the actual lock and reacquires it on visibility return',
    () async {
      final driver = FakeDriver();
      final service = WakeLockService(driver: driver);
      final visible = service.setVisible(true);
      final first = FakeLock();
      driver.requests.single.complete(first);
      await visible;
      expect(service.status, WakeLockStatus.active);
      await service.retry();
      expect(driver.requests.length, 1);
      await service.setVisible(false);
      expect(first.released, isTrue);
      final resumed = service.setVisible(true);
      driver.requests.last.complete(FakeLock());
      await resumed;
      expect(driver.requests.length, 2);
      expect(service.status, WakeLockStatus.active);
      service.dispose();
    },
  );

  test('denial and OS release are reported, with an explicit retry', () async {
    final driver = FakeDriver();
    final service = WakeLockService(driver: driver);
    final visible = service.setVisible(true);
    driver.requests.single.completeError(StateError('Battery saver'));
    await visible;
    expect(service.status, WakeLockStatus.unavailable);
    final retry = service.retry();
    final lock = FakeLock();
    driver.requests.last.complete(lock);
    await retry;
    lock.onRelease();
    expect(service.status, WakeLockStatus.unavailable);
    service.dispose();
  });

  test('a late request cannot keep a hidden or disposed app awake', () async {
    final driver = FakeDriver();
    final service = WakeLockService(driver: driver);
    final visible = service.setVisible(true);
    await service.setVisible(false);
    service.dispose();
    final lateLock = FakeLock();
    driver.requests.single.complete(lateLock);
    await visible;
    expect(lateLock.released, isTrue);
  });

  test(
    'hide and show during a pending request replaces the stale lock',
    () async {
      final driver = FakeDriver();
      final service = WakeLockService(driver: driver);
      final visible = service.setVisible(true);
      await service.setVisible(false);
      await service.setVisible(true);
      final staleLock = FakeLock();
      driver.requests.single.complete(staleLock);
      await Future<void>.delayed(Duration.zero);
      expect(staleLock.released, isTrue);
      expect(driver.requests.length, 2);
      driver.requests.last.complete(FakeLock());
      await visible;
      expect(service.status, WakeLockStatus.active);
      service.dispose();
    },
  );
}
