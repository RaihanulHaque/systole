# Systole

Flutter app (iOS and Android) for **continuous cuffless blood pressure monitoring**. A wrist PPG
sensor on a Seeed XIAO nRF52840 runs the BP model on the device and streams the raw pulse
waveform and the SBP/DBP estimates to the phone over Bluetooth Low Energy.

> Research prototype. Estimates are not a medical diagnosis.

## Features

- **Connect**: scans for sensors advertising the Systole BLE service, shows signal strength, and
  reconnects automatically if the link drops.
- **Live monitor**: large SBP/DBP readout with the AHA category, heart rate, signal quality and
  motion warnings, a live PPG waveform (display-filtered 0.5–8 Hz), and a trend chart.
- **Calibration**: enter a cuff reading and send it to the sensor as the model's baseline, or keep
  it only as a reference reading for validation.
- **Profile**: age, sex, height and weight (the model's demographic inputs) are saved on the phone
  and sent to the sensor on every connect.
- **Recording**: saves BP readings, cuff references and the **raw PPG samples** for each session.
  Keeps the screen awake while recording and checkpoints to disk every 15 s.
- **History and export**: per-session stats and chart; exports `readings.csv`,
  `cuff_references.csv`, `ppg.csv` and `meta.json` through the system share sheet, for training
  or validating the model.
- **Demo sensor**: a built-in simulator (synthetic 100 Hz PPG plus BP) so the app works without
  hardware.

## Run

```bash
flutter pub get
flutter run            # on a connected phone; BLE does not work in the iOS simulator
```

Use **Try with a demo sensor** on the Monitor tab (or in the scan screen) to test without hardware.

```bash
flutter test           # protocol encoding/decoding, BP categories, waveform buffer, smoke test
flutter build apk      # Android
flutter build ios      # iOS (needs signing for a real device)
```

## Hardware contract

The BLE GATT protocol (UUIDs, packet layouts, connection flow) is specified in
[PROTOCOL.md](PROTOCOL.md). [firmware/systole_xiao](firmware/systole_xiao/systole_xiao.ino) is an
untested reference sketch for the XIAO that implements the protocol, with a placeholder
`runModel()` where the real on-device model goes.

## Code map

```
lib/
  ble/
    protocol.dart        UUIDs, packet parse/encode (single source of truth for the wire format)
    bp_device.dart       device interface
    ble_bp_device.dart   real sensor over flutter_blue_plus
    demo_bp_device.dart  simulated sensor
  models/                UserProfile, Session/Reading/ReferenceReading, BP categories
  services/
    waveform_buffer.dart ring buffer + display filter for the live trace
    session_store.dart   sessions on disk, CSV export
  state/                 MonitorController (connection, live data, recording), Profile, History
  ui/                    screens and widgets
```

## Platform notes

- **Android**: the BLE permissions are in `AndroidManifest.xml`. `android/build.gradle.kts` raises
  plugin `compileSdk` to 36 because flutter_blue_plus 1.x still targets 33.
- **iOS**: `Info.plist` has the Bluetooth usage string and the `bluetooth-central` background
  mode, so BLE notifications keep arriving while the app is in the background.
- **Android background**: streaming continues while the app process is alive. For guaranteed
  long recordings with the screen off, add a foreground service (e.g. `flutter_foreground_task`).
