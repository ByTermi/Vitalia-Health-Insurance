import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_page.dart';
import 'services/fall_background_service.dart';
import 'services/notification_state.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initNotifications();
  await FallBackgroundService.configure();
  await _requestPermissions();

  runApp(const VitaliaApp());
}

Future<void> _initNotifications() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: _onNotificationResponseBackground,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
    'vitalia_bg',
    'Vitalia en segundo plano',
    description: 'Servicio de monitorización de caídas',
    importance: Importance.low,
  ));

  await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
    'fall_alert',
    'Alertas de caída',
    description: 'Vitalia detectó una posible caída',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  ));

  // Check if app was cold-started by tapping a fall notification.
  final launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true &&
      launchDetails?.notificationResponse?.payload != null) {
    initialFallPayload = FallNotificationPayload.fromPayload(
        launchDetails!.notificationResponse!.payload!);
  }
}

void _onNotificationResponse(NotificationResponse response) {
  if (response.payload?.startsWith('fall_alert') == true) {
    notifyFallTap(FallNotificationPayload.fromPayload(response.payload!));
  }
}

@pragma('vm:entry-point')
void _onNotificationResponseBackground(NotificationResponse response) {
  // Cold-start handled via initialFallPayload in _initNotifications().
}

Future<void> _requestPermissions() async {
  await [
    Permission.sensors,
    Permission.notification,
  ].request();
}

class VitaliaApp extends StatelessWidget {
  const VitaliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitalia HAR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFEFF2F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1558D6),
          primary: const Color(0xFF1558D6),
          brightness: Brightness.light,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF1558D6),
          thumbColor: Color(0xFF1558D6),
        ),
      ),
      home: const HomePage(),
    );
  }
}
