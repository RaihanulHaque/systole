# Systole BLE protocol v1

Contract between the sensor firmware (XIAO nRF52840 or any BLE peripheral) and the Systole app.
The app implementation is `lib/ble/protocol.dart`. Change both together.

All multi-byte fields are **little-endian**. The device is a GATT peripheral that advertises the
Systole service UUID (the app filters its scan on it) and a name such as `Systole-XXXX`.

## Service

| | UUID |
|---|---|
| Systole service | `7d2a0001-6c3b-4e5f-8a9b-0c1d2e3f4a5b` |
| Battery service (standard, optional) | `0x180F`, Battery Level `0x2A19` (read + notify, 0–100) |

## Characteristics

| Name | UUID | Props | Direction |
|---|---|---|---|
| PPG stream | `7d2a0002-…` | Notify | device → app |
| BP result | `7d2a0003-…` | Notify | device → app |
| Device info | `7d2a0004-…` | Read | device → app |
| User profile | `7d2a0005-…` | Write | app → device |
| Calibration | `7d2a0006-…` | Write | app → device |
| Control point | `7d2a0007-…` | Write | app → device |

(`…` = `-6c3b-4e5f-8a9b-0c1d2e3f4a5b`)

### PPG stream (notify)

Raw sensor samples in batches, sent continuously while streaming is on.

| Offset | Type | Field |
|---|---|---|
| 0 | u16 | `seq`: packet counter, +1 per packet, wraps at 65535 |
| 2 | u8 | `format`: 0 = u16 samples, 1 = u32 samples (e.g. 18-bit MAX30101) |
| 3 | u8 | `count`: number of samples that follow |
| 4 | u16[count] or u32[count] | samples, oldest first |

Keep the packet within `MTU - 3` bytes. The app requests a 512-byte MTU on Android; iOS
typically negotiates 185. 20 × u16 samples (44 bytes) fits everywhere except the 23-byte default.
The app uses `seq` gaps to count lost packets and shows the loss rate.

### BP result (notify)

One estimate from the on-device model, e.g. every beat or every few seconds.

| Offset | Type | Field |
|---|---|---|
| 0 | u32 | `device_ms`: device uptime in ms |
| 4 | u16 | SBP × 10 (mmHg) |
| 6 | u16 | DBP × 10 (mmHg) |
| 8 | u8 | heart rate (bpm) |
| 9 | u8 | signal quality 0–100 |
| 10 | u8 | flags: bit0 calibrated, bit1 motion detected, bit2 low quality |
| 11 | u8 | reserved (0) |

### Device info (read)

| Offset | Type | Field |
|---|---|---|
| 0 | u16 | PPG sample rate (Hz) |
| 2 | u8 | firmware major |
| 3 | u8 | firmware minor |
| 4 | u8 | model version |
| 5 | u8 | flags: bit0 calibrated |

### User profile (write)

Sent on every connect and whenever the user saves their profile. These are the demographic
inputs of the model (`age, is_male, height, weight`; the device derives BMI).

| Offset | Type | Field |
|---|---|---|
| 0 | u8 | age (years) |
| 1 | u8 | sex: 0 female, 1 male |
| 2 | u16 | height (cm × 10) |
| 4 | u16 | weight (kg × 10) |

### Calibration (write)

A cuff reading taken by the user. The device should use the current PPG window as the
calibration clip and these values as `baseline_sbp` / `baseline_dbp`, then set the calibrated flag.

| Offset | Type | Field |
|---|---|---|
| 0 | u16 | SBP × 10 |
| 2 | u16 | DBP × 10 |

### Control point (write, 1 byte)

| Op | Meaning |
|---|---|
| `0x01` | start streaming (the app sends this after connecting) |
| `0x02` | stop streaming (sent before a deliberate disconnect) |
| `0x03` | clear calibration |

## Connection flow (app side)

1. Scan filtered by the service UUID, connect, request MTU 512 (Android).
2. Discover services, read Device info, subscribe to PPG and BP result (and Battery).
3. Write Control `0x01`, then write User profile.
4. On an unexpected disconnect the app retries every 3 s until the user disconnects.
