import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import '../services/log_service.dart';
import 'dashboard_screen.dart';
import 'debug_console_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = false;
  String _statusMessage = 'Ready to scan for Formaldehyde Sensor';
  String _version = '';
  SensorData? _sensorData;
  BleService? _bleService;
  int _debugTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    const envVersion = String.fromEnvironment('APP_VERSION');
    if (kIsWeb && envVersion.isNotEmpty) {
      if (!mounted) return;
      setState(() => _version = envVersion);
      return;
    }

    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

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
  void dispose() {
    _sensorData?.removeListener(_onConnectionChange);
    super.dispose();
  }

  void _onConnectionChange() {
    if (!mounted || _sensorData == null) return;
    if (_sensorData!.isConnected) {
      LogService.instance.log('[ScanScreen] Device connected — navigating to Dashboard.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      // Scan timeout or disconnect — reset UI so the user can try again.
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Device not found. Tap Scan to try again.';
        });
      }
    }
  }

  Future<void> _startScan() async {
    final bleService = _bleService;
    if (bleService == null) return;

    // On mobile we request permissions before scanning.
    // iOS: only general Bluetooth permission needed.
    // Android: location + Bluetooth scan + Bluetooth connect required.
    if (!kIsWeb) {
      List<Permission> toRequest;

      if (Platform.isIOS) {
        toRequest = [Permission.bluetooth];
      } else {
        // Android (and any other native platform)
        toRequest = [
          Permission.location,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ];
      }

      final statuses = await toRequest.request();
      LogService.instance.log('[ScanScreen] Permissions: $statuses');

      bool allGranted = true;
      if (Platform.isIOS) {
        allGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
      } else {
        final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
        final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
        final locationOk = statuses[Permission.location]?.isGranted ?? false;
        allGranted = scanOk && connectOk && locationOk;
      }

      if (!allGranted) {
        setState(() {
          _statusMessage = Platform.isIOS
              ? 'Bluetooth permission is required.\nGo to Settings → Privacy → Bluetooth.'
              : 'Bluetooth & location permissions are required.';
        });
        LogService.instance.log('[ScanScreen] Permissions not granted — aborting scan.');
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _statusMessage = kIsWeb
          ? 'A browser picker will open.\n'
              'Select "FormaldehydeSensor" from the list.'
          : 'Searching for Formaldehyde Sensor…';
    });

    LogService.instance.log('[ScanScreen] Starting BLE scan (web=$kIsWeb).');
    bleService.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Connect to Sensor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 30),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 18, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (kIsWeb && !_isScanning) ...[
                const SizedBox(height: 12),
                const Text(
                  '⚠ Web Bluetooth requires Chrome or Edge.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 40),
              if (!_isScanning)
                 ElevatedButton(
                  onPressed: _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Start Scan',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              if (_isScanning)
                const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () {
            final now = DateTime.now();
            if (_lastTapTime == null || 
                now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
              _debugTapCount = 1;
            } else {
              _debugTapCount++;
            }
            _lastTapTime = now;

            if (_debugTapCount >= 5) {
              _debugTapCount = 0;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DebugConsoleScreen()),
              );
            }
          },
          child: Text(
            _version.isEmpty ? '' : 'v.$_version',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
