import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const VitaliaApp());
}

Future<void> _requestPermissions() async {
  // sensors_plus on Android 12+ requires BODY_SENSORS for health data
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
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.blueAccent.shade100,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
