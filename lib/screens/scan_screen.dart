import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import 'dashboard_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
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
      debugPrint('[ScanScreen] Device connected — navigating to Dashboard.');
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

    // On mobile (non-web) we need to request runtime permissions ourselves.
    // universal_ble handles Windows/Linux/Web internally.
    if (!kIsWeb) {
      final statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      debugPrint('[ScanScreen] Permissions: $statuses');

      final locationOk = statuses[Permission.location]?.isGranted ?? false;
      final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;

      if (!locationOk || !scanOk) {
        setState(() {
          _statusMessage = 'Bluetooth & location permissions are required.';
        });
        debugPrint('[ScanScreen] Permissions not granted — aborting scan.');
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

    debugPrint('[ScanScreen] Starting BLE scan (web=$kIsWeb).');
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
        child: Text(
          _version.isEmpty ? '' : 'v.$_version',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
