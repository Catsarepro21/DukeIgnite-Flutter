import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/ble_service.dart';
import 'scan_screen.dart';
import 'tips_screen.dart'; // NEW
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'debug_console_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/thingspeak_service.dart';
import '../services/thingspeak_service.dart';

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

  // ThingSpeak State
  final TextEditingController _channelIdController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  List<ThingSpeakReading> _history = [];
  bool _isFetchingHistory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sensorData == null) {
      _sensorData = Provider.of<SensorData>(context, listen: false);
      _bleService = Provider.of<BleService>(context, listen: false);
      _sensorData!.addListener(_onDataOrConnectionChange);
      // Immediate evaluation for when the screen is first loaded/returned to
      _onDataOrConnectionChange();
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
    _sensorData?.removeListener(_onDataOrConnectionChange);
    _ssidController.dispose();
    _passController.dispose();
    _channelIdController.dispose();
    _apiKeyController.dispose();
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

  Future<void> _fetchHistory() async {
    final channelId = _channelIdController.text.trim();
    if (channelId.isEmpty) return;

    setState(() => _isFetchingHistory = true);

    final history = await ThingSpeakService.instance.fetchHistory(
      channelId: channelId,
      apiKey: _apiKeyController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _history = history;
        _isFetchingHistory = false;
      });
    }
  }

  void _onDataOrConnectionChange() {
    if (!mounted || _sensorData == null) return;

    // Handle disconnect
    if (!_sensorData!.isConnected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ScanScreen(),
        ),
      );
      return;
    }
  }

  String _getSafetyMessage(double ppm) {
    const learnMore = "\nOpen personalized tips below to learn more";
    if (ppm < 0.05) return "Air quality is currently optimal.";
    if (ppm < 0.10) return "Fair—consider light ventilation.$learnMore";
    if (ppm < 0.50) return "Unhealthy—open a window for safety.$learnMore";
    if (ppm < 1.00) return "DANGEROUS—High concentration detected!$learnMore";
    if (ppm < 3.00) return "TOXIC HAZARD—EVACUATE AREA IMMEDIATELY!$learnMore";
    return "LETHAL RISK—EMERGENCY EVACUATION REQUIRED!$learnMore";
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
            // ---------- PPM Gauge Card (PRIORITIZED AT TOP) ----------
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
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            _getSafetyMessage(sensorData.ppm),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 25),

            // ---------- Tips Button Card (MOVE BELOW GAUGE) ----------
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
                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
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
                          'Personalized Tips',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View personalized safety deep-dive',
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
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
                          label:
                              '${sensorData.ppmThreshold.toStringAsFixed(2)} ppm',
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
            const SizedBox(height: 30),

            // ---------- ThingSpeak Trend Card ----------
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
                        'PPM Trend (ThingSpeak)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: _isFetchingHistory
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _fetchHistory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No history loaded.\nEnter Channel ID below.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _history.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), e.value.ppm);
                              }).toList(),
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withAlpha(30),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _channelIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Channel ID',
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
                    controller: _apiKeyController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Read API Key (Optional)',
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _fetchHistory,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Update History'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
