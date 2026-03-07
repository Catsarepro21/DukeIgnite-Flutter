# Arduino MKR 1010 BLE Guide

This guide provides the UUIDs and a sample Arduino sketch to make your hardware compatible with the Formaldehyde Monitor Flutter app.

## 🔑 BLE UUIDs

Use these exact strings in your Arduino code:

| Feature | UUID | Direction | Notes |
| :--- | :--- | :--- | :--- |
| **Service** | `0000FFFF-0000-1000-8000-00805F9B34FB` | — | Custom Service |
| **PPM** | `0000EEE1-0000-1000-8000-00805F9B34FB` | Sensor → App (Notify) | 4-byte little-endian float |
| **Command** | `0000EEE2-0000-1000-8000-00805F9B34FB` | App → Sensor (Write) | Packet-based, see below |

> **Note:** The app was previously using 4 characteristics (volume, SSid, password, ppm).
> These have been consolidated into **2 characteristics** (ppm + cmd) to keep the GATT table
> minimal and reduce the number of writes.

---

## 📦 Command Characteristic Packet Format

The app sends binary packets on the **Command** characteristic (`EEE2`).
Read the first byte to determine the command:

| Command | Byte 0 | Remaining bytes | Description |
| :--- | :--- | :--- | :--- |
| Set Volume | `0x01` | `[volume]` (0–100) | Set buzzer volume |
| Set Wi-Fi | `0x02` | `[...ssidBytes, 0x00, ...passBytes]` | SSID + null separator + password |

**Volume example:** `{0x01, 75}` → set volume to 75  
**Wi-Fi example:** `{0x02, 'M','y','W','i','F','i', 0x00, 'p','a','s','s'}` → SSID=MyWiFi, pass=pass

---

## 🛠 Sample Arduino Sketch (ArduinoBLE)

Install the **ArduinoBLE** library from the Library Manager.

```cpp
#include <ArduinoBLE.h>

// UUIDs
const char* serviceUuid = "0000FFFF-0000-1000-8000-00805F9B34FB";
const char* ppmUuid     = "0000EEE1-0000-1000-8000-00805F9B34FB";
const char* cmdUuid     = "0000EEE2-0000-1000-8000-00805F9B34FB";

BLEService sensorService(serviceUuid);

// PPM: 4-byte little-endian float, notified to the app
BLEFloatCharacteristic ppmChar(ppmUuid, BLERead | BLENotify);

// Command: variable-length byte array written by the app
BLECharacteristic cmdChar(cmdUuid, BLEWrite, 64 /*max bytes*/);

int currentVolume = 50;
String wifiSsid = "";
String wifiPass = "";

void handleCommand(const uint8_t* data, int len) {
  if (len < 1) return;
  uint8_t cmd = data[0];

  if (cmd == 0x01 && len >= 2) {
    // Set volume
    currentVolume = data[1];
    Serial.print("Volume set to: ");
    Serial.println(currentVolume);

  } else if (cmd == 0x02 && len >= 2) {
    // Set Wi-Fi: find null separator
    int sep = -1;
    for (int i = 1; i < len; i++) {
      if (data[i] == 0x00) { sep = i; break; }
    }
    if (sep > 0) {
      wifiSsid = String((const char*)(data + 1)).substring(0, sep - 1);
      wifiPass = (sep + 1 < len) ? String((const char*)(data + sep + 1)) : "";
      Serial.print("WiFi SSID: "); Serial.println(wifiSsid);
      Serial.print("WiFi Pass: "); Serial.println(wifiPass);
      // TODO: call WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
    }
  }
}

void setup() {
  Serial.begin(9600);
  if (!BLE.begin()) {
    Serial.println("BLE init failed!");
    while (1);
  }

  BLE.setLocalName("FormaldehydeSensor"); // Must match app exactly!
  BLE.setAdvertisedService(sensorService);
  sensorService.addCharacteristic(ppmChar);
  sensorService.addCharacteristic(cmdChar);
  BLE.addService(sensorService);

  ppmChar.writeValue(0.0f);
  BLE.advertise();
  Serial.println("Sensor advertising...");
}

void loop() {
  BLEDevice central = BLE.central();
  if (!central) return;

  Serial.print("Connected: ");
  Serial.println(central.address());

  while (central.connected()) {
    // Replace with real sensor reading
    float mockPpm = (float)random(0, 50) / 10.0f;
    ppmChar.writeValue(mockPpm);

    if (cmdChar.written()) {
      handleCommand(cmdChar.value(), cmdChar.valueLength());
    }
    delay(2000);
  }
  Serial.println("Disconnected.");
}
```

---

## 💡 Troubleshooting

- **Device Name**: `BLE.setLocalName("FormaldehydeSensor")` must match exactly — the app uses this to find the device.
- **PPM Format**: The app expects a 4-byte little-endian IEEE 754 float. `BLEFloatCharacteristic` generates this automatically.
- **Command length**: Max packet is 64 bytes (covers long SSIDs/passwords). Adjust if needed.
