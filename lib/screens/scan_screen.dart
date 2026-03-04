import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  SensorData? _sensorData;
  BleService? _bleService;
  
  // TODO: Update this version number to match pubspec.yaml
  final String _version = '1.0.0+1';

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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    }
  }

  Future<void> _startScan() async {
    final bleService = _bleService;
    if (bleService == null) return;

    if (!kIsWeb) {
       Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.location]!.isGranted &&
          (statuses[Permission.bluetoothScan]!.isGranted ||
              statuses[Permission.bluetoothScan]!.isRestricted)) {
        // All good
      } else {
        setState(() {
          _statusMessage = 'Permissions not granted for BLE access.';
        });
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Searching for Formaldehyde Sensor...';
    });
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
                child: const Text('Start Scan', style: TextStyle(fontSize: 18)),
              ),
            if (_isScanning)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'v.$_version',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
