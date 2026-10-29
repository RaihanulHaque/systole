import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/user_profile.dart';
import 'bp_device.dart';
import 'protocol.dart';

class NotSystoleDeviceException implements Exception {
  @override
  String toString() =>
      'This device does not expose the Systole BLE service. Check the firmware UUIDs.';
}

/// A Systole sensor (e.g. XIAO nRF52840) over Bluetooth Low Energy.
class BleBpDevice implements BpDevice {
  final BluetoothDevice device;
  final String _advertisedName;

  BleBpDevice(this.device, {String? advertisedName})
    : _advertisedName = advertisedName ?? '';

  final _link = StreamController<LinkState>.broadcast();
  final _ppg = StreamController<PpgPacket>.broadcast();
  final _results = StreamController<BpResult>.broadcast();
  final _battery = StreamController<int>.broadcast();
  final _subs = <StreamSubscription>[];

  BluetoothCharacteristic? _profileChar;
  BluetoothCharacteristic? _calChar;
  BluetoothCharacteristic? _controlChar;
  DeviceInfo? _info;

  @override
  String get id => device.remoteId.str;

  @override
  String get name {
    if (device.platformName.isNotEmpty) return device.platformName;
    if (_advertisedName.isNotEmpty) return _advertisedName;
    return 'Systole sensor';
  }

  @override
  bool get isDemo => false;

  @override
  DeviceInfo? get info => _info;

  @override
  Stream<LinkState> get linkState => _link.stream;
  @override
  Stream<PpgPacket> get ppg => _ppg.stream;
  @override
  Stream<BpResult> get results => _results.stream;
  @override
  Stream<int> get battery => _battery.stream;

  @override
  Future<void> connect() async {
    _cancelSubs();
    _link.add(LinkState.connecting);
    try {
      // On Android this also negotiates a 512-byte MTU so large PPG batches fit.
      await device.connect(timeout: const Duration(seconds: 15));
      _subs.add(
        device.connectionState.listen((s) {
          if (s == BluetoothConnectionState.disconnected) {
            _link.add(LinkState.disconnected);
          }
        }),
      );

      final services = await device.discoverServices();
      final svc = services
          .where((s) => s.uuid == SystoleUuids.service)
          .firstOrNull;
      if (svc == null) throw NotSystoleDeviceException();

      BluetoothCharacteristic? find(Guid uuid) =>
          svc.characteristics.where((c) => c.uuid == uuid).firstOrNull;

      final infoChar = find(SystoleUuids.info);
      if (infoChar != null) {
        _info = DeviceInfo.parse(await infoChar.read());
      }
      _profileChar = find(SystoleUuids.profile);
      _calChar = find(SystoleUuids.calibration);
      _controlChar = find(SystoleUuids.control);

      await _subscribe(find(SystoleUuids.ppg), (v) {
        final p = PpgPacket.parse(v);
        if (p != null) _ppg.add(p);
      });
      await _subscribe(find(SystoleUuids.bp), (v) {
        final r = BpResult.parse(v);
        if (r != null) _results.add(r);
      });

      final batSvc = services
          .where((s) => s.uuid == SystoleUuids.batteryService)
          .firstOrNull;
      final batChar = batSvc?.characteristics
          .where((c) => c.uuid == SystoleUuids.batteryLevel)
          .firstOrNull;
      if (batChar != null) {
        final v = await batChar.read();
        if (v.isNotEmpty) _battery.add(v.first);
        if (batChar.properties.notify) {
          await _subscribe(batChar, (v) {
            if (v.isNotEmpty) _battery.add(v.first);
          });
        }
      }

      await sendControl(ControlOp.startStream);
      _link.add(LinkState.connected);
    } catch (_) {
      _cancelSubs();
      await device.disconnect().catchError((_) {});
      _link.add(LinkState.disconnected);
      rethrow;
    }
  }

  Future<void> _subscribe(
    BluetoothCharacteristic? c,
    void Function(List<int>) onData,
  ) async {
    if (c == null) return;
    _subs.add(c.onValueReceived.listen(onData));
    await c.setNotifyValue(true);
  }

  Future<void> _write(BluetoothCharacteristic? c, List<int> bytes) async {
    if (c == null || device.isDisconnected) return;
    await c.write(bytes, withoutResponse: false);
  }

  @override
  Future<void> sendProfile(UserProfile p) => _write(
    _profileChar,
    encodeProfile(
      age: p.age,
      isMale: p.isMale,
      heightCm: p.heightCm,
      weightKg: p.weightKg,
    ),
  );

  @override
  Future<void> sendCalibration(double sbp, double dbp) =>
      _write(_calChar, encodeCalibration(sbp, dbp));

  @override
  Future<void> sendControl(int op) => _write(_controlChar, [op]);

  @override
  Future<void> disconnect() async {
    try {
      await sendControl(ControlOp.stopStream);
    } catch (_) {}
    _cancelSubs();
    await device.disconnect();
    _link.add(LinkState.disconnected);
  }

  void _cancelSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancelSubs();
    _link.close();
    _ppg.close();
    _results.close();
    _battery.close();
  }
}
