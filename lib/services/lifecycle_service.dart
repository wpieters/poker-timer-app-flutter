import 'package:flutter/material.dart';
import 'dart:async';

/// Service to handle app lifecycle events and provide time tracking
class LifecycleService with WidgetsBindingObserver {
  DateTime? _pausedTime;
  Function(Duration)? onResumeWithElapsed;
  bool _isInitialized = false;
  Timer? _visibilityCheckTimer;
  bool _wasVisible = true;

  /// Initialize the lifecycle observer
  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _setupVisibilityDetection();
      _isInitialized = true;
    }
  }
  
  /// Set up additional visibility detection for web
  void _setupVisibilityDetection() {
    // Check if we need to monitor visibility changes separately
    // This helps with screen lock detection which might not trigger lifecycle events
    _visibilityCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final isVisible = _checkVisibility();
      
      // If visibility changed
      if (isVisible != _wasVisible) {
        final now = DateTime.now();
        
        if (!isVisible) {
          // Screen just became invisible (locked or background)
          _pausedTime = now;
          debugPrint('Screen became invisible at ${now.toIso8601String()}');
        } else if (_pausedTime != null) {
          // Screen just became visible again
          final elapsedDuration = now.difference(_pausedTime!);
          debugPrint('Screen became visible again after ${elapsedDuration.inSeconds} seconds');
          
          // Only trigger if it's been at least 2 seconds
          // This helps filter out false positives
          if (elapsedDuration.inSeconds >= 2) {
            onResumeWithElapsed?.call(elapsedDuration);
          }
          _pausedTime = null;
        }
        
        _wasVisible = isVisible;
      }
    });
  }
  
  /// Check if the app is currently visible
  bool _checkVisibility() {
    // For Flutter's standard lifecycle detection
    // This is our default state based on lifecycle events
    return _pausedTime == null;
  }

  /// Handle lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    
    switch (state) {
      case AppLifecycleState.paused:
        // App is not visible, going to background or screen locked
        _pausedTime = now;
        debugPrint('App lifecycle paused at ${now.toIso8601String()}');
        break;
      case AppLifecycleState.resumed:
        // App is visible again
        if (_pausedTime != null) {
          final elapsedDuration = now.difference(_pausedTime!);
          debugPrint('App lifecycle resumed after ${elapsedDuration.inSeconds} seconds');
          
          // Only notify if we've been paused for at least 1 second
          // This helps filter out false positives
          if (elapsedDuration.inSeconds >= 1) {
            onResumeWithElapsed?.call(elapsedDuration);
          }
          _pausedTime = null;
        }
        break;
      case AppLifecycleState.detached:
        // App is completely detached from the view hierarchy
        _pausedTime = now;
        debugPrint('App lifecycle detached at ${now.toIso8601String()}');
        break;
      default:
        // Handle other states if needed
        break;
    }
  }

  /// Dispose the lifecycle observer
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _visibilityCheckTimer?.cancel();
      _isInitialized = false;
    }
  }
}
