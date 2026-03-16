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
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
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
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _sendWifiCredentials() async {
    final bleService = _bleService;
    if (bleService == null) return;
    FocusScope.of(context).unfocus();
    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim(); // empty = open network

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the network SSID.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await bleService.setWifiCredentials(ssid, pass);

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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- Tips Button Card ----------
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TipsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)], // Blue gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withAlpha(50),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tips',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Get personalized safety advice',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

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

            // Volume Control Card
            Consumer<SensorData>(
              builder: (context, sensorData, child) {
                return Container(
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
                          overlayColor: Colors.blueAccent.withAlpha(51),
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
                            _bleService?.setVolume(val.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // PPM Threshold Control Card
            Consumer<SensorData>(
              builder: (context, sensorData, child) {
                return Container(
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
                            'PPM Alarm Threshold',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orangeAccent[100]),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alarm above ${sensorData.ppmThreshold} ppm',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.orangeAccent,
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: Colors.orangeAccent,
                          overlayColor: Colors.orangeAccent.withAlpha(51),
                        ),
                        child: Slider(
                          value: sensorData.ppmThreshold,
                          min: 0.0,
                          max: 5.0,
                          divisions: 100, // 0.05 ppm increments
                          label: '${sensorData.ppmThreshold.toStringAsFixed(2)} ppm',
                          onChanged: (val) {
                            sensorData.updatePpmThreshold(val);
                          },
                          onChangeEnd: (val) {
                            _bleService?.setPpmThreshold(val);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // LCD Contrast Control Card
            Consumer<SensorData>(
              builder: (context, sensorData, child) {
                return Container(
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
                            'LCD Contrast',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.brightness_medium,
                              color: Colors.purpleAccent[100]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purpleAccent,
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: Colors.purpleAccent,
                          overlayColor: Colors.purpleAccent.withAlpha(51),
                        ),
                        child: Slider(
                          value: sensorData.lcdContrast.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 10,
                          label: '${sensorData.lcdContrast}%',
                          onChanged: (val) {
                            sensorData.updateLcdContrast(val.toInt());
                          },
                          onChangeEnd: (val) {
                            _bleService?.setLcdContrast(val.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            
            // Sensor Wi-Fi Setup Card (Static, no Consumer needed)
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
                      labelText: 'Password (leave blank for open network)',
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