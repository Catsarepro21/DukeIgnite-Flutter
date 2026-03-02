import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import 'scan_screen.dart';

class DashboardScreen extends StatefulWidget {
  final BleService bleService;

  const DashboardScreen({super.key, required this.bleService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
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
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _sensorData?.removeListener(_onConnectionChange);
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onConnectionChange() {
    if (!mounted || _sensorData == null) return;
    if (!_sensorData!.isConnected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ScanScreen(bleService: widget.bleService),
        ),
      );
    }
  }

  Future<void> _sendWifiCredentials() async {
    FocusScope.of(context).unfocus();
    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim();

    if (ssid.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both SSID and Password'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await widget.bleService.setWifiCredentials(ssid, pass);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credentials sent to sensor!'),
          backgroundColor: Colors.green,
        ),
      );
      _ssidController.clear();
      _passController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send credentials: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensorData = Provider.of<SensorData>(context);
    final isDanger =
        sensorData.ppm >= 5.0; // Default alarm threshold on arduino

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sensor Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
            onPressed: () {
              widget.bleService.disconnect();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PPM Gauge Card
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: isDanger
                        ? Colors.redAccent.withOpacity(0.2)
                        : Colors.blueAccent.withOpacity(0.1),
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
                    sensorData.ppm.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: isDanger ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  const Text(
                    'PPM',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  if (isDanger)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'WARNING: High Levels!',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Volume Control Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alarm Volume',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.volume_up, color: Colors.blueAccent[100]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.grey[800],
                      thumbColor: Colors.blueAccent,
                      overlayColor: Colors.blueAccent.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: sensorData.volume.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: sensorData.volume.toString(),
                      onChanged: (val) {
                        sensorData.updateVolume(val.toInt());
                      },
                      onChangeEnd: (val) {
                        widget.bleService.setVolume(val.toInt());
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Wi-Fi Config Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sensor Wi-Fi Setup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.wifi, color: Colors.blueAccent[100]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ssidController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'SSID',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendWifiCredentials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Update Credentials',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
