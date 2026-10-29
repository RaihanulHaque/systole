// Systole BLE protocol v1. Wire format is documented in PROTOCOL.md; keep the
// two in sync. All multi-byte fields are little-endian.

import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SystoleUuids {
  static final service = Guid('7d2a0001-6c3b-4e5f-8a9b-0c1d2e3f4a5b');
  static final ppg = Guid('7d2a0002-6c3b-4e5f-8a9b-0c1d2e3f4a5b');
  static final bp = Guid('7d2a0003-6c3b-4e5f-8a9b-0c1d2e3f4a5b');
  static final info = Guid('7d2a0004-6c3b-4e5f-8a9b-0c1d2e3f4a5b');
  static final profile = Guid('7d2a0005-6c3b-4e5f-8a9b-0c1d2e3f4a5b');
  static final calibration = Guid('7d2a0006-6c3b-4e5f-8a9b-0c1d2e3f4a5b');
  static final control = Guid('7d2a0007-6c3b-4e5f-8a9b-0c1d2e3f4a5b');

  // Standard Bluetooth SIG Battery Service.
  static final batteryService = Guid('180f');
  static final batteryLevel = Guid('2a19');
}

/// A batch of raw sensor samples (PPG / ADC counts).
class PpgPacket {
  final int seq;
  final List<int> samples;
  const PpgPacket(this.seq, this.samples);

  static const formatU16 = 0;
  static const formatU32 = 1;

  /// `[u16 seq][u8 format][u8 count][samples...]`
  static PpgPacket? parse(List<int> bytes) {
    if (bytes.length < 4) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    final seq = d.getUint16(0, Endian.little);
    final format = d.getUint8(2);
    final count = d.getUint8(3);
    final width = format == formatU32 ? 4 : 2;
    final available = (bytes.length - 4) ~/ width;
    final n = count < available ? count : available;
    final samples = List<int>.generate(
      n,
      (i) => width == 4
          ? d.getUint32(4 + i * 4, Endian.little)
          : d.getUint16(4 + i * 2, Endian.little),
    );
    return PpgPacket(seq, samples);
  }

  List<int> encode() {
    final d = ByteData(4 + samples.length * 2);
    d.setUint16(0, seq & 0xFFFF, Endian.little);
    d.setUint8(2, formatU16);
    d.setUint8(3, samples.length);
    for (var i = 0; i < samples.length; i++) {
      d.setUint16(4 + i * 2, samples[i], Endian.little);
    }
    return d.buffer.asUint8List();
  }
}

/// One blood-pressure estimate produced by the on-device model.
class BpResult {
  final int deviceMs;
  final double sbp;
  final double dbp;
  final int hr;
  final int quality; // 0-100
  final int flags;

  const BpResult({
    required this.deviceMs,
    required this.sbp,
    required this.dbp,
    required this.hr,
    required this.quality,
    this.flags = 0,
  });

  static const flagCalibrated = 0x01;
  static const flagMotion = 0x02;
  static const flagLowQuality = 0x04;

  bool get calibrated => flags & flagCalibrated != 0;
  bool get motion => flags & flagMotion != 0;
  bool get lowQuality => flags & flagLowQuality != 0;

  /// `[u32 deviceMs][u16 sbp*10][u16 dbp*10][u8 hr][u8 quality][u8 flags][u8 reserved]`
  static BpResult? parse(List<int> bytes) {
    if (bytes.length < 11) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    return BpResult(
      deviceMs: d.getUint32(0, Endian.little),
      sbp: d.getUint16(4, Endian.little) / 10.0,
      dbp: d.getUint16(6, Endian.little) / 10.0,
      hr: d.getUint8(8),
      quality: d.getUint8(9),
      flags: d.getUint8(10),
    );
  }

  List<int> encode() {
    final d = ByteData(12);
    d.setUint32(0, deviceMs, Endian.little);
    d.setUint16(4, (sbp * 10).round(), Endian.little);
    d.setUint16(6, (dbp * 10).round(), Endian.little);
    d.setUint8(8, hr);
    d.setUint8(9, quality);
    d.setUint8(10, flags);
    return d.buffer.asUint8List();
  }
}

/// Static device description, read once after connecting.
class DeviceInfo {
  final int sampleRateHz;
  final int fwMajor;
  final int fwMinor;
  final int modelVersion;
  final bool calibrated;

  const DeviceInfo({
    required this.sampleRateHz,
    required this.fwMajor,
    required this.fwMinor,
    required this.modelVersion,
    required this.calibrated,
  });

  String get firmware => '$fwMajor.$fwMinor';

  /// `[u16 sampleRateHz][u8 fwMajor][u8 fwMinor][u8 modelVersion][u8 flags]`
  static DeviceInfo? parse(List<int> bytes) {
    if (bytes.length < 6) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    return DeviceInfo(
      sampleRateHz: d.getUint16(0, Endian.little),
      fwMajor: d.getUint8(2),
      fwMinor: d.getUint8(3),
      modelVersion: d.getUint8(4),
      calibrated: d.getUint8(5) & 0x01 != 0,
    );
  }
}

/// Control-point opcodes.
class ControlOp {
  static const startStream = 0x01;
  static const stopStream = 0x02;
  static const clearCalibration = 0x03;
}

/// `[u8 age][u8 sex 0=female 1=male][u16 heightCm*10][u16 weightKg*10]`
List<int> encodeProfile({
  required int age,
  required bool isMale,
  required double heightCm,
  required double weightKg,
}) {
  final d = ByteData(6);
  d.setUint8(0, age.clamp(0, 255));
  d.setUint8(1, isMale ? 1 : 0);
  d.setUint16(2, (heightCm * 10).round().clamp(0, 0xFFFF), Endian.little);
  d.setUint16(4, (weightKg * 10).round().clamp(0, 0xFFFF), Endian.little);
  return d.buffer.asUint8List();
}

/// `[u16 sbp*10][u16 dbp*10]`
List<int> encodeCalibration(double sbp, double dbp) {
  final d = ByteData(4);
  d.setUint16(0, (sbp * 10).round(), Endian.little);
  d.setUint16(2, (dbp * 10).round(), Endian.little);
  return d.buffer.asUint8List();
}
