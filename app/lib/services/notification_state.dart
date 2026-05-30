import 'dart:async';
import '../inference/fall_detector.dart';

/// Non-null when app was cold-started by tapping a fall notification.
FallNotificationPayload? initialFallPayload;

final _controller = StreamController<FallNotificationPayload>.broadcast();

/// Stream for notification taps while the app is already alive.
Stream<FallNotificationPayload> get fallNotificationStream => _controller.stream;

void notifyFallTap(FallNotificationPayload payload) {
  _controller.add(payload);
}

/// Decoded data from the fall notification payload string.
/// Format: "fall_alert:<stage>:<svmPeak>:<cnnProbability>:<immobilityConfirmed>"
class FallNotificationPayload {
  final int stage;
  final double svmPeak;
  final double cnnProbability;
  final bool immobilityConfirmed;

  const FallNotificationPayload({
    required this.stage,
    required this.svmPeak,
    required this.cnnProbability,
    required this.immobilityConfirmed,
  });

  factory FallNotificationPayload.fromPayload(String payload) {
    try {
      final parts = payload.split(':');
      return FallNotificationPayload(
        stage: int.parse(parts[1]),
        svmPeak: double.parse(parts[2]),
        cnnProbability: double.parse(parts[3]),
        immobilityConfirmed: parts[4] == 'true',
      );
    } catch (_) {
      return const FallNotificationPayload(
          stage: 2, svmPeak: 0, cnnProbability: 0, immobilityConfirmed: false);
    }
  }

  FallResult toFallResult() => FallResult(
        triggeredStage: stage,
        svmPeak: svmPeak,
        cnnProbability: cnnProbability,
        immobilityConfirmed: immobilityConfirmed,
      );
}
