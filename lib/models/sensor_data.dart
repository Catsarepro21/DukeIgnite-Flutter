import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SensorData extends ChangeNotifier {
  BluetoothDevice? _device;
  bool _isConnected = false;
  double _ppm = 0.0;
  int _volume = 50;
  Timer? _timer;

  BluetoothDevice? get device => _device;
  bool get isConnected => _isConnected;
  double get ppm => _ppm;
  int get volume => _volume;

  void setDevice(BluetoothDevice? device) {
    if (_device == device) return;
    _device = device;
    notifyListeners();
  }

  void setConnectionStatus(bool status) {
    if (_isConnected == status) return;
    _isConnected = status;
    if (!_isConnected) {
      _timer?.cancel();
      _timer = null;
    } else {
      _startDataSimulation();
    }
    notifyListeners();
  }

  void _startDataSimulation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final random = Random();
      double newPpm = 0.0;
      if (_isConnected) {
        // Simulate a more realistic PPM value fluctuation
        double change = (random.nextDouble() - 0.4) * 0.1;
        newPpm = (_ppm + change).clamp(0.0, 1.0);
      }
      updatePpm(newPpm);
    });
  }

  void updatePpm(double ppm) {
    _ppm = ppm;
    notifyListeners();
  }

  void updateVolume(int volume) {
    if (_volume == volume) return;
    _volume = volume;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
