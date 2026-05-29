import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_service.dart';

// Provides vertical velocity and altitude delta for fall detection and stairs gate.
//
// Two paths:
//   Barometer (preferred): pressure → altitude via barometric formula. P0 calibrated
//     from first 20 readings at startup. hasBarometer flips true on first event.
//   Accel fallback: gravity direction estimated via heavy low-pass of raw accel;
//     linear accel projected onto that axis; samples stored for delta computation.
//     Integration drifts beyond ~3 s, so only use for short windows (≤ 128 samples).
//
// Thresholds used externally (calibrate in Sync 3):
//   Stairs gate  : |altitudeDeltaOverLastSamples(128)| < 0.25 m → flat (walking)
//   Fall gate    : altitudeDelta < -0.3 m OR verticalVelocityMs < -1.0 m/s → real fall
class AltitudeService {
  static const int _maxBufferSize = 300; // ~6 s at 50 Hz for accel, more for baro
  static const int _baroCalibSamples = 20;
  static const double _gravAlpha = 0.92; // low-pass coeff for gravity estimate

  // Barometer state
  bool _hasBarometer = false;
  bool get hasBarometer => _hasBarometer;

  double _p0 = 1013.25; // reference pressure (hPa); overwritten after calibration
  bool _p0Calibrated = false;
  int _calibCount = 0;
  double _calibSum = 0;
  final List<double> _altHistory = []; // metres above reference, baro-derived
  double _baroVertVel = 0; // m/s, estimated from baro altitude rate
  int _baroLastTimestampMs = 0;

  StreamSubscription? _baroSub;

  // Accel fallback state
  double _gx = 0, _gy = 0, _gz = -1; // gravity unit vector estimate (in g)
  bool _gravInitialized = false;
  final List<double> _vertAccelBuffer = []; // vertical linear accel, m/s²

  // Public API ---------------------------------------------------------------

  // Signed vertical velocity in m/s (+ = ascending, − = descending).
  // Uses baro rate if available, otherwise accel integration over last 25 samples.
  double get verticalVelocityMs {
    if (_hasBarometer) return _baroVertVel;
    return _integrateVelocity(25);
  }

  // Net altitude change in metres over the last [n] samples.
  //   Baro path : difference between oldest and newest altitude in the last n baro readings.
  //   Accel path: double-integration of the last n vertical accel samples with zero-velocity
  //               assumption at window start (suitable for ≤ 128 samples / 2.56 s).
  double altitudeDeltaOverLastSamples(int n) {
    if (_hasBarometer) {
      if (_altHistory.length < 2) return 0;
      final start = (_altHistory.length - n).clamp(0, _altHistory.length - 1);
      return _altHistory.last - _altHistory[start];
    } else {
      return _integrateDisplacement(n);
    }
  }

  // Feed each sensor sample from SensorService (needed for accel fallback).
  void addSample(SensorSample sample) {
    _updateGravity(sample);
    final vertMs2 = _projectVertical(sample);
    _vertAccelBuffer.add(vertMs2);
    if (_vertAccelBuffer.length > _maxBufferSize) _vertAccelBuffer.removeAt(0);
  }

  // Start barometer subscription if sensor is available.
  void start() {
    try {
      _baroSub = barometerEventStream().listen(
        _onBaro,
        onError: (_) {
          _hasBarometer = false;
          _baroSub?.cancel();
        },
        cancelOnError: true,
      );
      // hasBarometer stays false until first event arrives (_onBaro sets it)
    } catch (_) {
      _hasBarometer = false;
    }
  }

  void stop() {
    _baroSub?.cancel();
  }

  // Internal helpers ----------------------------------------------------------

  void _onBaro(BarometerEvent event) {
    _hasBarometer = true;
    final p = event.pressure; // hPa

    if (!_p0Calibrated) {
      _calibSum += p;
      _calibCount++;
      if (_calibCount >= _baroCalibSamples) {
        _p0 = _calibSum / _calibCount;
        _p0Calibrated = true;
      }
      return;
    }

    final h = _pressureToAltitude(p, _p0);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_altHistory.isNotEmpty && _baroLastTimestampMs > 0) {
      final dtS = (nowMs - _baroLastTimestampMs) / 1000.0;
      if (dtS > 0) _baroVertVel = (h - _altHistory.last) / dtS;
    }

    _baroLastTimestampMs = nowMs;
    _altHistory.add(h);
    if (_altHistory.length > _maxBufferSize) _altHistory.removeAt(0);
  }

  void _updateGravity(SensorSample s) {
    if (!_gravInitialized) {
      _gx = s.ax;
      _gy = s.ay;
      _gz = s.az;
      _gravInitialized = true;
    } else {
      _gx = _gravAlpha * _gx + (1 - _gravAlpha) * s.ax;
      _gy = _gravAlpha * _gy + (1 - _gravAlpha) * s.ay;
      _gz = _gravAlpha * _gz + (1 - _gravAlpha) * s.az;
    }
  }

  double _projectVertical(SensorSample s) {
    final gMag = sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    if (gMag < 0.1) return 0;
    final gnx = _gx / gMag, gny = _gy / gMag, gnz = _gz / gMag;
    // Dot product of linear accel (gravity-removed, g) onto gravity unit vector
    final vertG = s.lax * gnx + s.lay * gny + s.laz * gnz;
    return vertG * 9.81; // convert g → m/s²
  }

  double _integrateVelocity(int n) {
    if (_vertAccelBuffer.length < 2) return 0;
    final window = _vertAccelBuffer.sublist(
      (_vertAccelBuffer.length - n).clamp(0, _vertAccelBuffer.length),
    );
    const dt = 1.0 / 50;
    double vel = 0;
    for (final a in window) {
      vel += a * dt;
    }
    return vel;
  }

  double _integrateDisplacement(int n) {
    if (_vertAccelBuffer.length < 2) return 0;
    final window = _vertAccelBuffer.sublist(
      (_vertAccelBuffer.length - n).clamp(0, _vertAccelBuffer.length),
    );
    const dt = 1.0 / 50;
    double vel = 0, disp = 0;
    for (final a in window) {
      vel += a * dt;
      disp += vel * dt;
    }
    return disp;
  }

  static double _pressureToAltitude(double p, double p0) {
    return 44330.0 * (1.0 - pow(p / p0, 0.190263).toDouble());
  }
}
