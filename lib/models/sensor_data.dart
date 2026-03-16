import 'package:flutter/material.dart';

/// Holds all real-time state from the BLE sensor and notifies listeners
/// on any change. PPM is updated by [RealBleService] via BLE notifications —
/// there is no simulation timer; data only comes from the hardware.
class SensorData extends ChangeNotifier {
  bool _isConnected = false;
  double _ppm = 0.0;
  int _volume = 50;
  double _ppmThreshold = 0.5; // ppm alarm threshold (0.0–5.0)
  int _lcdContrast = 50; // LCD contrast (0–100)

  bool get isConnected => _isConnected;
  double get ppm => _ppm;
  int get volume => _volume;
  double get ppmThreshold => _ppmThreshold;
  int get lcdContrast => _lcdContrast;

  Color get alertColor {
    if (_ppm < 0.1) return Colors.greenAccent;
    if (_ppm < _ppmThreshold) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  bool get ventilationWarning {
    return _ppm >= _ppmThreshold;
  }

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

  void updatePpmThreshold(double ppm) {
    if (_ppmThreshold == ppm) return;
    _ppmThreshold = ppm;
    notifyListeners();
  }

  void updateLcdContrast(int contrast) {
    if (_lcdContrast == contrast) return;
    _lcdContrast = contrast;
    notifyListeners();
  }
}
