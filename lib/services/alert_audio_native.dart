import 'package:audioplayers/audioplayers.dart';

class AlertAudio {
  final AudioPlayer _player = AudioPlayer();

  Future<void> activate(double volume, {bool announce = false}) async {
    if (announce) await _play('game_begun', volume);
  }

  Future<void> complete(double volume) => _play('timer_end', volume);

  Future<void> _play(String name, double volume) async {
    await _player.setVolume(volume);
    await _player.play(AssetSource('audio/$name.mp3'));
  }

  Future<void> dispose() => _player.dispose();
}
