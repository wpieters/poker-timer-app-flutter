import 'package:wakelock_plus/wakelock_plus.dart';

import 'screen_lock.dart';

ScreenLockDriver createScreenLockDriver() => _NativeDriver();

class _NativeDriver implements ScreenLockDriver {
  @override
  Future<ScreenLock> request() async {
    await WakelockPlus.enable();
    return _NativeLock();
  }
}

class _NativeLock implements ScreenLock {
  @override
  set onRelease(void Function() callback) {}

  @override
  Future<void> release() => WakelockPlus.disable();
}
