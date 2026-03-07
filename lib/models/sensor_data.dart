import 'package:flutter/foundation.dart';

/// Holds all real-time state from the BLE sensor and notifies listeners
/// on any change. PPM is updated by [RealBleService] via BLE notifications —
/// there is no simulation timer; data only comes from the hardware.
class SensorData extends ChangeNotifier {
  bool _isConnected = false;
  double _ppm = 0.0;
  int _volume = 50;

  bool get isConnected => _isConnected;
  double get ppm => _ppm;
  int get volume => _volume;

  void setConnectionStatus(bool status) {
    if (_isConnected == status) return;
    _isConnected = status;
    debugPrint('[SensorData] Connection status → $status');
    notifyListeners();
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
}
