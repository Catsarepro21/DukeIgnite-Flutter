# Arduino MKR 1010 BLE Guide

This guide provides the necessary UUIDs and a sample Arduino sketch to make your hardware compatible with the Formaldehyde Monitor Flutter app.

## 🔑 Your Final UUIDs
Use these exact strings in your Arduino code to ensure the app can "see" and "talk" to the sensor.

| Feature | UUID | Data Type | Notes |
| :--- | :--- | :--- | :--- |
| **Service** | `0000FFFF-0000-1000-8000-00805F9B34FB` | - | Custom Service |
| **PPM** | `0000EEE1-0000-1000-8000-00805F9B34FB` | Float (4-byte) | Read/Notify |
| **Volume** | `0000EEE2-0000-1000-8000-00805F9B34FB` | Uint8 (1-byte) | Write |
| **SSID** | `0000EEE3-0000-1000-8000-00805F9B34FB` | String | Write |
| **Password** | `0000EEE4-0000-1000-8000-00805F9B34FB` | String | Write |

---

## 🛠 Sample Arduino Sketch (ArduinoBLE)
You will need to install the **ArduinoBLE** library from the Library Manager.

```cpp
#include <ArduinoBLE.h>

// Define UUIDs
const char* serviceUuid = "0000FFFF-0000-1000-8000-00805F9B34FB";
const char* ppmUuid     = "0000EEE1-0000-1000-8000-00805F9B34FB";
const char* volumeUuid  = "0000EEE2-0000-1000-8000-00805F9B34FB";

BLEService sensorService(serviceUuid);

// Float characteristic for PPM (Read + Notify)
BLEFloatCharacteristic ppmChar(ppmUuid, BLERead | BLENotify);

// Unsigned Char for volume (Write)
BLEUnsignedCharCharacteristic volumeChar(volumeUuid, BLEWrite);

void setup() {
  Serial.begin(9600);
  if (!BLE.begin()) {
    while (1);
  }

  BLE.setLocalName("FormaldehydeSensor"); // App searches for this exactly!
  BLE.setAdvertisedService(sensorService);

  sensorService.addCharacteristic(ppmChar);
  sensorService.addCharacteristic(volumeChar);
  BLE.addService(sensorService);

  ppmChar.writeValue(0.0);
  volumeChar.writeValue(50);

  BLE.advertise();
  Serial.println("Sensor is advertising...");
}

void loop() {
  BLEDevice central = BLE.central();
  if (central) {
    while (central.connected()) {
      float mockPpm = (float)random(0, 100) / 10.0;
      ppmChar.writeValue(mockPpm);
      
      if (volumeChar.written()) {
        int newVol = volumeChar.value();
        Serial.print("New Volume: ");
        Serial.println(newVol);
      }
      delay(2000);
    }
  }
}
```

## 💡 Troubleshooting
*   **Device Name**: Ensure `BLE.setLocalName("FormaldehydeSensor");` is exactly as written, as the Flutter app uses this to find the device.
*   **Data Types**: The app expects `PPM` to be a 4-byte float. In ArduinoBLE, use `BLEFloatCharacteristic`.
