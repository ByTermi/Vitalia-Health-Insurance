import 'dart:io';
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

  // Below this mean linear-accel SVM the phone is stationary.
  // Upstairs/walking/running always exceed 0.1 g mean; truly still → <0.03 g.
  static const double _staticSvmThreshold = 0.05;

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

  HarResult? classify(List<List<double>> window) {
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
      // Phone is stationary — restrict to sitting (3) or standing (4)
      final si = Activity.sitting.index;
      final sti = Activity.standing.index;
      maxIdx = probs[si] >= probs[sti] ? si : sti;
    } else {
      maxIdx = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    }
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
