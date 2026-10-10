import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// One context, unlocked directly from Start/Resume, for all tournament sounds.
class AlertAudio {
  web.AudioContext? _context;
  web.GainNode? _gain;
  web.AudioBufferSourceNode? _source;
  final Map<String, web.AudioBuffer> _buffers = {};
  bool _disposed = false;

  web.AudioContext get _audioContext {
    if (_context == null) {
      final context = _context = web.AudioContext();
      _gain = context.createGain()..connect(context.destination);
    }
    return _context!;
  }

  Future<web.AudioBuffer> _load(String name) async {
    if (_buffers[name] case final buffer?) return buffer;
    final context = _audioContext;
    final bytes = await rootBundle.load('assets/audio/$name.mp3');
    final buffer = await context
        .decodeAudioData(
          Uint8List.fromList(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          ).buffer.toJS,
        )
        .toDart;
    _buffers[name] = buffer;
    return buffer;
  }

  Future<void> activate(double volume, {bool announce = false}) async {
    // Call resume BEFORE the first await, while the user gesture is still active.
    final resume = _audioContext.resume().toDart;
    await resume;
    await _load('timer_end');
    if (announce && !_disposed) await _play('game_begun', volume);
  }

  Future<void> complete(double volume) => _play('timer_end', volume);

  Future<void> _play(String name, double volume) async {
    if (_disposed || volume == 0) return;
    final context = _audioContext;
    if (context.state != 'running') {
      throw StateError('Tap Enable sound to resume audio.');
    }
    final buffer = await _load(name);
    if (_disposed) return;
    _source?.stop();
    _source?.disconnect();
    _gain!.gain.value = volume;
    _source = context.createBufferSource()
      ..buffer = buffer
      ..connect(_gain!)
      ..start();
  }

  Future<void> dispose() async {
    _disposed = true;
    _source?.stop();
    if (_context case final context?) await context.close().toDart;
  }
}
