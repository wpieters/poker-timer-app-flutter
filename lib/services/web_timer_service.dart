import 'package:flutter/foundation.dart';
import 'dart:js' as js;

/// Service to manage web worker-based timer functionality
class WebTimerService {
  dynamic _worker;
  Function(int)? onTick;
  Function()? onComplete;
  int _currentSeconds = 0;
  
  /// Initialize the web worker for timing
  void initialize() {
    if (!kIsWeb) return;
    
    js.context.callMethod('eval', [
      '''
      if (!window.pokerTimerWorker) {
        window.pokerTimerWorker = new Worker('timer_worker.js');
      }
      '''
    ]);
    
    _worker = js.context['pokerTimerWorker'];
    
    js.context.callMethod('eval', [
      '''
      window.pokerTimerWorker.onmessage = function(e) {
        if (e.data.type === 'tick') {
          window.flutterPokerTimerCallback(e.data.remainingSeconds);
        } else if (e.data.type === 'complete') {
          window.flutterPokerTimerComplete();
        }
      };
      '''
    ]);
    
    // Register the callback functions
    js.context['flutterPokerTimerCallback'] = (int seconds) {
      onTick?.call(seconds);
    };
    
    js.context['flutterPokerTimerComplete'] = () {
      onComplete?.call();
    };
  }
  
  /// Start the timer with the given number of seconds
  void startTimer(int seconds) {
    if (!kIsWeb || _worker == null) return;
    
    _currentSeconds = seconds;
    _worker.callMethod('postMessage', [js.JsObject.jsify({
      'type': 'start',
      'data': {'seconds': seconds},
    })]);
  }
  
  /// Pause the timer
  void pauseTimer() {
    if (!kIsWeb || _worker == null) return;
    
    _worker.callMethod('postMessage', [js.JsObject.jsify({
      'type': 'pause',
    })]);
  }
  
  /// Stop the timer completely
  void stopTimer() {
    if (!kIsWeb || _worker == null) return;
    
    _worker.callMethod('postMessage', [js.JsObject.jsify({
      'type': 'stop',
    })]);
  }
  
  /// Adjust the timer by the given duration (typically after app resume)
  void adjustTimerForElapsedDuration(Duration elapsed) {
    if (!kIsWeb || _worker == null) return;
    
    // Calculate new remaining seconds
    final elapsedSeconds = elapsed.inSeconds;
    if (elapsedSeconds <= 0) return;
    
    // Adjust the current seconds
    _currentSeconds = _currentSeconds > elapsedSeconds ? 
        _currentSeconds - elapsedSeconds : 0;
    
    // Update the timer in the worker
    _worker.callMethod('postMessage', [js.JsObject.jsify({
      'type': 'adjust',
      'data': {'seconds': _currentSeconds},
    })]);
    
    // If timer would have completed during background, trigger completion
    if (_currentSeconds <= 0) {
      onComplete?.call();
    } else {
      // Otherwise update the UI with new time
      onTick?.call(_currentSeconds);
    }
  }

  /// Dispose of the web worker
  void dispose() {
    if (!kIsWeb || _worker == null) return;
    
    js.context.callMethod('eval', [
      '''
      if (window.pokerTimerWorker) {
        window.pokerTimerWorker.terminate();
        window.pokerTimerWorker = null;
      }
      '''
    ]);
    _worker = null;
  }
}
