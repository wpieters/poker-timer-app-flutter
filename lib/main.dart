import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:audioplayers/audioplayers.dart';
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
      title: 'Poker Timer',
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
  initial, // Start enabled, Stop disabled
  running, // Start disabled, Stop enabled
  paused, // Resume enabled, Reset enabled
}

class _TimerHomePageState extends State<TimerHomePage> {
  // Use a single audio player for simplicity
  final AudioPlayer _audioPlayer = AudioPlayer();
  late List<int> intervals;
  late List<ChipLevel> chipLevels;
  int? currentInterval;
  Timer? _timer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  String message = "Press start to begin timer.";
  TimerState _timerState = TimerState.initial;
  int currentBlindIndex = 0;
  int currentIntervalIndex = 0; // Track current position in intervals list

  // Flag to control when timer end sound should play
  bool _shouldPlayTimerEndSound = true;

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
      message =
          "Blinds doubled! New big blind multiplier: ${newLevel.bigBlindMultiplier}";
    }
  }

  void _startTimer({bool playSounds = true}) {
    // Set volume for audio playback
    _audioPlayer.setVolume(widget.settingsService.getSettings().volume);

    // Don't play timer end sound when we're starting
    _shouldPlayTimerEndSound = false;

    // Only play sounds if explicitly requested (not during auto-restart)
    if (playSounds) {
      if (kIsWeb) {
        // For web, use JavaScript to create and play audio
        // This is a more direct approach that works better with web browsers
        js.context.callMethod('eval', [
          '''
        (function() {
          // Always prepare the timer end sound
          var endAudio = new Audio('assets/assets/audio/timer_end.mp3');
          console.log('Prepping timer end sound from:', 'assets/assets/audio/timer_end.mp3');
          endAudio.id = 'poker-timer-audio-end';
          endAudio.volume = ${widget.settingsService.getSettings().volume};
          document.body.appendChild(endAudio);
          
          // Play the game start sound
          var startAudio = new Audio('assets/assets/audio/game_begun.mp3');
          console.log('Playing game start sound from:', 'assets/assets/audio/game_begun.mp3');
          startAudio.id = 'poker-timer-audio-start';
          startAudio.volume = ${widget.settingsService.getSettings().volume};
          document.body.appendChild(startAudio);
          startAudio.play().catch(function(error) {
            console.error('Game start audio error:', error);
          });
        })();
        '''
        ]);
      } else {
        // For mobile platforms, use AssetSource directly
        _audioPlayer.stop();
        _audioPlayer.play(AssetSource('audio/game_begun.mp3'));
      }
    } else if (kIsWeb) {
      // Even when not playing sounds, still prepare the timer end sound for web
      js.context.callMethod('eval', [
        '''
      (function() {
        // Just prepare the timer end sound without playing anything
        var endAudio = new Audio('assets/assets/audio/timer_end.mp3');
        console.log('Silently prepping timer end sound');
        endAudio.id = 'poker-timer-audio-end';
        endAudio.volume = ${widget.settingsService.getSettings().volume};
        document.body.appendChild(endAudio);
      })();
      '''
      ]);
    }

    // Allow timer end sound to play after a delay
    Future.delayed(Duration(seconds: 2), () {
      _shouldPlayTimerEndSound = true;
    });

    // Store the current state before changing it
    final wasInPausedState = _timerState == TimerState.paused;

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
    if (wasInPausedState) {
      // We're resuming, keep the current interval and remaining seconds
      // No need to change currentInterval or _remainingSeconds
      // Just continue with the existing values
    } else if (currentInterval == null) {
      // Starting fresh, get the first interval
      if (intervals.isNotEmpty && currentIntervalIndex < intervals.length) {
        currentInterval = intervals[currentIntervalIndex];
        _remainingSeconds = currentInterval! * 60;
      } else {
        currentInterval = 10;
        _remainingSeconds = currentInterval! * 60;
      }
    } else {
      // Timer expired, move to next interval if not at the end
      if (currentIntervalIndex < intervals.length - 1) {
        currentIntervalIndex++; // Increment to the next interval
        currentInterval = intervals[currentIntervalIndex];
        _remainingSeconds = currentInterval! * 60;
      } else {
        // We've reached the last interval, stay on it and reset the time
        currentInterval = intervals[currentIntervalIndex];
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
        // Update volume in case it was changed in settings
        await _audioPlayer.setVolume(settings.volume);

        // Stop any current playback
        await _audioPlayer.stop();

        // For web, we need to use a different approach
        if (kIsWeb && _shouldPlayTimerEndSound) {
          try {
            // Use JavaScript to create and play audio directly
            // This is a more reliable approach for web browsers
            js.context.callMethod('eval', [
              '''
            (function() {
              // Look up the existing audio element by ID
              var audio = document.getElementById('poker-timer-audio-end');
              if (audio) {
                console.log('Playing timer end sound from existing element');
                audio.currentTime = 0; // Reset to beginning
                audio.volume = ${settings.volume};
                audio.play().catch(function(error) {
                  console.error('Timer end audio error:', error);
                });
              } else {
                console.error('Could not find timer end audio element');
              }
            })();
            '''
            ]);
          } catch (e) {
            print("Web audio playback error: $e");
            // Try the audioplayers approach as fallback
            try {
              await _audioPlayer.play(AssetSource('audio/timer_end.mp3'));
            } catch (fallbackError) {
              print("Fallback audio playback error: $fallbackError");
            }
          }
        } else {
          // For mobile platforms
          await _audioPlayer.play(AssetSource('audio/timer_end.mp3'));
        }
      } catch (e) {
        print("Error playing audio: $e");
      }
      setState(() {
        _updateBlinds();
        message = "$currentInterval minutes passed!";
        // Don't reset currentInterval to null anymore
        // Instead, handle the timer expiration here
        _startTimer(playSounds: false);
      });
    });

    setState(() {
      if (_timerState == TimerState.paused) {
        message =
            "Timer resumed with ${(_remainingSeconds / 60).floor()}:${(_remainingSeconds % 60).toString().padLeft(2, '0')} remaining.";
      } else {
        message = "Timer set for $currentInterval minutes.";
      }
    });
  }

  void _stopTimer() {
    // Stop the timer
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
        currentIntervalIndex = 0;
        _remainingSeconds = 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeAudio();
    currentIntervalIndex = 0; // Initialize interval index
  }

  void _initializeAudio() {
    try {
      // Set the volume based on settings
      final volume = widget.settingsService.getSettings().volume;
      _audioPlayer.setVolume(volume);
    } catch (e) {
      print("Error initializing audio: $e");
    }
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
    // Audio is initialized in initState

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
                          value: currentInterval != null
                              ? _remainingSeconds / (currentInterval! * 60)
                              : 0,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[700],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      Text(
                        currentInterval != null
                            ? '${(_remainingSeconds / 60).floor()}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}'
                            : '--:--',
                        style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 120,
                        child: Text('Small Blind',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2)
                                ]))),
                    SizedBox(
                        width: 120,
                        child: Text('Big Blind',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2)
                                ]))),
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
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
                  onPressed:
                      _timerState == TimerState.running ? null : () => _startTimer(playSounds: _timerState != TimerState.paused),
                  child: Text(
                      _timerState == TimerState.paused ? 'Resume' : 'Start'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed:
                      _timerState == TimerState.initial ? null : _stopTimer,
                  child:
                      Text(_timerState == TimerState.paused ? 'Reset' : 'Stop'),
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
