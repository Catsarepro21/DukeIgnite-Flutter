import 'dart:async';
import 'dart:math';
import '../models/sensor_data.dart';
import 'ble_service.dart';

class MockBleService implements BleService {
  final SensorData sensorData;
  Timer? _timer;
  final Random _random = Random();

  MockBleService(this.sensorData);

  @override
  void startScan() async {
    print("Mock: Starting scan...");
    // Simulate scanning delay
    await Future.delayed(const Duration(seconds: 2));
    print("Mock: Found FormaldehydeSensor!");
    _connect();
  }

  void _connect() {
    print("Mock: Connecting to device...");
    sensorData.setConnectionStatus(true);

    // Start simulating PPM data
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Generate random PPM between 0.0 and 10.0
      double ppm = _random.nextDouble() * 10.0;
      sensorData.updatePpm(ppm);
      print("Mock: Updated PPM to ${ppm.toStringAsFixed(2)}");
    });
  }

  @override
  void stopScan() {
    print("Mock: Stopping scan.");
  }

  @override
  Future<void> setVolume(int volume) async {
    print("Mock: Setting volume to $volume");
    sensorData.updateVolume(volume);
  }

  @override
  Future<void> setWifiCredentials(String ssid, String password) async {
    print("Mock: Setting Wi-Fi to $ssid / $password");
  }

  @override
  void disconnect() {
    print("Mock: Disconnecting...");
    _timer?.cancel();
    sensorData.setConnectionStatus(false);
  }
}
