import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../sensors/sensor_service.dart';

/// Result of a fall detection cycle.
class FallResult {
  /// Stage that triggered (1, 2, or 3). 0 = no fall.
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

/// Operating mode — configures the CNN decision threshold.
///
/// Conservative: for 65+ segment — recall ≥ 0.95, accepts more false positives.
/// Balanced: F1-optimal — default for general population.
/// Strict: precision ≥ 0.90 — for young users who find false alarms annoying.
enum DetectionMode { conservative, balanced, strict }

const _thresholds = {
  DetectionMode.conservative: 0.30,
  DetectionMode.balanced: 0.50,
  DetectionMode.strict: 0.70,
};

/// 3-stage fall detection cascade (on-device).
///
/// Stage 1: SVM threshold — always-on, < 1 mW.
/// Stage 2: CNN confirmer — activated only on SVM peak.
/// Stage 3: Post-fall immobility check (30 s window).
class FallDetector {
  static const String _modelPath = 'assets/models/fall_model_int8.tflite';
  static const int windowSize = 100; // 2 s @ 50 Hz
  static const int channels = 6;
  static const double svmThreshold = 3.0; // g — Stage 1 gate

  // Post-fall immobility: 0.5 s (25 samples) of near-zero motion
  static const double _immobilityStdThreshold = 0.1;
  static const int _immobilitySamples = 25;

  Interpreter? _interpreter;
  bool _loaded = false;

  DetectionMode mode;

  FallDetector({this.mode = DetectionMode.balanced});

  Future<void> load() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      _loaded = true;
    } catch (e) {
      _loaded = false;
    }
  }

  bool get isLoaded => _loaded;
  double get threshold => _thresholds[mode]!;

  /// Run the 3-stage cascade on a completed window.
  ///
  /// [window]: windowSize × channels float values.
  FallResult analyze(List<List<double>> window) {
    // Stage 1: SVM peak check
    double svmPeak = 0.0;
    for (final sample in window) {
      final svm = (sample[0] * sample[0] +
          sample[1] * sample[1] +
          sample[2] * sample[2]);
      if (svm > svmPeak) svmPeak = svm;
    }
    svmPeak = svmPeak.abs(); // already in g²; take sqrt for g units
    final svmPeakG = svmPeak < 0 ? 0.0 : svmPeak;

    if (svmPeakG < svmThreshold) {
      return FallResult(
        triggeredStage: 0,
        svmPeak: svmPeakG,
        cnnProbability: 0.0,
        immobilityConfirmed: false,
      );
    }

    // Stage 2: CNN inference
    double cnnProb = 0.0;
    if (_loaded && _interpreter != null) {
      cnnProb = _runCnn(window);
    }

    if (cnnProb < threshold) {
      return FallResult(
        triggeredStage: 1, // SVM fired but CNN didn't confirm
        svmPeak: svmPeakG,
        cnnProbability: cnnProb,
        immobilityConfirmed: false,
      );
    }

    // Stage 3: post-fall immobility
    final lastSamples = window.sublist(window.length - _immobilitySamples);
    double sumSq = 0.0;
    for (final s in lastSamples) {
      sumSq += s[0] * s[0] + s[1] * s[1] + s[2] * s[2];
    }
    final postStd = (sumSq / _immobilitySamples);
    final immobility = postStd < _immobilityStdThreshold;

    return FallResult(
      triggeredStage: immobility ? 3 : 2,
      svmPeak: svmPeakG,
      cnnProbability: cnnProb,
      immobilityConfirmed: immobility,
    );
  }

  double _runCnn(List<List<double>> window) {
    final inputDetails = _interpreter!.getInputTensor(0);
    final outputDetails = _interpreter!.getOutputTensor(0);

    final inputScale = inputDetails.params.scale;
    final inputZeroPoint = inputDetails.params.zeroPoint;
    final outputScale = outputDetails.params.scale;
    final outputZeroPoint = outputDetails.params.zeroPoint;

    final input = List.generate(
      windowSize,
      (i) => List.generate(
        channels,
        (j) => (window[i][j] / inputScale + inputZeroPoint)
            .round()
            .clamp(-128, 127),
      ),
    );

    final output = [[0]];
    _interpreter!.run([input], output);

    return ((output[0][0] as int) - outputZeroPoint) * outputScale;
  }

  void dispose() {
    _interpreter?.close();
  }
}
