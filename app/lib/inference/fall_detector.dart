import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

class FallResult {
  final int triggeredStage;
  final double svmPeak;
  final double cnnProbability;
  final bool immobilityConfirmed;

  const FallResult({
    required this.triggeredStage,
    required this.svmPeak,
    required this.cnnProbability,
    required this.immobilityConfirmed,
  });

  bool get isFall => triggeredStage > 0;
}

enum DetectionMode { conservative, balanced, strict }

// balanced/strict lowered -0.05; altitude gate + still→motion blanking + debounce
// compensate the marginal FP increase while recall improves.
// Defaults — used when SQLite has no saved value (see DatabaseService settings table).
const Map<DetectionMode, double> defaultThresholds = {
  DetectionMode.conservative: 0.55, // 65+ segment: maximise recall
  DetectionMode.balanced: 0.70,
  DetectionMode.strict: 0.85,
};

class FallDetector {
  static const String _modelPath = 'assets/models/fall_model_int8.tflite';
  static const int windowSize = 100;
  static const int channels = 6;
  static const double defaultSvmThreshold = 3.0;
  static const double _immobilityStdThreshold = 0.1;
  static const int _immobilitySamples = 25;

  // Mutable, user-tunable thresholds (persisted in SQLite, defaults above).
  final Map<DetectionMode, double> cnnThresholds = Map.of(defaultThresholds);
  double svmThreshold = defaultSvmThreshold;

  void setCnnThreshold(DetectionMode m, double v) => cnnThresholds[m] = v;

  // Altitude gate (Stage 2.5) — calibrate in Sync 3.
  // If CNN fires but neither condition is met, escalation stops at stage 2 (no alert).
  // Null altitude values bypass the gate entirely (preserves recall on devices without sensor).
  static const double _altDeltaFallThresholdM = -0.30; // net drop in window, metres
  static const double _vertVelFallThresholdMs = -1.0; // m/s, negative = downward

  Interpreter? _interpreter;
  bool _loaded = false;

  DetectionMode mode;

  FallDetector({this.mode = DetectionMode.balanced});

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
  double get threshold => cnnThresholds[mode]!;

  // [altitudeDeltaM] : net altitude change (m) over the fall window, from AltitudeService.
  //                    Negative = person dropped. Null = no altitude data → gate bypassed.
  // [verticalVelocityMs]: signed vertical velocity (m/s) at moment of analysis.
  //                    Null = no altitude data.
  FallResult analyze(
    List<List<double>> window, {
    double? altitudeDeltaM,
    double? verticalVelocityMs,
  }) {
    // Stage 1: SVM peak — compare actual magnitude (g), not squared
    double svmPeakG = 0.0;
    for (final s in window) {
      final mag = sqrt(s[0] * s[0] + s[1] * s[1] + s[2] * s[2]);
      if (mag > svmPeakG) svmPeakG = mag;
    }

    if (svmPeakG < svmThreshold) {
      return FallResult(
          triggeredStage: 0,
          svmPeak: svmPeakG,
          cnnProbability: 0.0,
          immobilityConfirmed: false);
    }

    // Stage 2: CNN
    double cnnProb = 0.0;
    if (_loaded && _interpreter != null) {
      cnnProb = _runCnn(window);
    }

    if (cnnProb < threshold) {
      return FallResult(
          triggeredStage: 1,
          svmPeak: svmPeakG,
          cnnProbability: cnnProb,
          immobilityConfirmed: false);
    }

    // Stage 2.5: altitude gate — if altitude data available, require evidence of a drop.
    // A real fall drops altitude; a hard step while walking does not.
    // Both conditions are checked; either alone is sufficient to confirm fall altitude evidence.
    if (altitudeDeltaM != null && verticalVelocityMs != null) {
      final altDrop = altitudeDeltaM < _altDeltaFallThresholdM;
      final velDrop = verticalVelocityMs < _vertVelFallThresholdMs;
      if (!altDrop && !velDrop) {
        // CNN fired but no altitude evidence → stop at stage 2 (no alert dispatched)
        return FallResult(
            triggeredStage: 2,
            svmPeak: svmPeakG,
            cnnProbability: cnnProb,
            immobilityConfirmed: false);
      }
    }

    // Stage 3: immobility — std of SVM over last 0.5 s (matches Python: std(SVM[-25:]) < 0.1)
    final last = window.sublist(window.length - _immobilitySamples);
    final svms = last
        .map((s) => sqrt(s[0] * s[0] + s[1] * s[1] + s[2] * s[2]))
        .toList();
    final mean = svms.reduce((a, b) => a + b) / svms.length;
    final variance = svms
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        svms.length;
    final immobility = sqrt(variance) < _immobilityStdThreshold;

    return FallResult(
        triggeredStage: immobility ? 3 : 2,
        svmPeak: svmPeakG,
        cnnProbability: cnnProb,
        immobilityConfirmed: immobility);
  }

  double _runCnn(List<List<double>> window) {
    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    final inScale = inputTensor.params.scale;
    final inZp = inputTensor.params.zeroPoint;
    final outScale = outputTensor.params.scale;
    final outZp = outputTensor.params.zeroPoint;

    if (inScale == 0.0) {
      // Float model fallback
      final input = [window.map((s) => s.map((v) => v.toDouble()).toList()).toList()];
      final output = [[0.0]];
      _interpreter!.run(input, output);
      return output[0][0].clamp(0.0, 1.0);
    }

    // Quantize float → int8
    final input = [
      window.map((row) =>
        row.map((v) => (v / inScale + inZp).round().clamp(-128, 127)).toList()
      ).toList()
    ];

    final outputBuf = [[0]];
    _interpreter!.run(input, outputBuf);

    return ((outputBuf[0][0] - outZp) * outScale).clamp(0.0, 1.0);
  }

  void dispose() {
    _interpreter?.close();
  }
}
