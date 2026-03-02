import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/sensor_data.dart';
import 'screens/scan_screen.dart';
import 'services/ble_service.dart';

import 'services/mock_ble_service.dart';

const bool useMock = false; // Set to false for real hardware

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SensorData())],
      child: const FormaldehydeApp(),
    ),
  );
}

class FormaldehydeApp extends StatefulWidget {
  const FormaldehydeApp({super.key});

  @override
  State<FormaldehydeApp> createState() => _FormaldehydeAppState();
}

class _FormaldehydeAppState extends State<FormaldehydeApp> {
  late BleService _bleService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final sensorData = Provider.of<SensorData>(context, listen: false);
      if (useMock) {
        _bleService = MockBleService(sensorData);
      } else {
        _bleService = RealBleService(sensorData);
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formaldehyde Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Inter', // Assuming Inter if added, else system default
      ),
      home: ScanScreen(bleService: _bleService),
    );
  }
}
