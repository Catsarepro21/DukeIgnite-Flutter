import 'services/ble_service.dart';
import 'services/real_ble_service.dart';
import 'models/sensor_data.dart';

/// Returns the BLE service for the current platform.
///
/// [universal_ble] supports Android, iOS, macOS, Windows, Linux, and Web,
/// so [RealBleService] is used everywhere — no platform branching needed.
BleService getBleService(SensorData sensorData) => RealBleService(sensorData);
