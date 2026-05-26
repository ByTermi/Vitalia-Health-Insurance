import 'package:tflite_flutter/tflite_flutter.dart';

enum Activity {
  walking,
  running,
  cycling,
  upstairs,
  downstairs,
  stationary,
}

const _activityNames = {
  Activity.walking: 'Walking',
  Activity.running: 'Running',
  Activity.cycling: 'Cycling',
  Activity.upstairs: 'Upstairs',
  Activity.downstairs: 'Downstairs',
  Activity.stationary: 'Stationary',
};

const _vitaPointsPerMinute = {
  Activity.walking: 2,
  Activity.running: 5,
  Activity.cycling: 4,
  Activity.upstairs: 3,
  Activity.downstairs: 2,
  Activity.stationary: 0,
};

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

    // Input shape: [1, 128, 6]
    final input = [window.map((s) => s.map((v) => v.toDouble()).toList()).toList()];
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
