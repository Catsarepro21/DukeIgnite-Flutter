/// Abstract BLE service interface.
///
/// Implementations: [RealBleService] (Android/iOS) and
/// [UnsupportedBleService] (Linux/Windows platforms).
abstract class BleService {
  void startScan();
  void disconnect();
  void dispose();
  Future<void> setVolume(int volume);
  Future<void> setWifiCredentials(String ssid, String pass);
}
