abstract class BleService {
  void startScan();
  void disconnect();
  void dispose(); // Add dispose method for cleanup
  Future<void> setVolume(int volume);
  Future<void> setWifiCredentials(String ssid, String pass);
}
