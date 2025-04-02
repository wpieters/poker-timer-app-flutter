import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:js_util' show promiseToFuture;
import 'dart:async';

/// Service to manage wake lock functionality for web platform
class WakeLockService {
  dynamic _wakeLock;
  bool _isActive = false;
  Timer? _renewTimer;
  
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
        // Try the standard Wake Lock API
        await _requestStandardWakeLock();
      } else {
        // Fallback to NoSleep.js approach
        await _requestNoSleepWakeLock();
      }
      
      // Set up a renewal timer to periodically refresh the wake lock
      // This helps with some browsers that may release the lock after a period
      _renewTimer?.cancel();
      _renewTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (_isActive) {
          requestWakeLock(); // Re-request the wake lock periodically
        }
      });
      
      _isActive = true;
    } catch (e) {
      // Wake lock is not critical for functionality, just log the error
      debugPrint('Wake Lock not supported or error: $e');
      // Try alternative approach if primary method fails
      await _requestNoSleepWakeLock();
    }
  }

  /// Request wake lock using the standard Wake Lock API
  Future<void> _requestStandardWakeLock() async {
    try {
      _wakeLock = await promiseToFuture(js.context.callMethod('eval', [
        '''
        navigator.wakeLock.request('screen')
        '''
      ]));
      debugPrint('Standard wake lock acquired');
    } catch (e) {
      debugPrint('Standard wake lock failed: $e');
      throw e; // Rethrow to try alternative methods
    }
  }
  
  /// Request wake lock using NoSleep.js approach (video playback trick)
  Future<void> _requestNoSleepWakeLock() async {
    try {
      // Create a hidden video element that plays silently to prevent sleep
      final result = js.context.callMethod('eval', [
        '''
        (function() {
          // Remove any existing nosleep video
          var existingVideo = document.getElementById('nosleep-video');
          if (existingVideo) {
            document.body.removeChild(existingVideo);
          }
          
          // Create a new video element
          var video = document.createElement('video');
          video.id = 'nosleep-video';
          video.setAttribute('loop', '');
          video.setAttribute('playsinline', '');
          video.setAttribute('muted', '');
          video.style.display = 'none';
          
          // Create a source with a 1x1 black video
          var source = document.createElement('source');
          source.src = 'data:video/mp4;base64,AAAAIGZ0eXBtcDQyAAAAAG1wNDJtcDQxaXNvbWF2YzEAAATKbW9vdgAAAGxtdmhkAAAAANLEP5XSxD+VAAB1MAAAdU4AAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAACFpb2RzAAAAABCAgIAQAE////9//w6AgIAEAAAAAQAABDV0cmFrAAAAXHRraGQAAAAH0sQ/ldLEP5UAAAABAAAAAAAAdU4AAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAIWaWRhdAAAABBpZGF0AAAAAAAAAAAAAAAAAC5tZGlyAAAAHm1kaGQAAAAAAAAAAAAAAAAAAKxEAAAIAFXEAAAAAAAtaGRscgAAAAAAAAAAc291bgAAAAAAAAAAAAAAAFNvdW5kSGFuZGxlcgAAAAEPbWluZgAAABBzbWhkAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAADTc3RibAAAAGdzdHNkAAAAAAAAAAEAAABXbXA0YQAAAAAAAAABAAAAAAAAAAAAAgAQAAAAAKxEAAAAAAAzZXNkcwAAAAADgICAIgACAASAgIAUQBUAAAAAAfQAAAHz+QWAgIACEhAGgICAAQIAAAAYc3R0cwAAAAAAAAABAAAAAgAABAAAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAIAAAABAAAAHHN0c3oAAAAAAAAAAAAAAAIAAAFzAAABdAAAABRzdGNvAAAAAAAAAAEAAAAsAAAAYnVkdGEAAABabWV0YQAAAAAAAAAhaGRscgAAAAAAAAAAbWRpcmAAAAAAAAAAAAAAAAAAAAA6aWxzdAAAADKpdG9vAAAAKmRhdGEAAAABAAAAAEhhbmRCcmFrZSAxLjEuMiAyMDE4MDkwNTAw';
          video.appendChild(source);
          
          // Add to document and play
          document.body.appendChild(video);
          var playPromise = video.play();
          
          if (playPromise !== undefined) {
            playPromise.catch(function(error) {
              console.error('NoSleep video play error:', error);
            });
          }
          
          return true;
        })()
        '''
      ]);
      
      debugPrint('NoSleep wake lock approach: $result');
      return;
    } catch (e) {
      debugPrint('NoSleep wake lock failed: $e');
    }
  }

  /// Release the wake lock
  void releaseWakeLock() {
    if (!kIsWeb) return;
    
    _isActive = false;
    _renewTimer?.cancel();
    _renewTimer = null;
    
    try {
      // Release standard wake lock if we have one
      if (_wakeLock != null) {
        js.context.callMethod('eval', [
          '''
          (function() {
            try {
              if (document.getElementById('nosleep-video')) {
                var video = document.getElementById('nosleep-video');
                video.pause();
                if (video.parentElement) {
                  video.parentElement.removeChild(video);
                }
              }
            } catch (e) {
              console.error('Error removing NoSleep video:', e);
            }
          })()
          '''
        ]);
        
        try {
          // Try to release standard wake lock
          js.context.callMethod('eval', [
            '''
            (function() {
              if (navigator.wakeLock && navigator.wakeLock.release) {
                navigator.wakeLock.release();
              }
            })()
            '''
          ]);
        } catch (e) {
          debugPrint('Error releasing standard wake lock: $e');
        }
      }
      
      _wakeLock = null;
    } catch (e) {
      debugPrint('Error releasing wake lock: $e');
    }
  }
}
