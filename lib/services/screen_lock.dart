abstract interface class ScreenLock {
  set onRelease(void Function() callback);
  Future<void> release();
}

abstract interface class ScreenLockDriver {
  Future<ScreenLock> request();
}
