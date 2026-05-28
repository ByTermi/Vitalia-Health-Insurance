import 'dart:io';
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

const _thresholds = {
  DetectionMode.conservative: 0.55,
  DetectionMode.balanced: 0.70,
  DetectionMode.strict: 0.85,
};

class FallDetector {
  static const String _modelPath = 'assets/models/fall_model_int8.tflite';
  static const int windowSize = 100;
  static const int channels = 6;
  static const double svmThreshold = 3.0;
  static const double _immobilityStdThreshold = 0.1;
  static const int _immobilitySamples = 25;

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
  double get threshold => _thresholds[mode]!;

  FallResult analyze(List<List<double>> window) {
    // Stage 1: SVM peak
    double svmPeakSq = 0.0;
    for (final s in window) {
      final sq = s[0] * s[0] + s[1] * s[1] + s[2] * s[2];
      if (sq > svmPeakSq) svmPeakSq = sq;
    }
    final svmPeakG = svmPeakSq < 0 ? 0.0 : svmPeakSq;

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

    // Stage 3: immobility
    final last = window.sublist(window.length - _immobilitySamples);
    double sumSq = 0.0;
    for (final s in last) {
      sumSq += s[0] * s[0] + s[1] * s[1] + s[2] * s[2];
    }
    final immobility = (sumSq / _immobilitySamples) < _immobilityStdThreshold;

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
      return (output[0][0] as double).clamp(0.0, 1.0);
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
