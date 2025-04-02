import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:js_util' show promiseToFuture;

/// Service to manage wake lock functionality for web platform
class WakeLockService {
  dynamic _wakeLock;
  
  /// Request a wake lock to keep the screen active
  Future<void> requestWakeLock() async {
    if (!kIsWeb) return;
    
    try {
      // First check if wake lock is supported
      final hasWakeLock = js.context.callMethod('eval', [
        '''
        (function() {
          return 'wakeLock' in navigator;
        })()
        '''
      ]);
      
      if (hasWakeLock == true) {
        _wakeLock = await promiseToFuture(js.context.callMethod('eval', [
          '''
          navigator.wakeLock.request('screen')
          '''
        ]));
      }
    } catch (e) {
      // Wake lock is not critical for functionality, just log the error
      debugPrint('Wake Lock not supported or error: $e');
    }
  }

  /// Release the wake lock
  void releaseWakeLock() {
    if (!kIsWeb || _wakeLock == null) return;
    
    try {
      js.context.callMethod('eval', [
        '''
        (function() {
          if (window.wakeLock && window.wakeLock.release) {
            window.wakeLock.release();
          }
        })()
        '''
      ]);
      _wakeLock = null;
    } catch (e) {
      debugPrint('Error releasing wake lock: $e');
    }
  }
}
