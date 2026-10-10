import 'dart:async';

import 'package:flutter/material.dart';

import 'models/tournament_timer.dart';
import 'pages/settings_page.dart';
import 'services/alert_audio.dart';
import 'services/settings_service.dart';
import 'services/wake_lock_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SettingsService.create();
  runApp(TimerApp(settingsService: settingsService));
}

class TimerApp extends StatelessWidget {
  const TimerApp({super.key, required this.settingsService});
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Poker Timer',
    theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
    home: TimerHomePage(settingsService: settingsService),
  );
}

class TimerHomePage extends StatefulWidget {
  const TimerHomePage({
    super.key,
    required this.settingsService,
    this.wakeLockService,
    this.audio,
    this.now,
  });
  final SettingsService settingsService;
  final WakeLockService? wakeLockService;
  final AlertAudio? audio;
  final DateTime Function()? now;

  @override
  State<TimerHomePage> createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage>
    with WidgetsBindingObserver {
  late TournamentTimer _game;
  late final WakeLockService _wakeLock;
  late final AlertAudio _audio;
  Timer? _refresh;
  bool _visible = true;
  bool _soundNeedsActivation = false;
  String message = 'Press start to begin timer.';
  int _remainingSeconds = 0;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  TimerState get _timerState => _game.state;
  int? get currentInterval =>
      _timerState == TimerState.initial ? null : _game.intervalMinutes;
  double get _volume => widget.settingsService.getSettings().volume;

  @override
  void initState() {
    super.initState();
    _wakeLock = widget.wakeLockService ?? WakeLockService();
    _audio = widget.audio ?? AlertAudio();
    _game =
        widget.settingsService.restoreTimer() ??
        TournamentTimer(widget.settingsService.getSettings());
    if (_game.state != TimerState.initial) {
      _game.synchronize(_now);
      _remainingSeconds = _game.remainingSeconds(_now);
      _soundNeedsActivation = true;
      message = 'Tournament restored. Level ${_game.levelIndex + 1}.';
      _save();
    }
    WidgetsBinding.instance.addObserver(this);
    _wakeLock.addListener(_wakeLockChanged);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _visible =
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.detached;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_wakeLock.setVisible(_visible));
    });
    _refresh = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tick(),
    );
  }

  void _wakeLockChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _visible = true;
      unawaited(_wakeLock.setVisible(true));
      _tick();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _visible = false;
      unawaited(_wakeLock.setVisible(false));
      _save();
    }
  }

  void _tick() {
    if (!mounted || !_visible || _timerState != TimerState.running) return;
    final now = _now;
    final completed = _game.synchronize(now);
    final remaining = _game.remainingSeconds(now);
    if (remaining != _remainingSeconds || completed > 0) {
      setState(() {
        _remainingSeconds = remaining;
        if (completed > 0) {
          message = 'Blinds increased. Level ${_game.levelIndex + 1}.';
        }
      });
    }
    if (completed > 0) {
      _save();
      // One alert for the current level, even if several elapsed while hidden.
      unawaited(_playCompletion());
    }
  }

  Future<void> _playCompletion() async {
    try {
      await _audio.complete(_volume);
    } catch (error) {
      debugPrint('Timer alert unavailable: $error');
      if (mounted) setState(() => _soundNeedsActivation = true);
    }
  }

  Future<void> _activateSound({bool announce = false}) async {
    try {
      await _audio.activate(_volume, announce: announce);
      if (mounted) setState(() => _soundNeedsActivation = false);
    } catch (error) {
      debugPrint('Sound activation failed: $error');
      if (mounted) setState(() => _soundNeedsActivation = true);
    }
  }

  void _startTimer({bool playSounds = true}) {
    // Audio activation and wake lock requests begin inside the button gesture.
    unawaited(_activateSound(announce: playSounds));
    unawaited(_wakeLock.retry());
    final wasPaused = _timerState == TimerState.paused;
    _game.start(_now);
    setState(() {
      _remainingSeconds = _game.remainingSeconds(_now);
      message = wasPaused
          ? 'Timer resumed.'
          : 'Timer set for $currentInterval minutes.';
    });
    _save();
  }

  void _stopTimer() {
    final now = _now;
    setState(() {
      if (_timerState == TimerState.running) {
        _game.pause(now);
        _remainingSeconds = _game.remainingSeconds(now);
        message = 'Timer paused.';
      } else {
        _game = TournamentTimer(widget.settingsService.getSettings());
        _remainingSeconds = 0;
        message = 'Timer reset.';
      }
    });
    _save();
  }

  void _save() {
    unawaited(
      widget.settingsService.saveTimer(_game).catchError((Object error) {
        debugPrint('Could not save tournament: $error');
      }),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          settingsService: widget.settingsService,
          onSettingsChanged: (_) {
            if (_timerState == TimerState.initial) {
              setState(
                () => _game = TournamentTimer(
                  widget.settingsService.getSettings(),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatus() => Column(
    children: [
      if (_wakeLock.status == WakeLockStatus.active)
        const Text('Screen stays awake while this app is visible.')
      else if (_wakeLock.status == WakeLockStatus.unavailable) ...[
        const Text(
          'Could not keep the screen awake. Check battery saver or screen-lock settings.',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: _wakeLock.retry,
          child: const Text('Retry keeping screen awake'),
        ),
      ] else
        const Text('Requesting screen wake lock…'),
      if (_soundNeedsActivation && _volume > 0)
        TextButton(
          onPressed: () => _activateSound(announce: true),
          child: const Text('Enable sound'),
        ),
    ],
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _wakeLock.removeListener(_wakeLockChanged);
    _wakeLock.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _game.currentLevel;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildStatus(),
              const SizedBox(height: 12),
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        ),
                        Text(
                          currentInterval != null
                              ? '${(_remainingSeconds / 60).floor()}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}'
                              : '--:--',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
                        child: Text(
                          'Small Blind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Big Blind',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
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
                                  fontWeight: FontWeight.bold,
                                ),
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
                                  fontWeight: FontWeight.bold,
                                ),
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
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20.0),
              ),
              const SizedBox(height: 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _timerState == TimerState.running
                        ? null
                        : () => _startTimer(
                            playSounds: _timerState != TimerState.paused,
                          ),
                    child: Text(
                      _timerState == TimerState.paused ? 'Resume' : 'Start',
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _timerState == TimerState.initial
                        ? null
                        : _stopTimer,
                    child: Text(
                      _timerState == TimerState.paused ? 'Reset' : 'Pause',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.grey,
    );
  }
}
