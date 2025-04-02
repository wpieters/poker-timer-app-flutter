import 'package:flutter/foundation.dart';
import 'dart:js' as js;

/// Service to manage web worker-based timer functionality
class WebTimerService {
  dynamic _worker;
  Function(int)? onTick;
  Function()? onComplete;
  
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
