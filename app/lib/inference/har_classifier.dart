import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

// Order MUST match the training class order (notebook 03_har_ut_pocket_kaggle):
// [stationary, walking, running, cycling, stairs]
// sitting + standing are merged into stationary (index 0);
// upstairs + downstairs are merged into stairs (index 4) — they are nearly
// indistinguishable from a single pocket accelerometer.
// The model outputs an index into this list; reordering breaks the mapping.
enum Activity {
  stationary, // index 0 — merged sitting + standing (0 VitaPoints)
  walking,    // index 1
  running,    // index 2
  cycling,    // index 3
  stairs,     // index 4 — merged upstairs + downstairs
}

const _activityNames = {
  Activity.stationary: 'Static',
  Activity.walking: 'Walking',
  Activity.running: 'Running',
  Activity.cycling: 'Cycling',
  Activity.stairs: 'Stairs',
};

const _vitaPointsPerMinute = {
  Activity.stationary: 0,
  Activity.walking: 2,
  Activity.running: 5,
  Activity.cycling: 4,
  Activity.stairs: 3,
};

extension ActivityInfo on Activity {
  String get displayName => _activityNames[this] ?? 'Unknown';
  int get vitaPointsPerMin => _vitaPointsPerMinute[this] ?? 0;
  bool get isActive => this != Activity.stationary;
}

class HarResult {
  final Activity activity;
  final double confidence;
  final int vitaPointsPerMinute;

  const HarResult({
    required this.activity,
    required this.confidence,
    required this.vitaPointsPerMinute,
  });

  String get activityName => _activityNames[activity] ?? 'Unknown';
}

class HarClassifier {
  static const String _modelPath = 'assets/models/har_model_int8.tflite';
  static const int windowSize = 128;
  static const int channels = 6;

  // Below this mean linear-accel SVM the phone is stationary.
  // Stairs/walking/running always exceed 0.1 g mean; truly still → <0.03 g.
  static const double _staticSvmThreshold = 0.05;

  // Temporal smoothing: majority vote over the last N windows (see Sync 2 for N choice).
  // N=3 means ~3.84 s before a class change is accepted; prevents walking↔stairs flicker.
  static const int _smoothingN = 3;
  final List<Activity> _recentActivities = [];

  Interpreter? _interpreter;
  bool _loaded = false;

  Future<void> load({String? overridePath}) async {
    final options = InterpreterOptions()..threads = 2;
    if (overridePath != null) {
      try {
        final candidate = await Interpreter.fromFile(File(overridePath), options: options);
        final outShape = candidate.getOutputTensor(0).shape;
        if (outShape.length >= 2 && outShape.last == Activity.values.length) {
          _interpreter = candidate;
          _loaded = true;
          return;
        }
        // Shape mismatch — discard stale OTA model, fall through to bundled asset.
        candidate.close();
      } catch (_) {}
    }
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }

  bool get isLoaded => _loaded;

  HarResult? classify(List<List<double>> window) {
    if (!_loaded || _interpreter == null) return null;
    if (window.length != windowSize || window[0].length != channels) return null;

    // Compute mean linear-accel SVM over the window (channels 0-2 = gravity-removed accel).
    // When the phone is completely still Android's TYPE_LINEAR_ACCELERATION can drift
    // slightly, producing a near-zero but repetitive signal the CNN mis-reads as "stairs".
    // Guard: if mean SVM < threshold the window is stationary → clamp to sitting/standing.
    double svmSum = 0.0;
    for (final sample in window) {
      final ax = sample[0], ay = sample[1], az = sample[2];
      svmSum += sqrt(ax * ax + ay * ay + az * az);
    }
    final meanSvm = svmSum / windowSize;

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    final inScale = inputTensor.params.scale;
    final inZp = inputTensor.params.zeroPoint;
    final outScale = outputTensor.params.scale;
    final outZp = outputTensor.params.zeroPoint;

    List<double> probs;

    if (inScale == 0.0) {
      // Float model fallback
      final input = [window];
      final output = [List<double>.filled(Activity.values.length, 0.0)];
      _interpreter!.run(input, output);
      probs = output[0];
    } else {
      // INT8: quantize input
      final input = [
        window.map((row) =>
          row.map((v) => (v / inScale + inZp).round().clamp(-128, 127)).toList()
        ).toList()
      ];
      final outputBuf = [List<int>.filled(Activity.values.length, 0)];
      _interpreter!.run(input, outputBuf);
      // Dequantize output
      probs = outputBuf[0].map((q) => (q - outZp) * outScale).toList();
    }

    final int maxIdx;
    if (meanSvm < _staticSvmThreshold) {
      // Phone is stationary — clamp to static (index 0)
      maxIdx = Activity.stationary.index;
    } else {
      maxIdx = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    }
    final rawActivity = Activity.values[maxIdx];
    final rawConfidence = probs[maxIdx];

    // Temporal smoothing: majority vote over last _smoothingN predictions.
    _recentActivities.add(rawActivity);
    if (_recentActivities.length > _smoothingN) _recentActivities.removeAt(0);

    final smoothed = _majorityVote(_recentActivities, rawActivity);
    final smoothedConf = _recentActivities
        .where((a) => a == smoothed)
        .fold(0.0, (sum, _) => sum + rawConfidence) /
        _recentActivities.where((a) => a == smoothed).length;

    return HarResult(
      activity: smoothed,
      confidence: smoothedConf,
      vitaPointsPerMinute: _vitaPointsPerMinute[smoothed] ?? 0,
    );
  }

  static Activity _majorityVote(List<Activity> recent, Activity fallback) {
    if (recent.isEmpty) return fallback;
    final counts = <Activity, int>{};
    for (final a in recent) {
      counts[a] = (counts[a] ?? 0) + 1;
    }
    Activity best = fallback;
    int bestCount = 0;
    counts.forEach((a, c) {
      if (c > bestCount) {
        bestCount = c;
        best = a;
      }
    });
    return best;
  }

  void dispose() {
    _interpreter?.close();
  }
}
