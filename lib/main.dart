import 'package:flutter/material.dart';
import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:poker_timer/models/blind_settings.dart';
import 'package:poker_timer/services/settings_service.dart';
import 'package:poker_timer/pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SettingsService.create();
  runApp(TimerApp(settingsService: settingsService));
}

class TimerApp extends StatelessWidget {
  final SettingsService settingsService;

  const TimerApp({super.key, required this.settingsService});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interval Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TimerHomePage(settingsService: settingsService),
    );
  }
}

class TimerHomePage extends StatefulWidget {
  final SettingsService settingsService;

  const TimerHomePage({super.key, required this.settingsService});
  @override
  _TimerHomePageState createState() => _TimerHomePageState();
}

enum TimerState {
  initial,   // Start enabled, Stop disabled
  running,   // Start disabled, Stop enabled
  paused,    // Resume enabled, Reset enabled
}

class _TimerHomePageState extends State<TimerHomePage> {
  final AssetsAudioPlayer _audioPlayer = AssetsAudioPlayer();
  bool _audioInitialized = false;
  late List<int> intervals;
  late List<ChipLevel> chipLevels;
  int? currentInterval;
  Timer? _timer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  String message = "Press start to begin timer.";
  TimerState _timerState = TimerState.initial;
  int currentBlindIndex = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateBlinds() {
    if (currentBlindIndex < chipLevels.length - 1) {
      // If we have more predefined chip levels, use the next one
      currentBlindIndex++;
    } else {
      // We've reached the last predefined level, create a new level with doubled values
      final lastLevel = chipLevels.last;
      final newLevel = ChipLevel(
        smallBlindColor: lastLevel.smallBlindColor,
        bigBlindColor: lastLevel.bigBlindColor,
        bigBlindMultiplier: lastLevel.bigBlindMultiplier * 2,
      );
      
      // Add the new level to the list
      chipLevels.add(newLevel);
      currentBlindIndex++;
      
      // Update the message to indicate blinds have doubled
      message = "Blinds doubled! New big blind multiplier: ${newLevel.bigBlindMultiplier}";
    }
  }

  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
      _countdownTimer = null;
    }
    setState(() {
      _timerState = TimerState.running;
    });

    // Handle different scenarios for setting the current interval
    if (_timerState == TimerState.paused) {
      // We're resuming, keep the current interval and remaining seconds
    } else if (currentInterval == null) {
      // Starting fresh, get the first interval
      if (intervals.isNotEmpty) {
        currentInterval = intervals.removeAt(0);
      } else {
        currentInterval = 10;
      }
      _remainingSeconds = currentInterval! * 60;
    } else {
      // Timer expired, move to next interval
      if (intervals.isNotEmpty) {
        currentInterval = intervals.removeAt(0);
        _remainingSeconds = currentInterval! * 60;
      } else {
        // No more intervals, stay at current interval (already handled by _updateBlinds)
        _remainingSeconds = currentInterval! * 60;
      }
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
      });
    });

    // Calculate the remaining duration based on _remainingSeconds
    final durationInSeconds = _remainingSeconds;
    _timer = Timer(Duration(seconds: durationInSeconds), () async {
      // Play sound when timer ends
      final settings = widget.settingsService.getSettings();
      try {
        if (_audioInitialized) {
          // If audio is already initialized, just play it
          await _audioPlayer.play();
        } else {
          // Fallback if not initialized
          await _audioPlayer.open(
            Audio("assets/audio/timer_end.mp3"),
            autoStart: true,
            showNotification: false,
            volume: settings.volume,
          );
        }
      } catch (e) {
        print("Error playing audio: $e");
      }
      setState(() {
        _updateBlinds();
        message = "$currentInterval minutes passed!";
        // Reset currentInterval to null to indicate we need a new interval
        currentInterval = null;
        _startTimer();
      });
    });

    setState(() {
      if (_timerState == TimerState.paused) {
        message = "Timer resumed with ${(_remainingSeconds / 60).floor()}:${(_remainingSeconds % 60).toString().padLeft(2, '0')} remaining.";
      } else {
        message = "Timer set for $currentInterval minutes.";
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      if (_timerState == TimerState.running) {
        _timerState = TimerState.paused;
        message = "Timer paused.";
      } else {
        // Reset
        _timerState = TimerState.initial;
        message = "Timer reset.";
        intervals = widget.settingsService.getSettings().intervals;
        currentBlindIndex = 0;
        currentInterval = null;
        _remainingSeconds = 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeAudio();
  }
  
  void _initializeAudio() {
    // Pre-load audio to handle web browser restrictions
    _audioPlayer.open(
      Audio("assets/audio/timer_end.mp3"),
      autoStart: false,
      showNotification: false,
      volume: widget.settingsService.getSettings().volume,
    ).then((_) {
      setState(() {
        _audioInitialized = true;
      });
    });
  }

  void _loadSettings() {
    final settings = widget.settingsService.getSettings();
    setState(() {
      intervals = List.from(settings.intervals);
      chipLevels = List.from(settings.chipLevels);
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          settingsService: widget.settingsService,
          onSettingsChanged: (newSettings) {
            setState(() {
              intervals = List.from(newSettings.intervals);
              chipLevels = List.from(newSettings.chipLevels);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = chipLevels[currentBlindIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Poker Blinds Timer"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 180,
                        width: 180,
                        child: CircularProgressIndicator(
                          value: currentInterval != null ? _remainingSeconds / (currentInterval! * 60) : 0,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[700],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      Text(
                        currentInterval != null
                            ? '${(_remainingSeconds / 60).floor()}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}'
                            : '--:--',
                        style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(width: 120, child: Text('Small Blind', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]))),
                    SizedBox(width: 120, child: Text('Big Blind', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]))),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: currentLevel.smallBlindColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                        if (currentLevel.bigBlindMultiplier > 1)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "×${currentLevel.bigBlindMultiplier ~/ 2}",
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: currentLevel.bigBlindColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                        if (currentLevel.bigBlindMultiplier > 1)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "×${currentLevel.bigBlindMultiplier}",
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Text(
              message,
              style: const TextStyle(fontSize: 20.0),
            ),
            const SizedBox(height: 20.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _timerState == TimerState.running ? null : _startTimer,
                  child: Text(_timerState == TimerState.paused ? 'Resume' : 'Start'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _timerState == TimerState.initial ? null : _stopTimer,
                  child: Text(_timerState == TimerState.paused ? 'Reset' : 'Stop'),
                ),
              ],
            )
          ],
        ),
      ),
      backgroundColor: Colors.grey,
    );
  }
}
