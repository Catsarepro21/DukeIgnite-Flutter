import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_data.dart';
import 'ble_service.dart';

// Correct Custom UUIDs for the Formaldehyde Sensor
const String targetDeviceName = "FormaldehydeSensor";
final Guid formaldehydeServiceUuid = Guid("0000FFFF-0000-1000-8000-00805F9B34FB");
final Guid ppmCharacteristicUuid = Guid("0000EEE1-0000-1000-8000-00805F9B34FB");
final Guid volumeCharacteristicUuid = Guid("0000EEE2-0000-1000-8000-00805F9B34FB");
final Guid wifiSsidCharacteristicUuid = Guid("0000EEE3-0000-1000-8000-00805F9B34FB");
final Guid wifiPassCharacteristicUuid = Guid("0000EEE4-0000-1000-8000-00805F9B34FB");

class RealBleService implements BleService {
  final SensorData sensorData;
  BluetoothDevice? _device;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _ppmSubscription;

  RealBleService(this.sensorData);

  @override
  void startScan() {
    debugPrint("Real: Starting scan...");
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == targetDeviceName) {
          FlutterBluePlus.stopScan();
          _connect(r.device);
          break;
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  void _connect(BluetoothDevice device) async {
    _device = device;
    _connectionSubscription = _device!.connectionState.listen((state) {
      sensorData.setConnectionStatus(state == BluetoothConnectionState.connected);
      if (state == BluetoothConnectionState.connected) {
        _discoverServices();
      }
    });

    await _device!.connect(autoConnect: false);
  }

  void _discoverServices() async {
    if (_device == null) return;
    List<BluetoothService> services = await _device!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == formaldehydeServiceUuid) {
        _setupPpmNotifications(service);
      }
    }
  }

  void _setupPpmNotifications(BluetoothService service) async {
    var ppmCharacteristic = service.characteristics.firstWhere((c) => c.uuid == ppmCharacteristicUuid);
    await ppmCharacteristic.setNotifyValue(true);
    _ppmSubscription = ppmCharacteristic.lastValueStream.listen((value) {
      // TODO: Implement proper data parsing from the characteristic value
      // This is just an example, assuming the value is a single float.
      // You might need to use a ByteData and a different Endian.
      if (value.isNotEmpty) {
        double ppm = Uint8List.fromList(value).buffer.asByteData().getFloat32(0, Endian.little);
        sensorData.updatePpm(ppm);
      }
    });
  }

  @override
  void disconnect() {
    debugPrint("Real: Disconnecting...");
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _ppmSubscription?.cancel();
    _device?.disconnect();
  }

  @override
  Future<void> setVolume(int volume) async {
    if (_device == null) return;
    try {
      BluetoothService service = await _findService();
      var characteristic = service.characteristics.firstWhere((c) => c.uuid == volumeCharacteristicUuid);
      // Assuming volume is a single byte
      await characteristic.write([volume]);
      sensorData.updateVolume(volume);
    } catch (e) {
      debugPrint("Error setting volume: $e");
    }
  }

  @override
  Future<void> setWifiCredentials(String ssid, String pass) async {
    if (_device == null) return;
     try {
      BluetoothService service = await _findService();
      var ssidChar = service.characteristics.firstWhere((c) => c.uuid == wifiSsidCharacteristicUuid);
      var passChar = service.characteristics.firstWhere((c) => c.uuid == wifiPassCharacteristicUuid);
      
      await ssidChar.write(ssid.codeUnits);
      await passChar.write(pass.codeUnits);
     } catch (e) {
      debugPrint("Error setting WiFi credentials: $e");
    }
  }

  Future<BluetoothService> _findService() async {
    if (_device == null) throw "Device not connected";
    List<BluetoothService> services = await _device!.discoverServices();
    return services.firstWhere((s) => s.uuid == formaldehydeServiceUuid);
  }

  @override
  void dispose() {
    disconnect();
  }
}
