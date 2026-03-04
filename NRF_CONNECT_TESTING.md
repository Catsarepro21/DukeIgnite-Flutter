# Testing with nRF Connect

This document provides instructions on how to test your app with the nRF Connect for Mobile app, even if you don't have the physical sensor hardware.

You will use nRF Connect's "Server" functionality to simulate the Formaldehyde Sensor.

## 1. Prerequisites

*   Two Android or iOS devices, both with the [nRF Connect for Mobile](https://www.nordicsemi.com/Software-and-tools/Development-Tools/nRF-Connect-for-mobile) app installed.
    *   **Device A:** Will simulate the sensor (the "Server").
    *   **Device B:** Will run your Flutter app to connect to the simulated sensor.
    *   *Note: If you are testing on the Android Emulator, you can use your physical phone as Device A and the emulator as Device B.*

## 2. Simulating the Sensor (on Device A)

1.  Open nRF Connect and go to the **"Server"** tab.
2.  Tap **"Add configuration"**. You can leave the default name or call it "Formaldehyde Sensor".
3.  **Add Service:**
    *   Tap **"ADD SERVICE"**.
    *   Select the **"Custom Service"** tab.
    *   **Service UUID:** `0000FFFF-0000-1000-8000-00805F9B34FB`
    *   **Description:** `Formaldehyde Service`.
    *   Tap **"OK"**.

4.  **Add Characteristics:** Now, add the following four characteristics to the service you just created.

    *   **PPM Level Characteristic:**
        *   Tap **"ADD CHARACTERISTIC"** inside your new service.
        *   Select the **"Custom Characteristic"** tab.
        *   **UUID:** `0000EEE1-0000-1000-8000-00805F9B34FB`
        *   **Description:** `PPM Level`
        *   **Properties:** Select **`Notify`**.
        *   **Permissions:** Leave as default (`Read/Write`).
        *   **Initial Value:** Set Type to `byte array` and enter the value `0000003F`. (This is the 4-byte little-endian representation of the float value 0.5).
        *   Tap **"OK"**.

    *   **Volume Characteristic:**
        *   Tap **"ADD CHARACTERISTIC"**.
        *   **UUID:** `0000EEE2-0000-1000-8000-00805F9B34FB`
        *   **Description:** `Volume`
        *   **Properties:** Select **`Write`**.
        *   **Permissions:** Leave as default (`Read/Write`).
        *   **Initial Value:** Select `unsigned...` and then `UINT8`. Enter an initial value like `50`.
        *   Tap **"OK"**.

    *   **Wi-Fi SSID Characteristic:**
        *   Tap **"ADD CHARACTERISTIC"**.
        *   **UUID:** `0000EEE3-0000-1000-8000-00805F9B34FB`
        *   **Description:** `Wi-Fi SSID`
        *   **Properties:** Select **`Write`**.
        *   **Permissions:** Leave as default (`Read/Write`).
        *   **Initial Value:** Set Type to `UTF-8` and enter a placeholder like `MyWiFi`.
        *   Tap **"OK"**.

    *   **Wi-Fi Password Characteristic:**
        *   Tap **"ADD CHARACTERISTIC"**.
        *   **UUID:** `0000EEE4-0000-1000-8000-00805F9B34FB`
        *   **Description:** `Wi-Fi Password`
        *   **Properties:** Select **`Write`**.
        *   **Permissions:** Leave as default (`Read/Write`).
        *   **Initial Value:** Set Type to `UTF-8` and enter a placeholder like `password123`.
        *   Tap **"OK"**.

5.  Go back to the **"Advertiser"** tab in nRF Connect.
6.  Tap the menu icon (3 dots) and select your "Formaldehyde Sensor" configuration.
7.  Change the **"Device name"** under "Advertising data" to **`FormaldehydeSensor`**.
8.  Turn on the advertiser by tapping the toggle switch.

Device A is now simulating your sensor and is ready for a connection.

## 3. Connecting Your App (on Device B)

Now, open your Flutter app on Device B. When you tap "Start Scan", it will find the "FormaldehydeSensor" being advertised by Device A, connect, and you can proceed with testing.
