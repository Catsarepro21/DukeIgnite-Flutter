import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
// Hide universal_ble's internal BleService model to avoid name collision
// with our own BleService abstract class.
import 'package:universal_ble/universal_ble.dart' hide BleService;
import '../models/sensor_data.dart';
import 'ble_service.dart';
import 'log_service.dart';

// ---------------------------------------------------------------------------
// BLE Configuration
// ---------------------------------------------------------------------------

/// The advertised name the app scans for.
const String targetDeviceName = 'FormaldehydeSensor';

/// Primary GATT service UUID.
const String serviceUuid = '0000FFFF-0000-1000-8000-00805F9B34FB';

/// Notify characteristic — sensor pushes PPM readings as a little-endian
/// 4-byte IEEE 754 float.
const String ppmCharUuid = '0000EEE1-0000-1000-8000-00805F9B34FB';

/// Write characteristic — app sends command packets.
///
/// Packet format:
///   [0x01, volume]                              → set buzzer volume (0–100)
///   [0x02, ...ssidBytes, 0x00, ...passBytes]    → set Wi-Fi credentials
const String cmdCharUuid = '0000EEE2-0000-1000-8000-00805F9B34FB';

// Command byte identifiers
const int _cmdVolume = 0x01;
const int _cmdWifi = 0x02;
const int _cmdThreshold = 0x03; // [0x03, low_byte, high_byte] = ppm uint16 LE
const int _cmdContrast = 0x04;  // [0x04, contrast 0-100]

// ---------------------------------------------------------------------------

class RealBleService implements BleService {
  final SensorData sensorData;

  BleDevice? _device;
  bool _isConnected = false;

  /// True only after service discovery completes successfully.
  /// Writes are blocked until this is set to prevent race conditions where
  /// the UI navigates to the dashboard and the user interacts before GATT is ready.
  bool _serviceReady = false;

  /// Guards against the scan result callback firing more than once before
  /// stopScan() completes, which would call _connect() concurrently.
  bool _isConnecting = false;

  /// After a subscription failure on web, Chrome's Web Bluetooth marks the
  /// GATT service object as stale. We re-discover to get fresh handles, then
  /// set this flag so we never attempt subscription again on this connection.
  bool _skipSubscription = false;

  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;

  RealBleService(this.sensorData) {
    // Listen to connection state changes.
    UniversalBle.onConnectionChange =
        (String deviceId, bool isConnected, String? error) {
      if (_device?.deviceId != deviceId) return;
      LogService.instance.log(
        '[BLE] Connection change: deviceId=$deviceId '
        'connected=$isConnected error=$error',
      );
      
      _isConnected = isConnected;
      
      if (isConnected) {
        _reconnectTimer?.cancel();
        sensorData.setConnectionStatus(true);
      } else {
        _serviceReady = false;
        _skipSubscription = false;
        LogService.instance.log('[BLE] Disconnected — flags cleared.');
        
        if (!_intentionalDisconnect) {
          LogService.instance.log('[BLE] Unexpected disconnect. Attempting auto-reconnect in background...');
          // Try connecting again immediately
          _connect(_device!);
          
          // Give it 5 seconds to reconnect before notifying UI
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(const Duration(seconds: 5), () {
            if (!_isConnected && _device != null) {
              LogService.instance.log('[BLE] Auto-reconnect failed. Notifying UI of disconnect.');
              sensorData.setConnectionStatus(false);
            }
          });
        } else {
          sensorData.setConnectionStatus(false);
        }
      }
    };

    // Listen to characteristic value changes (PPM notifications).
    // Signature: (deviceId, characteristicId, value, notificationTypeIndex?)
    UniversalBle.onValueChange =
        (String deviceId, String charId, Uint8List value, int? _) {
      if (_device?.deviceId != deviceId) return;
      
      // LOG EVERYTHING for debugging iOS
      LogService.instance.log('[BLE] Notification received: ID=$charId size=${value.length}');

      // Robust check: compare normalized strings (lowercase, no dashes)
      if (_normalizeUuid(charId) != _normalizeUuid(ppmCharUuid)) return;

      LogService.instance.log('[BLE] PPM notification match found. Raw: $value');
      if (value.length >= 4) {
        final ppm = value.buffer.asByteData().getFloat32(0, Endian.little);
        LogService.instance.log('[BLE] PPM parsed: $ppm');
        sensorData.updatePpm(ppm);
      } else {
        LogService.instance.log('[BLE] PPM notification too short — ignored.');
      }
    };
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  @override
  void startScan() {
    LogService.instance.log('[BLE] startScan() → target: "$targetDeviceName"');
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _serviceReady = false;
    _skipSubscription = false;
    _isConnecting = false;

    UniversalBle.onScanResult = (BleDevice device) {
      LogService.instance.log(
        '[BLE] Scan result: "${device.name}" '
        '(${device.deviceId}) RSSI=${device.rssi}',
      );
      if (device.name == targetDeviceName && !_isConnecting) {
        _isConnecting = true;
        LogService.instance.log('[BLE] Target found — stopping scan and connecting.');
        UniversalBle.stopScan();
        _connect(device);
      }
    };

    // On web the service UUID must be declared so the browser allows access
    // after connection (Web Bluetooth API security requirement).
    UniversalBle.startScan(
      scanFilter: ScanFilter(
        withNamePrefix: [targetDeviceName],
        withServices: kIsWeb ? [serviceUuid] : [],
      ),
      platformConfig: PlatformConfig(
        web: WebOptions(optionalServices: [serviceUuid]),
      ),
    );
    LogService.instance.log('[BLE] Scan started (web=$kIsWeb).');
  }

  @override
  void disconnect() {
    LogService.instance.log('[BLE] disconnect() called.');
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _cleanUp();
  }

  @override
  Future<void> setVolume(int volume) async {
    if (!_isConnected || _device == null) {
      LogService.instance.log('[BLE] setVolume($volume) skipped — not connected.');
      return;
    }
    if (!_serviceReady) {
      LogService.instance.log('[BLE] setVolume($volume) skipped — discovery not complete yet.');
      return;
    }
    final packet = Uint8List.fromList([_cmdVolume, volume.clamp(0, 100)]);
    LogService.instance.log('[BLE] setVolume($volume) → writing packet $packet');
    final ok = await _writeCommand(packet);
    if (ok) sensorData.updateVolume(volume);
  }

  @override
  Future<void> setWifiCredentials(String ssid, String pass) async {
    if (!_isConnected || _device == null) {
      LogService.instance.log('[BLE] setWifiCredentials() skipped — not connected.');
      return;
    }
    if (!_serviceReady) {
      LogService.instance.log('[BLE] setWifiCredentials() skipped — discovery not complete yet.');
      return;
    }
    // Build packet: [0x02, ...ssidBytes, 0x00, ...passBytes]
    final packet = Uint8List.fromList(
      [_cmdWifi, ...ssid.codeUnits, 0x00, ...pass.codeUnits],
    );
    LogService.instance.log(
      '[BLE] setWifiCredentials(ssid="$ssid") → '
      'packet length=${packet.length} bytes',
    );
    await _writeCommand(packet);
  }

  @override
  Future<void> setPpmThreshold(double ppm) async {
    if (!_isConnected || _device == null) {
      LogService.instance.log('[BLE] setPpmThreshold($ppm) skipped — not connected.');
      return;
    }
    if (!_serviceReady) {
      LogService.instance.log('[BLE] setPpmThreshold($ppm) skipped — discovery not complete yet.');
      return;
    }
    final clamped = ppm.clamp(0.0, 5.0);
    // Encode as IEEE 754 float32 little-endian (same as sensor PPM readings).
    final bytes = ByteData(4)..setFloat32(0, clamped, Endian.little);
    final packet = Uint8List.fromList(
      [_cmdThreshold, ...bytes.buffer.asUint8List()],
    );
    LogService.instance.log('[BLE] setPpmThreshold($clamped) → $packet');
    await _writeCommand(packet);
  }

  @override
  Future<void> setLcdContrast(int contrast) async {
    if (!_isConnected || _device == null) {
      LogService.instance.log('[BLE] setLcdContrast($contrast) skipped — not connected.');
      return;
    }
    if (!_serviceReady) {
      LogService.instance.log('[BLE] setLcdContrast($contrast) skipped — discovery not complete yet.');
      return;
    }
    final clamped = contrast.clamp(0, 100);
    final packet = Uint8List.fromList([_cmdContrast, clamped]);
    LogService.instance.log('[BLE] setLcdContrast($clamped) → $packet');
    await _writeCommand(packet);
    sensorData.updateLcdContrast(clamped);
  }

  @override
  void dispose() {
    LogService.instance.log('[BLE] dispose().');
    _cleanUp();
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Future<void> _connect(BleDevice device) async {
    _device = device;
    LogService.instance.log('[BLE] Connecting to ${device.deviceId}…');
    try {
      await UniversalBle.connect(device.deviceId);
      // connect() completes after onConnectionChange fires with isConnected=true,
      // which has already triggered UI navigation. Now run discovery.
      LogService.instance.log('[BLE] connect() returned — discovering services…');
      await _discoverAndSubscribe();
    } catch (e) {
      LogService.instance.log('[BLE] _connect() ERROR: $e');
    }
  }

  Future<void> _discoverAndSubscribe() async {
    final device = _device;
    if (device == null) return;

    try {
      var services = await UniversalBle.discoverServices(device.deviceId);
      LogService.instance.log('[BLE] Discovered ${services.length} service(s).');

      // nRF Connect sometimes needs a moment to make its GATT server
      // available after a connection. Retry once if we get an empty list.
      if (services.isEmpty && _isConnected) {
        LogService.instance.log('[BLE] 0 services found — retrying after 1.5 s…');
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (!_isConnected) return; // Disconnected during delay.
        services = await UniversalBle.discoverServices(device.deviceId);
        LogService.instance.log('[BLE] Retry discovered ${services.length} service(s).');
      }

      bool foundService = false;
      for (final s in services) {
        LogService.instance.log('[BLE]   Service: ${s.uuid}');
        if (_normalizeUuid(s.uuid) == _normalizeUuid(serviceUuid)) {
          foundService = true;
          for (final c in s.characteristics) {
            LogService.instance.log('[BLE]     Char: ${c.uuid} props=${c.properties}');
          }
          if (!_skipSubscription) {
            await _subscribeToPpm(device.deviceId);
          } else {
            LogService.instance.log('[BLE] Skipping subscription (previously caused GATT invalidation).');
          }
          break;
        }
      }

      if (!foundService) {
        LogService.instance.log('[BLE] WARNING: Target service not found! Is the nRF Connect GATT Server ON?');
      }
    } catch (e) {
      LogService.instance.log('[BLE] _discoverAndSubscribe() ERROR: $e');
    }

    // Only unlock writes if the device is still connected.
    // If disconnected during discovery, leave _serviceReady=false so
    // the reconnect cycle starts fresh.
    if (_isConnected) {
      _serviceReady = true;
      LogService.instance.log('[BLE] Service ready — writes enabled.');
    } else {
      LogService.instance.log('[BLE] Discovery ended while disconnected — writes NOT enabled.');
    }
  }

  /// Attempts to enable PPM notifications (then indications as fallback).
  ///
  /// **Chrome Web Bluetooth quirk**: when `startNotifications()` fails, Chrome
  /// marks the current GATT service reference as stale. Subsequent writes to
  /// the same service fail with "GATT operation failed for unknown reason".
  ///
  /// Fix: after any subscription failure on web, we call `discoverServices()`
  /// again to obtain fresh GATT handles before returning, so writes still work.
  Future<void> _subscribeToPpm(String deviceId) async {
    LogService.instance.log('[BLE] Subscribing to PPM notifications…');

    // Try notifications first.
    try {
      await UniversalBle.subscribeNotifications(
        deviceId,
        serviceUuid,
        ppmCharUuid,
      );
      LogService.instance.log('[BLE] PPM notifications subscribed successfully.');
      return;
    } catch (e) {
      LogService.instance.log('[BLE] subscribeNotifications failed: $e');
    }

    // Fallback: try indications.
    try {
      await UniversalBle.subscribeIndications(
        deviceId,
        serviceUuid,
        ppmCharUuid,
      );
      LogService.instance.log('[BLE] PPM indications subscribed (fallback).');
      return;
    } catch (e) {
      LogService.instance.log('[BLE] subscribeIndications also failed: $e');
    }

    // Both subscription attempts failed — the platform has likely invalidated
    // its internal GATT session (Chrome does this, WinRT does this too).
    // Re-discovering services gets fresh GATT handles so writes still work.
    LogService.instance.log('[BLE] Re-discovering services to refresh GATT handles after subscription failure…');
    try {
      await UniversalBle.discoverServices(deviceId);
      LogService.instance.log('[BLE] GATT handles refreshed — writes will work without PPM notifications.');
    } catch (e) {
      LogService.instance.log('[BLE] Re-discovery failed: $e');
    }

    _skipSubscription = true;
    LogService.instance.log(
      '[BLE] PPM auto-update unavailable.\n'
      'nRF Connect fix: add a CCCD descriptor (UUID 0x2902) to the PPM characteristic.',
    );
  }

  /// Writes [packet] to the command characteristic.
  ///
  /// Web Bluetooth (and WinRT) stale GATT handles after the first write.
  /// Fix: always re-fetch the service + characteristic via [discoverServices]
  /// before every write. Inelegant but reliable — the BLE stack needs coffee.
  ///
  /// Also waits 150 ms after each write so the stack can breathe between
  /// rapid slider events.
  Future<bool> _writeCommand(Uint8List packet) async {
    final device = _device;
    if (device == null || !_isConnected) return false;

    try {
      // Re-fetch service/characteristic handles before every write.
      // (Required on Web due to a Chrome GATT invalidation bug, but massive overhead on Native)
      if (kIsWeb) {
        await UniversalBle.discoverServices(device.deviceId);
      }

      // Attempt 1: Write With Response.
      await UniversalBle.write(device.deviceId, serviceUuid, cmdCharUuid, packet);
      LogService.instance.log('[BLE] Write OK.');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return true;
    } catch (e) {
      LogService.instance.log('[BLE] Write (with response) failed: $e — trying without response…');
    }

    // Attempt 2: Write Without Response (for peripherals that support it).
    if (!_isConnected) return false;
    try {
      await UniversalBle.write(
        device.deviceId, serviceUuid, cmdCharUuid, packet,
        withoutResponse: true,
      );
      LogService.instance.log('[BLE] Write Without Response OK.');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return true;
    } catch (e) {
      LogService.instance.log('[BLE] All write attempts failed: $e');
      return false;
    }
  }


  void _cleanUp() {
    UniversalBle.stopScan().catchError((Object e) {
      LogService.instance.log('[BLE] stopScan error (ignored): $e');
    });

    final device = _device;
    _device = null;
    _isConnected = false;
    _serviceReady = false;
    _skipSubscription = false;
    _isConnecting = false;

    if (device != null) {
      UniversalBle.disconnect(device.deviceId).catchError((Object e) {
        LogService.instance.log('[BLE] disconnect error (ignored): $e');
      });
    }
  }

  /// Normalizes UUIDs for robust comparison across platforms.
  /// iOS, Web, and Windows often format the same UUID differently.
  String _normalizeUuid(String uuid) {
    return uuid.toLowerCase().replaceAll('-', '').replaceAll('0x', '');
  }
}
