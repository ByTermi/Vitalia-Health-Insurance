import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../sensors/sensor_service.dart';
import '../sensors/altitude_service.dart';
import '../inference/har_classifier.dart';
import '../inference/fall_detector.dart';
import '../services/api_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _sensorService = SensorService();
  final _altitudeService = AltitudeService();
  final _harBuffer = SlidingWindowBuffer(
      windowSize: 128, overlap: 0.5, rowMapper: (s) => s.toListLinear());
  final _fallBuffer = SlidingWindowBuffer(windowSize: 100, overlap: 0.5);
  final _harClassifier = HarClassifier();
  final _fallDetector = FallDetector(mode: DetectionMode.balanced);

  StreamSubscription? _sensorSub;

  // UI state
  Activity? _currentActivity;
  double _currentConfidence = 0.0;
  int _vitaPoints = 0;
  int _activeMinutes = 0;
  bool _fallAlert = false;
  double _lastSvmPeak = 0.0;

  DateTime? _activityStartTime;
  Timer? _pointsTimer;

  // Debounce: minimum gap between consecutive fall alerts (J-3).
  DateTime? _lastFallAlertTime;
  static const _fallCooldown = Duration(seconds: 15);

  bool _modelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _harClassifier.load();
    await _fallDetector.load();
    setState(() => _modelsLoaded = true);
    _startSensors();
  }

  void _startSensors() {
    _altitudeService.start();
    _sensorService.start();
    _sensorSub = _sensorService.sampleStream.listen(_onSample);

    // Award VitaPoints every minute of active movement
    _pointsTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_currentActivity != null && _currentActivity!.isActive) {
        setState(() {
          _vitaPoints += _currentActivity!.vitaPointsPerMin;
          _activeMinutes++;
        });
      }
    });
  }

  void _onSample(SensorSample sample) {
    _altitudeService.addSample(sample);

    // HAR window
    final harWindow = _harBuffer.addSample(sample);
    if (harWindow != null && _harClassifier.isLoaded) {
      final result = _harClassifier.classify(harWindow);
      if (result != null) {
        setState(() {
          _currentActivity = result.activity;
          _currentConfidence = result.confidence;
        });
      }
    }

    // Fall detection window — pass altitude evidence (J-2).
    // AltitudeService uses barometer when available, accel fallback otherwise.
    // Accel integration is reliable for the short 2 s fall window.
    final fallWindow = _fallBuffer.addSample(sample);
    if (fallWindow != null) {
      final fallResult = _fallDetector.analyze(
        fallWindow,
        altitudeDeltaM: _altitudeService.altitudeDeltaOverLastSamples(100),
        verticalVelocityMs: _altitudeService.verticalVelocityMs,
      );
      setState(() => _lastSvmPeak = fallResult.svmPeak);

      // Debounce: suppress re-trigger within cooldown window (J-3).
      if (fallResult.isFall && fallResult.triggeredStage >= 2) {
        final now = DateTime.now();
        if (_lastFallAlertTime == null ||
            now.difference(_lastFallAlertTime!) > _fallCooldown) {
          _lastFallAlertTime = now;
          unawaited(_triggerFallAlert(fallResult));
        }
      }
    }
  }

  Future<void> _triggerFallAlert(FallResult result) async {
    setState(() => _fallAlert = true);

    // Post fall event to backend — worker will alert if not ACKed in 30 s
    final fallId = await ApiService.instance.postFall(
      stage: result.triggeredStage,
      svmPeak: result.svmPeak,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade700,
        title: const Text('¿Estás bien?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Hemos detectado una posible caída.\n'
          'Probabilidad: ${(result.cnnProbability * 100).toStringAsFixed(0)}%\n\n'
          'Si estás bien, pulsa "Estoy bien".\n'
          'Si no respondes en 30 s, contactaremos a emergencias.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _fallAlert = false);
              if (fallId != null) ApiService.instance.ackFall(fallId);
            },
            child: const Text('Estoy bien'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _fallAlert = false);
              // No ACK → worker sends ntfy + email after 30 s
            },
            child: const Text('Llamar a emergencias'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _altitudeService.stop();
    _sensorService.dispose();
    _harClassifier.dispose();
    _fallDetector.dispose();
    _pointsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('Vitalia HAR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (!_modelsLoaded)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActivityCard(),
            const SizedBox(height: 20),
            _buildVitaPointsCard(),
            const SizedBox(height: 20),
            _buildFallStatusCard(),
            const SizedBox(height: 20),
            _buildDebugCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    final activityIcons = {
      Activity.walking: Icons.directions_walk,
      Activity.upstairs: Icons.stairs,
      Activity.downstairs: Icons.stairs_outlined,
      Activity.sitting: Icons.chair,
      Activity.standing: Icons.accessibility_new,
      Activity.running: Icons.directions_run,
    };
    final icon = activityIcons[_currentActivity] ?? Icons.device_unknown;
    final name = _currentActivity?.displayName ?? 'Detecting…';

    return Card(
      color: const Color(0xFF1A2D4A),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.greenAccent),
            const SizedBox(height: 12),
            Text(
              _modelsLoaded ? name : 'Loading model…',
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (_currentActivity != null)
              Text(
                'Confidence: ${(_currentConfidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitaPointsCard() {
    return Card(
      color: const Color(0xFF1A2D4A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('VitaPoints', _vitaPoints.toString(), Icons.star, Colors.amber),
            _statItem('Active min', _activeMinutes.toString(), Icons.timer, Colors.greenAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildFallStatusCard() {
    return Card(
      color: _fallAlert ? Colors.red.shade800 : const Color(0xFF1A2D4A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _fallAlert ? Icons.warning_amber_rounded : Icons.shield_outlined,
              color: _fallAlert ? Colors.amber : Colors.greenAccent,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fallAlert ? 'Fall Detected!' : 'Fall Monitor Active',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  Text(
                    'Mode: ${_fallDetector.mode.name}  |  '
                    'Threshold: ${_fallDetector.threshold}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugCard() {
    return Card(
      color: const Color(0xFF0D1F35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11)),
            Text(
              'HAR model: ${_harClassifier.isLoaded ? "loaded" : "not available"}\n'
              'Fall model: ${_fallDetector.isLoaded ? "loaded" : "not available"}\n'
              'Last SVM peak: ${_lastSvmPeak.toStringAsFixed(2)} g\n'
              'Altitude sensor: ${_altitudeService.hasBarometer ? "barometer" : "accel fallback"}\n'
              'Vert vel: ${_altitudeService.verticalVelocityMs.toStringAsFixed(2)} m/s  '
              'Δh(2s): ${_altitudeService.altitudeDeltaOverLastSamples(100).toStringAsFixed(2)} m',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }
}
