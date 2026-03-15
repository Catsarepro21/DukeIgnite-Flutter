import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_services.dart';
import 'models/sensor_data.dart';
import 'screens/scan_screen.dart';
import 'services/ble_service.dart';
import 'services/gemini_service.dart';

void main() async {
  // Must be called before any Flutter plugin or platform channel is used,
  // including universal_ble's static initializer which sets up message handlers.
  WidgetsFlutterBinding.ensureInitialized();

  // Try loading the Env file if it exists
  try {
    await dotenv.load(fileName: ".env");
    GeminiService.instance.initialize();
  } catch (e) {
    debugPrint("No .env file found or failed to load: $e");
  }

  // The SensorData is created once and provided to the entire app.
  final sensorData = SensorData();
  
  // The BleService is determined by the getBleService function and provided.
  final bleService = getBleService(sensorData);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sensorData),
        Provider<BleService>.value(value: bleService),
      ],
      child: const FormaldehydeApp(),
    ),
  );
}

class FormaldehydeApp extends StatelessWidget {
  const FormaldehydeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formaldehyde Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Inter', 
      ),
      home: const ScanScreen(),
    );
  }
}
