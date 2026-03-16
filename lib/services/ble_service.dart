/// Abstract BLE service interface.
abstract class BleService {
  void startScan();
  void disconnect();
  void dispose();
  Future<void> setVolume(int volume);
  Future<void> setWifiCredentials(String ssid, String pass);

  /// Sends the PPM alarm threshold to the sensor (0.0–5.0 ppm, sent as float32 LE).
  Future<void> setPpmThreshold(double ppm);

  /// Sends LCD contrast level to the sensor (0–100).
  Future<void> setLcdContrast(int contrast);
}
