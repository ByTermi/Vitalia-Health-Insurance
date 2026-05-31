import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

// Order MUST match the training class order (notebook har-pamap-kaggle-inigo, 5 classes):
// [static, walking, running, upstairs, downstairs]
// sitting + standing are merged into static (index 0). Cycling was removed: PAMAP2
// ankle placement did not transfer to phone and the model hallucinated it over walking.
// The model outputs an index into this list; reordering breaks the mapping.
enum Activity {
  stationary, // index 0 — merged sitting + standing (0 VitaPoints)
  walking,    // index 1
  running,    // index 2
  upstairs,   // index 3
  downstairs, // index 4
}

const _activityNames = {
  Activity.stationary: 'Static',
  Activity.walking: 'Walking',
  Activity.running: 'Running',
  Activity.upstairs: 'Upstairs',
  Activity.downstairs: 'Downstairs',
};

const _vitaPointsPerMinute = {
  Activity.stationary: 0,
  Activity.walking: 2,
  Activity.running: 5,
  Activity.upstairs: 3,
  Activity.downstairs: 2,
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
  // Upstairs/walking/running always exceed 0.1 g mean; truly still → <0.03 g.
  static const double _staticSvmThreshold = 0.05;

  // Stairs altitude gate (J/Sync-3): the inertial model confuses flat walking with stairs
  // in pocket placement (LOSO: walking→downstairs ~29%, walking→upstairs ~11%).
  //
  // Barometer is noisy: on the test phone flat walking swings Δh ∈ [-1, +1] m (mean ~0),
  // while descending stairs holds Δh ~ -1.4 m. Instantaneous |Δh| is too jittery to gate on.
  // We average Δh over the last few windows: flat walking averages to ~0 (the ± swings cancel),
  // real stairs hold a sustained signed trend. Altitude is AUTHORITATIVE for stairs — a sustained
  // trend FORCES up/downstairs (the inertial model alone rarely predicts them); a flat trend
  // demotes any stairs prediction to walking.
  static const int defaultAltTrendWindows = 2;     // ~2.5 s — small for fast response
  static const double defaultStairsUpM = 0.7;      // |mean Δh| (m) to confirm a flight of stairs

  int altTrendWindows = defaultAltTrendWindows;
  double stairsConfirmUpM = defaultStairsUpM;       // trend ≥ this → upstairs
  double stairsConfirmDownM = -defaultStairsUpM;    // trend ≤ this → downstairs

  // Set both up/down thresholds from a single positive magnitude (slider-friendly).
  void setStairsThresholdMagnitude(double m) {
    stairsConfirmUpM = m;
    stairsConfirmDownM = -m;
  }

  final List<double> _recentAltDeltas = [];
  double _altTrend = 0.0;
  // Smoothed altitude trend (m) over the last altTrendWindows windows — exposed for debug UI.
  double get altitudeTrend => _altTrend;

  // Temporal smoothing: majority vote over the last N windows (see Sync 2 for N choice).
  // N=3 means ~3.84 s before a class change is accepted; prevents walking↔stairs flicker.
  static const int _smoothingN = 3;
  final List<Activity> _recentActivities = [];

  Interpreter? _interpreter;
  bool _loaded = false;

  Future<void> load({String? overridePath}) async {
    try {
      final options = InterpreterOptions()..threads = 2;
      if (overridePath != null) {
        _interpreter = await Interpreter.fromFile(
          File(overridePath),
          options: options,
        );
      } else {
        _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      }
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }

  bool get isLoaded => _loaded;

  // [altitudeDeltaM]: net altitude change (m) over the window, from AltitudeService.
  // When provided, enables the stairs gate (flat altitude → reclassify stairs as walking).
  // Pass null to disable the gate (e.g. offline test samples with no sensor context).
  HarResult? classify(List<List<double>> window, {double? altitudeDeltaM}) {
    if (!_loaded || _interpreter == null) return null;
    if (window.length != windowSize || window[0].length != channels) return null;

    // Compute mean linear-accel SVM over the window (channels 0-2 = gravity-removed accel).
    // When the phone is completely still Android's TYPE_LINEAR_ACCELERATION can drift
    // slightly, producing a near-zero but repetitive signal the CNN mis-reads as "upstairs".
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
    var rawActivity = Activity.values[maxIdx];
    final rawConfidence = probs[maxIdx];

    // Stairs altitude gate — altitude is authoritative for stairs (the inertial model rarely
    // predicts them in pocket placement). A sustained altitude trend FORCES up/downstairs; a
    // flat trend demotes any stairs prediction to walking. The static-SVM clamp keeps priority
    // (skip the gate when the phone is stationary so "still" never turns into stairs).
    if (altitudeDeltaM != null && meanSvm >= _staticSvmThreshold) {
      _recentAltDeltas.add(altitudeDeltaM);
      if (_recentAltDeltas.length > altTrendWindows) _recentAltDeltas.removeAt(0);
      _altTrend = _recentAltDeltas.reduce((a, b) => a + b) / _recentAltDeltas.length;

      if (_altTrend <= stairsConfirmDownM) {
        rawActivity = Activity.downstairs; // sustained descent
      } else if (_altTrend >= stairsConfirmUpM) {
        rawActivity = Activity.upstairs; // sustained climb
      } else if (rawActivity == Activity.upstairs ||
          rawActivity == Activity.downstairs) {
        rawActivity = Activity.walking; // flat ground → model's stairs guess was wrong
      }
    }

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
