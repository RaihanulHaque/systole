import 'package:flutter_test/flutter_test.dart';
import 'package:systole/ble/protocol.dart';
import 'package:systole/models/bp_category.dart';
import 'package:systole/services/waveform_buffer.dart';

void main() {
  group('PpgPacket', () {
    test('round-trips u16 samples', () {
      const p = PpgPacket(513, [0, 2048, 4095]);
      final parsed = PpgPacket.parse(p.encode())!;
      expect(parsed.seq, 513);
      expect(parsed.samples, [0, 2048, 4095]);
    });

    test('parses u32 samples (e.g. 18-bit MAX30101)', () {
      final bytes = [
        0x01, 0x00, PpgPacket.formatU32, 2, //
        0xFF, 0xFF, 0x03, 0x00, // 262143
        0x10, 0x00, 0x00, 0x00, // 16
      ];
      final p = PpgPacket.parse(bytes)!;
      expect(p.samples, [262143, 16]);
    });

    test('ignores a count longer than the payload', () {
      final p = PpgPacket.parse([0, 0, 0, 5, 1, 0])!;
      expect(p.samples, [1]);
    });

    test('rejects short packets', () {
      expect(PpgPacket.parse([1, 2]), isNull);
    });
  });

  group('BpResult', () {
    test('round-trips and decodes flags', () {
      const r = BpResult(
        deviceMs: 123456,
        sbp: 121.4,
        dbp: 78.9,
        hr: 66,
        quality: 91,
        flags: BpResult.flagCalibrated | BpResult.flagMotion,
      );
      final p = BpResult.parse(r.encode())!;
      expect(p.deviceMs, 123456);
      expect(p.sbp, closeTo(121.4, 0.01));
      expect(p.dbp, closeTo(78.9, 0.01));
      expect(p.hr, 66);
      expect(p.quality, 91);
      expect(p.calibrated, isTrue);
      expect(p.motion, isTrue);
      expect(p.lowQuality, isFalse);
    });
  });

  test('DeviceInfo parses', () {
    final i = DeviceInfo.parse([100, 0, 1, 2, 5, 1])!;
    expect(i.sampleRateHz, 100);
    expect(i.firmware, '1.2');
    expect(i.modelVersion, 5);
    expect(i.calibrated, isTrue);
  });

  test('profile and calibration encoding', () {
    expect(
      encodeProfile(age: 25, isMale: false, heightCm: 165.5, weightKg: 60),
      [25, 0, 0x77, 0x06, 0x58, 0x02],
    );
    expect(encodeCalibration(120, 80), [0xB0, 0x04, 0x20, 0x03]);
  });

  test('BP categories', () {
    expect(BpCategory.of(115, 75), BpCategory.normal);
    expect(BpCategory.of(125, 75), BpCategory.elevated);
    expect(BpCategory.of(118, 84), BpCategory.stage1);
    expect(BpCategory.of(145, 85), BpCategory.stage2);
    expect(BpCategory.of(190, 100), BpCategory.crisis);
  });

  test('WaveformBuffer removes DC offset and wraps', () {
    final b = WaveformBuffer(sampleRate: 10, seconds: 2);
    b.addAll(List.filled(50, 3000));
    expect(b.length, 20);
    expect(b[b.length - 1].abs(), lessThan(1));
  });
}
