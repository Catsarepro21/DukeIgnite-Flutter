import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/sensor_data.dart';
import 'ble_service.dart';

class UnsupportedBleService implements BleService {
  final SensorData _sensorData;

  UnsupportedBleService(this._sensorData) {
    debugPrint("BLE is not supported on this platform.");
  }

  @override
  void startScan() {
    // Do nothing, as BLE is not supported.
  }

  @override
  void disconnect() {
    _sensorData.setConnectionStatus(false);
  }

  @override
  Future<void> setVolume(int volume) async {
    // No device to control.
  }

  @override
  Future<void> setWifiCredentials(String ssid, String pass) async {
    // No device to configure.
  }

  @override
  void dispose() {
    // Nothing to dispose.
  }
}
