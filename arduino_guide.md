# Arduino BLE Guide — Formaldehyde Monitor

Compatible with any board running **ArduinoBLE** (MKR WiFi 1010, Nano 33 IoT, Nano 33 BLE, etc.)

---

## 🔑 BLE UUIDs

```cpp
const char* SERVICE_UUID   = "0000FFFF-0000-1000-8000-00805F9B34FB";
const char* PPM_UUID        = "0000EEE1-0000-1000-8000-00805F9B34FB";
const char* CMD_UUID        = "0000EEE2-0000-1000-8000-00805F9B34FB";
```

| Characteristic | UUID | Direction | Format |
|---|---|---|---|
| **Service** | `FFFF` | — | — |
| **PPM** | `EEE1` | Sensor → App | 4-byte little-endian IEEE 754 float |
| **Command** | `EEE2` | App → Sensor | Binary packet (see below) |

---

## 📦 Command Packets (EEE2)

The app writes to EEE2. First byte is always the command type:

| Cmd | Byte 0 | Remaining bytes | Description |
|---|---|---|---|
| Set Volume | `0x01` | `[vol]` — uint8 (0–100) | Buzzer volume |
| Set Wi-Fi | `0x02` | `[...ssid, 0x00, ...pass]` | SSID + null + password |
| PPM Threshold | `0x03` | `[b0,b1,b2,b3]` — float32 LE (0.0–5.0 ppm) | Alarm trigger level |
| LCD Contrast | `0x04` | `[contrast]` — uint8 (0–100) | LCD contrast % |

**Examples:**
```
Volume 75%:         {0x01, 75}
WiFi MyNet/pass:    {0x02, 'M','y','N','e','t', 0x00, 'p','a','s','s'}
Threshold 0.5 ppm:  {0x03, 0x00, 0x00, 0x00, 0x3F}   // 0.5f little-endian
Contrast 60%:       {0x04, 60}
```

---

## 🛠 Full Arduino Sketch

Install **ArduinoBLE** from the Library Manager (`Sketch → Include Library → Manage Libraries`).

```cpp
#include <ArduinoBLE.h>

// ── UUIDs ────────────────────────────────────────────────────────────────────
const char* SERVICE_UUID = "0000FFFF-0000-1000-8000-00805F9B34FB";
const char* PPM_UUID     = "0000EEE1-0000-1000-8000-00805F9B34FB";
const char* CMD_UUID     = "0000EEE2-0000-1000-8000-00805F9B34FB";

BLEService sensorService(SERVICE_UUID);

// PPM: 4-byte little-endian float, BLEFloatCharacteristic handles encoding
BLEFloatCharacteristic ppmChar(PPM_UUID, BLERead | BLENotify);

// Command: up to 64 bytes, written by the app
BLECharacteristic cmdChar(CMD_UUID, BLEWrite | BLEWriteWithoutResponse, 64);

// ── State ─────────────────────────────────────────────────────────────────────
int   currentVolume    = 50;      // 0–100
float ppmThreshold     = 0.5f;   // ppm, alarm triggers above this
int   lcdContrast      = 50;     // 0–100
String wifiSsid        = "";
String wifiPass        = "";

// ── Helper: read float32 little-endian from 4 bytes ──────────────────────────
float readFloat32LE(const uint8_t* b) {
  float f;
  memcpy(&f, b, 4);   // Arduino is little-endian — direct copy works
  return f;
}

// ── Command dispatcher ────────────────────────────────────────────────────────
void handleCommand(const uint8_t* data, int len) {
  if (len < 1) return;

  switch (data[0]) {

    case 0x01:  // ── Set Volume ─────────────────────────────────────────────
      if (len >= 2) {
        currentVolume = data[1];
        Serial.print("[CMD] Volume → "); Serial.println(currentVolume);
        // TODO: analogWrite(BUZZER_PIN, map(currentVolume, 0, 100, 0, 255));
      }
      break;

    case 0x02:  // ── Set Wi-Fi ──────────────────────────────────────────────
      if (len >= 2) {
        // Find the null separator between SSID and password
        int sep = -1;
        for (int i = 1; i < len; i++) {
          if (data[i] == 0x00) { sep = i; break; }
        }
        if (sep > 0) {
          wifiSsid = "";
          for (int i = 1; i < sep; i++) wifiSsid += (char)data[i];
          wifiPass = "";
          for (int i = sep + 1; i < len; i++) wifiPass += (char)data[i];
          Serial.print("[CMD] WiFi SSID: "); Serial.println(wifiSsid);
          Serial.print("[CMD] WiFi Pass: "); Serial.println(wifiPass);
          // TODO: WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
        }
      }
      break;

    case 0x03:  // ── Set PPM Threshold ──────────────────────────────────────
      if (len >= 5) {
        ppmThreshold = readFloat32LE(data + 1);
        Serial.print("[CMD] PPM threshold → "); Serial.println(ppmThreshold);
      }
      break;

    case 0x04:  // ── Set LCD Contrast ───────────────────────────────────────
      if (len >= 2) {
        lcdContrast = data[1];
        Serial.print("[CMD] LCD contrast → "); Serial.println(lcdContrast);
        // TODO: analogWrite(LCD_CONTRAST_PIN, map(lcdContrast, 0, 100, 0, 255));
      }
      break;

    default:
      Serial.print("[CMD] Unknown command: 0x");
      Serial.println(data[0], HEX);
  }
}

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);
  if (!BLE.begin()) {
    Serial.println("BLE init failed!");
    while (1);
  }

  BLE.setLocalName("FormaldehydeSensor");  // ← must match app exactly
  BLE.setAdvertisedService(sensorService);
  sensorService.addCharacteristic(ppmChar);
  sensorService.addCharacteristic(cmdChar);
  BLE.addService(sensorService);

  ppmChar.writeValue(0.0f);
  BLE.advertise();
  Serial.println("Advertising as FormaldehydeSensor...");
}

// ── Loop ──────────────────────────────────────────────────────────────────────
void loop() {
  BLEDevice central = BLE.central();
  if (!central) return;

  Serial.print("Connected: "); Serial.println(central.address());

  while (central.connected()) {
    // ── Read real sensor (replace with actual sensor code) ──────────────────
    float ppm = readSensor();  // e.g. 0.037f for 37 ppb
    ppmChar.writeValue(ppm);   // notifies the app automatically

    // ── Check for incoming commands ─────────────────────────────────────────
    if (cmdChar.written()) {
      handleCommand(cmdChar.value(), cmdChar.valueLength());
    }

    // ── Optional: trigger alarm if above threshold ──────────────────────────
    if (ppm >= ppmThreshold) {
      // TODO: activate buzzer / LED
    }

    delay(2000);  // send PPM every 2 s
  }

  Serial.println("Disconnected.");
  BLE.advertise();  // restart advertising after disconnect
}

// ── Replace this with your actual sensor read ─────────────────────────────────
float readSensor() {
  // Example: MQ-138 on analog pin A0
  // float voltage = analogRead(A0) * (3.3 / 1023.0);
  // return voltage * SOME_CALIBRATION_FACTOR;
  return (float)random(0, 500) / 1000.0f; // remove — mock only
}
```

---

## 💡 Troubleshooting

| Problem | Fix |
|---|---|
| App can't find device | Check `BLE.setLocalName("FormaldehydeSensor")` matches exactly (case-sensitive) |
| PPM not updating | `BLEFloatCharacteristic` with `BLENotify` is required; plain `BLECharacteristic` won't notify |
| Write commands not received | Add `BLEWriteWithoutResponse` to `cmdChar` properties (app tries both write types) |
| PPM value wrong endianness | `BLEFloatCharacteristic.writeValue(float)` handles little-endian automatically — don't encode manually |
| Alarm doesn't trigger | Compare `ppm >= ppmThreshold` — threshold arrives as float32 LE from the app |

## 📐 PPM Sensor Data Format

The app reads EEE1 as a **4-byte little-endian IEEE 754 float**.

```
50.0 ppm → bytes: 00 00 48 42
 0.5 ppm → bytes: 00 00 00 3F
0.037 ppm → bytes: 17 B7 17 3D
```

`BLEFloatCharacteristic` encodes this automatically — just call `writeValue(float)`.