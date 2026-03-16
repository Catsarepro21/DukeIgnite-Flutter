import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Holds all real-time state from the BLE sensor and notifies listeners
/// on any change. PPM is updated by [RealBleService] via BLE notifications —
/// there is no simulation timer; data only comes from the hardware.
class SensorData extends ChangeNotifier {
  bool _isConnected = false;
  bool _isBypassMode = false;
  double _ppm = 0.0;
  int _volume = 50;
  double _ppmThreshold = 0.5; // ppm alarm threshold (0.0–5.0)
  int _lcdContrast = 50; // LCD contrast (0–100)
  DateTime? _lastNotificationTime;

  bool get isConnected => _isConnected || _isBypassMode;
  bool get isBypassMode => _isBypassMode;
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

  void setBypassMode(bool enabled) {
    if (_isBypassMode == enabled) return;
    _isBypassMode = enabled;
    debugPrint('[SensorData] Bypass mode → $enabled');
    notifyListeners();
  }

  void updatePpm(double ppm) {
    _ppm = ppm;

    // Check for threshold breach and send notification
    if (_ppm >= _ppmThreshold && _isConnected) {
      final now = DateTime.now();
      if (_lastNotificationTime == null ||
          now.difference(_lastNotificationTime!) > const Duration(minutes: 5)) {
        _lastNotificationTime = now;
        NotificationService.instance.showHighPpmAlert(_ppm);
      }
    }

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
