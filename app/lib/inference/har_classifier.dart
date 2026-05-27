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

    // Window is gravity-removed accel (g) + gyro (rad/s), matching the
    // UCI body_acc the model trained on. No per-window standardization:
    // on a flat/idle window unit-std amplifies sensor noise into fake motion.

    // Input shape: [1, 128, 6]
    final input = [window];
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

  void dispose() {
    _interpreter?.close();
  }
}
