import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// 6-axis sensor sample in g + rad/s.
/// ax/ay/az: raw accelerometer (gravity included), in g — used by fall SVM/chart.
/// lax/lay/laz: linear accelerometer (gravity removed), in g — used by HAR.
/// gx/gy/gz: gyroscope, rad/s.
class SensorSample {
  final double ax, ay, az;
  final double lax, lay, laz;
  final double gx, gy, gz;
  final DateTime timestamp;

  const SensorSample({
    required this.ax,
    required this.ay,
    required this.az,
    required this.lax,
    required this.lay,
    required this.laz,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.timestamp,
  });

  /// Row for fall detector: raw accel (gravity) + gyro. Resting SVM ≈ 1 g.
  List<double> toList() => [ax, ay, az, gx, gy, gz];

  /// Row for HAR: gravity-removed accel + gyro, matching UCI body_acc /
  /// MotionSense userAcceleration the model trained on.
  List<double> toListLinear() => [lax, lay, laz, gx, gy, gz];

  /// SVM = √(ax² + ay² + az²) in g — resting value ≈ 1 g (gravity)
  double get svm => sqrt(ax * ax + ay * ay + az * az);

  double get svmG => svm;
}

/// Streams fused accelerometer + gyroscope samples at ~50 Hz.
///
/// sensors_plus provides separate streams; we merge them by time proximity.
/// The target rate of 50 Hz (20 ms interval) matches the model training data.
class SensorService {
  static const int targetHz = 50;
  static const Duration _sampleInterval = Duration(milliseconds: 20);

  final _controller = StreamController<SensorSample>.broadcast();
  Stream<SensorSample> get sampleStream => _controller.stream;

  StreamSubscription? _accelSub;
  StreamSubscription? _userAccelSub;
  StreamSubscription? _gyroSub;
  Timer? _timer;

  // Latest raw readings (g / rad/s)
  double _ax = 0, _ay = 0, _az = 0;
  double _lax = 0, _lay = 0, _laz = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;

    // Raw accelerometer — includes gravity (fall SVM, chart).
    _accelSub = accelerometerEventStream().listen((e) {
      _ax = e.x / 9.81; // convert to g
      _ay = e.y / 9.81;
      _az = e.z / 9.81;
    });

    // Linear accelerometer — gravity removed (HAR input).
    _userAccelSub = userAccelerometerEventStream().listen((e) {
      _lax = e.x / 9.81;
      _lay = e.y / 9.81;
      _laz = e.z / 9.81;
    });

    _gyroSub = gyroscopeEventStream().listen((e) {
      _gx = e.x;
      _gy = e.y;
      _gz = e.z;
    });

    // Emit at fixed 50 Hz rate
    _timer = Timer.periodic(_sampleInterval, (_) {
      if (!_controller.isClosed) {
        _controller.add(SensorSample(
          ax: _ax, ay: _ay, az: _az,
          lax: _lax, lay: _lay, laz: _laz,
          gx: _gx, gy: _gy, gz: _gz,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _accelSub?.cancel();
    _userAccelSub?.cancel();
    _gyroSub?.cancel();
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

/// Circular buffer that accumulates sensor samples into fixed-size windows.
class SlidingWindowBuffer {
  final int windowSize;
  final int stepSize; // windowSize * (1 - overlap)
  // How each sample becomes a feature row. HAR uses gravity-removed accel
  // (toListLinear); fall detection uses raw accel (toList).
  final List<double> Function(SensorSample) rowMapper;
  final _buffer = <SensorSample>[];

  SlidingWindowBuffer({
    required this.windowSize,
    double overlap = 0.5,
    List<double> Function(SensorSample)? rowMapper,
  })  : stepSize = (windowSize * (1.0 - overlap)).round(),
        rowMapper = rowMapper ?? ((s) => s.toList());

  int _samplesSinceLastWindow = 0;

  /// Add a sample. Returns a completed window if the step size has elapsed,
  /// otherwise returns null.
  List<List<double>>? addSample(SensorSample sample) {
    _buffer.add(sample);
    if (_buffer.length > windowSize * 3) {
      // Keep only what we need to avoid unbounded growth
      _buffer.removeRange(0, _buffer.length - windowSize * 2);
    }

    _samplesSinceLastWindow++;
    if (_buffer.length >= windowSize && _samplesSinceLastWindow >= stepSize) {
      _samplesSinceLastWindow = 0;
      final start = _buffer.length - windowSize;
      return _buffer
          .sublist(start)
          .map(rowMapper)
          .toList();
    }
    return null;
  }

  /// Returns true if max SVM in last [windowSize] samples exceeds threshold_g.
  /// Used by Stage 1 of the fall detection cascade (always-on, cheap).
  bool hasSvmPeak(double thresholdG) {
    if (_buffer.length < windowSize) return false;
    final recent = _buffer.sublist(_buffer.length - windowSize);
    return recent.any((s) => s.svmG > thresholdG);
  }
}
