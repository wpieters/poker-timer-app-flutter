import 'dart:async';

import 'package:flutter/foundation.dart';

import 'screen_lock.dart';
import 'screen_lock_native.dart'
    if (dart.library.js_interop) 'screen_lock_web.dart';

enum WakeLockStatus { inactive, requesting, active, unavailable }

/// Holds a screen lock while visible and reacquires it after returning to the app.
class WakeLockService extends ChangeNotifier {
  WakeLockService({ScreenLockDriver? driver})
    : _driver = driver ?? createScreenLockDriver();

  final ScreenLockDriver _driver;
  ScreenLock? _lock;
  bool _visible = false;
  bool _disposed = false;
  bool _requesting = false;
  int _generation = 0;
  WakeLockStatus status = WakeLockStatus.inactive;

  void _setStatus(WakeLockStatus value) {
    if (_disposed || status == value) return;
    status = value;
    notifyListeners();
  }

  Future<void> setVisible(bool visible) async {
    if (_disposed) return;
    if (_visible != visible) _generation++;
    _visible = visible;
    if (!visible) {
      final lock = _lock;
      _lock = null;
      _setStatus(WakeLockStatus.inactive);
      if (lock != null) await _release(lock);
    } else {
      await retry();
    }
  }

  Future<void> retry() async {
    if (_disposed || !_visible || _requesting || _lock != null) return;
    final generation = _generation;
    _requesting = true;
    _setStatus(WakeLockStatus.requesting);
    try {
      final lock = await _driver.request();
      if (_disposed || !_visible || generation != _generation) {
        await _release(lock);
      } else {
        _lock = lock;
        _setStatus(WakeLockStatus.active);
        lock.onRelease = () {
          if (_disposed || _lock != lock) return;
          _lock = null;
          _setStatus(
            _visible ? WakeLockStatus.unavailable : WakeLockStatus.inactive,
          );
        };
      }
    } catch (error) {
      debugPrint('Screen wake lock unavailable: $error');
      if (generation == _generation) _setStatus(WakeLockStatus.unavailable);
    } finally {
      _requesting = false;
      if (!_disposed && _visible && generation != _generation) await retry();
    }
  }

  Future<void> _release(ScreenLock lock) async {
    try {
      await lock.release();
    } catch (error) {
      debugPrint('Could not release screen wake lock: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _visible = false;
    _generation++;
    final lock = _lock;
    _lock = null;
    if (lock != null) unawaited(_release(lock));
    super.dispose();
  }
}
