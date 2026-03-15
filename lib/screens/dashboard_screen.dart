import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import 'scan_screen.dart';
import 'tips_screen.dart'; // NEW
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'debug_console_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SensorData? _sensorData;
  BleService? _bleService;
  String _version = '';
  int _debugTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sensorData == null) {
      _sensorData = Provider.of<SensorData>(context, listen: false);
      _bleService = Provider.of<BleService>(context, listen: false);
      _sensorData!.addListener(_onConnectionChange);
    }
  }

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    const envVersion = String.fromEnvironment('APP_VERSION');
    if (kIsWeb && envVersion.isNotEmpty) {
      setState(() {
        _version = envVersion;
      });
      return;
    }

    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  @override
  void dispose() {
    _sensorData?.removeListener(_onConnectionChange);
    super.dispose();
  }

  void _onConnectionChange() {
    if (!mounted || _sensorData == null) return;
    if (!_sensorData!.isConnected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ScanScreen(),
        ),
      );
    }
  }


  String _formatPpm(double ppm) {
    if (ppm < 0.01) return ppm.toStringAsFixed(4);
    if (ppm < 0.1) return ppm.toStringAsFixed(3);
    if (ppm < 10.0) return ppm.toStringAsFixed(2);
    return ppm.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sensor Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
            onPressed: () {
              _bleService?.disconnect();
            },
          ),
          IconButton(
            icon: const Icon(Icons.health_and_safety),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TipsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- PPM Gauge Card ----------
            Consumer<SensorData>(
              builder: (context, sensorData, child) {
                final alertColor = sensorData.alertColor;
                return Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: alertColor.withAlpha(60),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Formaldehyde level',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatPpm(sensorData.ppm),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: alertColor,
                        ),
                      ),
                      const Text(
                        'PPM',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      if (sensorData.ventilationWarning)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Open a door or window for your safety',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),

            // ---------- Other Controls (Volume, Threshold, LCD, WiFi) ----------
            // Keep your existing Consumer sliders and WiFi setup here unchanged
            // ...
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('About App'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Duke Ignite Formaldehyde Monitor'),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    if (_lastTapTime == null ||
                        now.difference(_lastTapTime!) >
                            const Duration(seconds: 2)) {
                      _debugTapCount = 1;
                    } else {
                      _debugTapCount++;
                    }
                    _lastTapTime = now;

                    if (_debugTapCount >= 5) {
                      _debugTapCount = 0;
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const DebugConsoleScreen()),
                      );
                    }
                  },
                  child: Text(
                    'Version $_version',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}