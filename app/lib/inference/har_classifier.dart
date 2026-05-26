import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

// Order MUST match the training class order (notebook 03):
// [walking, upstairs, downstairs, sitting, standing, running].
// The model outputs an index into this list; reordering breaks the mapping.
enum Activity {
  walking,
  upstairs,
  downstairs,
  sitting,
  standing,
  running,
}

const _activityNames = {
  Activity.walking: 'Walking',
  Activity.upstairs: 'Upstairs',
  Activity.downstairs: 'Downstairs',
  Activity.sitting: 'Sitting',
  Activity.standing: 'Standing',
  Activity.running: 'Running',
};

const _vitaPointsPerMinute = {
  Activity.walking: 2,
  Activity.upstairs: 3,
  Activity.downstairs: 2,
  Activity.sitting: 0,
  Activity.standing: 0,
  Activity.running: 5,
};

extension ActivityInfo on Activity {
  String get displayName => _activityNames[this] ?? 'Unknown';
  int get vitaPointsPerMin => _vitaPointsPerMinute[this] ?? 0;
  // sitting/standing are the model's stationary classes (0 VitaPoints).
  bool get isActive => this != Activity.sitting && this != Activity.standing;
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

  Interpreter? _interpreter;
  bool _loaded = false;

  Future<void> load() async {
    try {
      final options = InterpreterOptions()..threads = 2;
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

    // Per-channel zero-mean/unit-std over the window, matching
    // normalize_subject() in training. Without this the model sees raw g
    // (idle phone ≈ 1g gravity offset) far outside its training distribution.
    final normalized = _standardize(window);

    // Input shape: [1, 128, 6]
    final input = [normalized];
    // Output shape: [1, 6]
    final output = [List<double>.filled(Activity.values.length, 0.0)];

    _interpreter!.run(input, output);

    final probs = output[0];
    final maxIdx = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    final activity = Activity.values[maxIdx];

    return HarResult(
      activity: activity,
      confidence: probs[maxIdx],
      vitaPointsPerMinute: _vitaPointsPerMinute[activity] ?? 0,
    );
  }

  List<List<double>> _standardize(List<List<double>> window) {
    final n = window.length;
    final means = List<double>.filled(channels, 0.0);
    final stds = List<double>.filled(channels, 0.0);

    for (final s in window) {
      for (var c = 0; c < channels; c++) {
        means[c] += s[c];
      }
    }
    for (var c = 0; c < channels; c++) {
      means[c] /= n;
    }

    for (final s in window) {
      for (var c = 0; c < channels; c++) {
        final d = s[c] - means[c];
        stds[c] += d * d;
      }
    }
    for (var c = 0; c < channels; c++) {
      stds[c] = sqrt(stds[c] / n) + 1e-8;
    }

    return window
        .map((s) => [
              for (var c = 0; c < channels; c++) (s[c] - means[c]) / stds[c]
            ])
        .toList();
  }

  void dispose() {
    _interpreter?.close();
  }
}
