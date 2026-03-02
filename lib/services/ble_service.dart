import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_data.dart';

abstract class BleService {
  void startScan();
  void stopScan();
  Future<void> setVolume(int volume);
  Future<void> setWifiCredentials(String ssid, String password);
  void disconnect();
}

class RealBleService implements BleService {
  final SensorData sensorData;

  // --- ARDUINO GATT UUIDs ---
  static const String SERVICE_UUID = "0000FFFF-0000-1000-8000-00805F9B34FB";
  static const String CHARACTERISTIC_PPM =
      "0000EEE1-0000-1000-8000-00805F9B34FB";
  static const String CHARACTERISTIC_VOLUME =
      "0000EEE2-0000-1000-8000-00805F9B34FB";
  static const String CHARACTERISTIC_SSID =
      "0000EEE3-0000-1000-8000-00805F9B34FB";
  static const String CHARACTERISTIC_PASS =
      "0000EEE4-0000-1000-8000-00805F9B34FB";

  BluetoothCharacteristic? _ppmChar;
  BluetoothCharacteristic? _volumeChar;
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passChar;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _ppmSubscription;

  RealBleService(this.sensorData);

  @override
  void startScan() async {
    try {
      // Check if Bluetooth is supported on this platform
      if (!await FlutterBluePlus.isSupported) {
        print("Bluetooth is not supported on this platform.");
        return;
      }

      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.on) {
        await FlutterBluePlus.startScan(
          withServices: [Guid(SERVICE_UUID)],
          timeout: const Duration(seconds: 15),
        );

        _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult r in results) {
            String name = r.device.advName.isNotEmpty
                ? r.device.advName
                : (r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : "Unknown");

            print("Found device: $name (${r.device.remoteId})");

            if (name == "FormaldehydeSensor") {
              print("Match found! Connecting to $name...");
              FlutterBluePlus.stopScan();
              _connectToDevice(r.device);
              break;
            }
          }
        });
      }
    } catch (e) {
      print("Scan Error: $e");
    }
  }

  @override
  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      sensorData.setDevice(device);
      sensorData.setConnectionStatus(true);

      // CustomDeviceState state = CustomDeviceState.disconnected;
      device.connectionState.listen((BluetoothConnectionState st) {
        if (st == BluetoothConnectionState.disconnected) {
          sensorData.setConnectionStatus(false);
          _ppmSubscription?.cancel();
        }
      });

      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        String sUuid = service.uuid.toString().toUpperCase();
        if (sUuid.contains("FFFF")) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            String cUuid = characteristic.uuid.toString().toUpperCase();
            if (cUuid.contains("EEE1")) {
              print("Found PPM Characteristic");
              _ppmChar = characteristic;
              await _subscribeToPpm();
            } else if (cUuid.contains("EEE2")) {
              print("Found Volume Characteristic");
              _volumeChar = characteristic;
            } else if (cUuid.contains("EEE3")) {
              print("Found SSID Characteristic");
              _ssidChar = characteristic;
            } else if (cUuid.contains("EEE4")) {
              print("Found Password Characteristic");
              _passChar = characteristic;
            }
          }
        }
      }
    } catch (e) {
      print("Connection Error: $e");
      sensorData.setConnectionStatus(false);
    }
  }

  Future<void> _subscribeToPpm() async {
    if (_ppmChar != null) {
      try {
        await _ppmChar!.setNotifyValue(true);
        _ppmSubscription = _ppmChar!.lastValueStream.listen((value) {
          if (value.length == 4) {
            ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
            double ppm = byteData.getFloat32(0, Endian.little);
            sensorData.updatePpm(ppm);
          }
        });
      } catch (e) {
        print("PPM Subscription Error: $e");
      }
    }
  }

  @override
  Future<void> setVolume(int volume) async {
    if (_volumeChar != null) {
      try {
        print("Setting volume to $volume...");
        await _volumeChar!.write([volume]);
        sensorData.updateVolume(volume);
        print("Volume set successfully.");
      } catch (e) {
        print("Set Volume Error: $e");
      }
    }
  }

  @override
  Future<void> setWifiCredentials(String ssid, String password) async {
    try {
      if (_ssidChar != null) {
        print("Writing SSID: $ssid");
        await _ssidChar!.write(utf8.encode(ssid));
      } else {
        print("Error: SSID Characteristic (EEE3) not found!");
      }
      if (_passChar != null) {
        print("Writing Password to sensor...");
        await _passChar!.write(utf8.encode(password));
      } else {
        print("Error: Password Characteristic (EEE4) not found!");
      }
      print("Wi-Fi credentials sent successfully.");
    } catch (e) {
      print("Set Wi-Fi Error: $e");
      rethrow; // So the UI can handle or ignore it
    }
  }

  @override
  void disconnect() {
    if (!sensorData.isConnected) return;
    sensorData.device?.disconnect();
    _ppmSubscription?.cancel();
    _scanSubscription?.cancel();
    sensorData.setConnectionStatus(false);
  }
}

enum CustomDeviceState { disconnected, connecting, connected }
