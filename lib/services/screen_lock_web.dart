import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'screen_lock.dart';

ScreenLockDriver createScreenLockDriver() => _WebDriver();

class _WebDriver implements ScreenLockDriver {
  @override
  Future<ScreenLock> request() async {
    final sentinel = await web.window.navigator.wakeLock
        .request('screen')
        .toDart;
    return _WebLock(sentinel);
  }
}

class _WebLock implements ScreenLock {
  _WebLock(this.sentinel);
  final web.WakeLockSentinel sentinel;
  JSFunction? _listener;

  @override
  set onRelease(void Function() callback) {
    final oldListener = _listener;
    if (oldListener != null) {
      sentinel.removeEventListener('release', oldListener);
    }
    _listener = ((web.Event event) => callback()).toJS;
    sentinel.addEventListener('release', _listener);
    if (sentinel.released) callback();
  }

  @override
  Future<void> release() async {
    final listener = _listener;
    if (listener != null) sentinel.removeEventListener('release', listener);
    await sentinel.release().toDart;
  }
}
