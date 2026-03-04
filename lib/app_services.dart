import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'services/ble_service.dart';
import 'services/real_ble_service.dart';
import 'services/unsupported_ble_service.dart';
import 'models/sensor_data.dart';

BleService getBleService(SensorData sensorData) {
  if (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows) {
    return UnsupportedBleService(sensorData);
  } else {
    return RealBleService(sensorData);
  }
}
