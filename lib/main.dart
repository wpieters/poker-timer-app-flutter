import 'package:flutter/material.dart';
import 'dart:async';

import 'package:poker_timer/blindcolors.dart';

void main() => runApp(TimerApp());

class TimerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interval Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TimerHomePage(),
    );
  }
}

class TimerHomePage extends StatefulWidget {
  @override
  _TimerHomePageState createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage> {
  List<int> intervals = [45, 45, 30, 30, 15, 15];
  int? currentInterval;
  Timer? _timer;
  String message = "Press start to begin timer.";
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

    if (intervals.isNotEmpty) {
      currentInterval = intervals.removeAt(0);
    } else {
      currentInterval = 10;
    }

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
    setState(() {
      message = "Timer stopped.";
      intervals = [45, 45, 30, 30, 15, 15];
    });
  }

  @override
  Widget build(BuildContext context) {
    BlindColors currentBlinds = blindColorsList[currentBlindIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Poker Blinds Timer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildBlindIcon(currentBlinds.smallBlind, currentBlinds.getSmallCount()), // Small blind icon
                buildBlindIcon(currentBlinds.bigBlind, currentBlinds.getBigCount()), // Big blind icon
              ],
            ),
            Text(
              message,
              style: const TextStyle(fontSize: 20.0),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: _startTimer,
              child: const Text("Start"),
            ),
            const SizedBox(height: 10.0),
            ElevatedButton(
              onPressed: _stopTimer,
              child: const Text("Stop"),
            )
          ],
        ),
      ),
      backgroundColor: Colors.grey,
    );
  }
}
