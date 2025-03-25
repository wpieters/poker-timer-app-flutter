import 'package:flutter/material.dart';
import 'dart:async';

import 'package:poker_timer/blindcolors.dart';
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
  late List<int> intervals;
  int? currentInterval;
  Timer? _timer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  String message = "Press start to begin timer.";
  TimerState _timerState = TimerState.initial;
  List<BlindColors> blindColorsList = [
    BlindColors(smallBlind: Colors.blue, bigBlind: Colors.white, bigCount: 1),
    BlindColors(smallBlind: Colors.white, bigBlind: Colors.black, bigCount: 1),
    BlindColors(smallBlind: Colors.black, bigBlind: Colors.red, bigCount: 1),
    BlindColors(smallBlind: Colors.red, bigBlind: Colors.green, bigCount: 1),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 2),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 4),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 8),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 16),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 32),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 64),
    BlindColors(smallBlind: Colors.green, bigBlind: Colors.green, bigCount: 128), // we should never realistically reach this
  ];
  int currentBlindIndex = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateBlinds() {
    if (currentBlindIndex < blindColorsList.length - 1) {
      currentBlindIndex++;
    } else {
      currentBlindIndex = 0;
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

    if (intervals.isNotEmpty) {
      currentInterval = intervals.removeAt(0);
    } else {
      currentInterval = 10;
    }

    _remainingSeconds = currentInterval! * 60;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
      });
    });

    _timer = Timer(Duration(minutes: currentInterval!), () {
      setState(() {
        _updateBlinds();
        message = "$currentInterval minutes passed!";
        _startTimer();
      });
    });

    setState(() {
      message = "Timer set for $currentInterval minutes.";
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
  }

  void _loadSettings() {
    final settings = widget.settingsService.getSettings();
    setState(() {
      intervals = List.from(settings.intervals);
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
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    BlindColors currentBlinds = blindColorsList[currentBlindIndex];

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
                    buildBlindIcon(currentBlinds.smallBlind, currentBlinds.getSmallCount()), // Small blind icon
                    buildBlindIcon(currentBlinds.bigBlind, currentBlinds.getBigCount()), // Big blind icon
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
