import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import 'dashboard_screen.dart';

class ScanScreen extends StatefulWidget {
  final BleService bleService;

  const ScanScreen({super.key, required this.bleService});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isScanning = false;
  String _statusMessage = 'Ready to scan for Formaldehyde Sensor';
  SensorData? _sensorData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sensorData == null) {
      _sensorData = Provider.of<SensorData>(context, listen: false);
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
          builder: (context) => DashboardScreen(bleService: widget.bleService),
        ),
      );
    }
  }

  Future<void> _startScan() async {
    bool canScan = false;

    if (kIsWeb) {
      // Browsers handle permissions automatically via the Web Bluetooth API
      canScan = true;
    } else {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.location]!.isGranted &&
          (statuses[Permission.bluetoothScan]!.isGranted ||
              statuses[Permission.bluetoothScan]!.isRestricted)) {
        canScan = true;
      }
    }

    if (canScan) {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Searching for Formaldehyde Sensor...';
      });
      widget.bleService.startScan();
    } else {
      setState(() {
        _statusMessage = 'Permissions not granted needed for BLE access.';
      });
    }
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
    );
  }
}
