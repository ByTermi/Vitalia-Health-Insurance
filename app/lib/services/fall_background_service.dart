import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../sensors/sensor_service.dart';
import '../inference/fall_detector.dart';
import '../storage/database_service.dart';

const _bgChannelId = 'vitalia_bg';
const _fallChannelId = 'fall_alert';
const _persistentNotifId = 889;

class FallBackgroundService {
  /// Call once at app startup (before runApp) to register the background service.
  static Future<void> configure() async {
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        notificationChannelId: _bgChannelId,
        initialNotificationTitle: 'Vitalia',
        initialNotificationContent: 'Monitorizando caídas…',
        foregroundServiceNotificationId: _persistentNotifId,
        foregroundServiceTypes: [AndroidForegroundType.health],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  static Future<void> start() async {
    await FlutterBackgroundService().startService();
  }

  static Future<void> stop() async {
    FlutterBackgroundService().invoke('stopService');
  }

  static Stream<Map<String, dynamic>?> get fallEvents =>
      FlutterBackgroundService().on('fallDetected');
}

/// Entry point that runs in the background isolate.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  // Required so Flutter plugins (sensors_plus, tflite_flutter) work in this isolate.
  DartPluginRegistrant.ensureInitialized();

  final notif = FlutterLocalNotificationsPlugin();
  await notif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final sensorService = SensorService();
  final fallDetector = FallDetector(mode: DetectionMode.balanced);
  final fallBuffer = SlidingWindowBuffer(windowSize: 100, overlap: 0.5);

  // Honour user-tuned thresholds (SQLite) — the SVM gate governs stage-1 in background too.
  try {
    final db = DatabaseService.instance;
    await db.init();
    final s = await db.getAllSettings();
    for (final m in DetectionMode.values) {
      fallDetector.setCnnThreshold(m, s['cnn_${m.name}'] ?? defaultThresholds[m]!);
    }
    fallDetector.svmThreshold =
        s['svm_threshold'] ?? FallDetector.defaultSvmThreshold;
  } catch (_) {
    // DB unavailable in isolate → keep defaults.
  }

  await fallDetector.load();
  sensorService.start();

  // Cooldown to prevent duplicate alerts from the same fall event.
  DateTime? lastFallTime;
  const cooldown = Duration(seconds: 15);

  service.on('stopService').listen((_) {
    sensorService.dispose();
    fallDetector.dispose();
    service.stopSelf();
  });

  sensorService.sampleStream.listen((sample) {
    final window = fallBuffer.addSample(sample);
    if (window == null) return;

    final result = fallDetector.analyze(window);
    if (!result.isFall || result.triggeredStage < 2) return;

    final now = DateTime.now();
    if (lastFallTime != null && now.difference(lastFallTime!) < cooldown) {
      return;
    }
    lastFallTime = now;

    _showFallNotification(notif, result);

    service.invoke('fallDetected', {
      'stage': result.triggeredStage,
      'svmPeak': result.svmPeak,
      'cnnProbability': result.cnnProbability,
      'immobilityConfirmed': result.immobilityConfirmed,
    });
  });
}

Future<void> _showFallNotification(
    FlutterLocalNotificationsPlugin notif, FallResult result) async {
  const androidDetails = AndroidNotificationDetails(
    _fallChannelId,
    'Alertas de caída',
    channelDescription: 'Vitalia detectó una posible caída',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
  );

  final svmStr = result.svmPeak.toStringAsFixed(1);
  final cnnStr = (result.cnnProbability * 100).toStringAsFixed(0);

  await notif.show(
    888,
    '¡Posible caída detectada!',
    'Pico SVM: ${svmStr}g · CNN: $cnnStr% · Etapa ${result.triggeredStage}',
    const NotificationDetails(android: androidDetails),
    payload: 'fall_alert:${result.triggeredStage}:${result.svmPeak}:${result.cnnProbability}:${result.immobilityConfirmed}',
  );
}
