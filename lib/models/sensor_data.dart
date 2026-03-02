import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SensorData extends ChangeNotifier {
  BluetoothDevice? _device;
  bool _isConnected = false;
  double _ppm = 0.0;
  int _volume = 50;

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
    notifyListeners();
  }

  void updatePpm(double ppm) {
    if (_ppm == ppm) return;
    _ppm = ppm;
    notifyListeners();
  }

  void updateVolume(int volume) {
    if (_volume == volume) return;
    _volume = volume;
    notifyListeners();
  }
}
