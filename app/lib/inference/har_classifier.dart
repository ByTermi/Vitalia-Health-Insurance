import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Activity classes matching the 6-class HAR model output.
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

/// VitaPoints per minute for each activity (business logic).
const _vitaPointsPerMinute = {
  Activity.walking: 2,
  Activity.running: 5,
  Activity.cycling: 4,
  Activity.upstairs: 3,
  Activity.downstairs: 2,
  Activity.stationary: 0,
};

/// Result of a single HAR inference pass.
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

/// Loads and runs the HAR TFLite INT8 model.
///
/// Input tensor: [1, 128, 6] INT8
/// Output tensor: [1, 6] INT8 — softmax probabilities (quantized)
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
    } catch (e) {
      // Model not yet available (waiting for Íñigo — Day 5)
      _loaded = false;
    }
  }

  bool get isLoaded => _loaded;

  /// Run inference on a [windowSize × channels] window.
  /// [window] is a flat list of windowSize * channels float32 values.
  HarResult? classify(List<List<double>> window) {
    if (!_loaded || _interpreter == null) return null;
    if (window.length != windowSize || window[0].length != channels) return null;

    // Prepare INT8 input
    final inputDetails = _interpreter!.getInputTensor(0);
    final outputDetails = _interpreter!.getOutputTensor(0);

    final inputScale = inputDetails.params.scale;
    final inputZeroPoint = inputDetails.params.zeroPoint;
    final outputScale = outputDetails.params.scale;
    final outputZeroPoint = outputDetails.params.zeroPoint;

    // Quantize input: float32 → int8
    final input = List.generate(
      windowSize,
      (i) => List.generate(
        channels,
        (j) => (window[i][j] / inputScale + inputZeroPoint)
            .round()
            .clamp(-128, 127),
      ),
    );

    final output = List.filled(Activity.values.length, 0).reshape([1, Activity.values.length]);

    _interpreter!.run([input], output);

    // Dequantize output
    final probs = List.generate(
      Activity.values.length,
      (i) => (output[0][i] - outputZeroPoint) * outputScale,
    );

    final maxIdx = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    final activity = Activity.values[maxIdx];

    return HarResult(
      activity: activity,
      confidence: probs[maxIdx].toDouble(),
      vitaPointsPerMinute: _vitaPointsPerMinute[activity] ?? 0,
    );
  }

  void dispose() {
    _interpreter?.close();
  }
}
