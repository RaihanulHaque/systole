import 'dart:async';
import 'dart:math' as math;

import '../models/user_profile.dart';
import 'bp_device.dart';
import 'protocol.dart';

/// Simulated sensor: synthetic 100 Hz PPG plus a BP estimate every few
/// seconds. Lets the app be developed and demoed without hardware.
class DemoBpDevice implements BpDevice {
  static const sampleRate = 100;
  static const _batch = 10;

  final _rng = math.Random();
  final _link = StreamController<LinkState>.broadcast();
  final _ppg = StreamController<PpgPacket>.broadcast();
  final _results = StreamController<BpResult>.broadcast();
  final _battery = StreamController<int>.broadcast();

  Timer? _sampleTimer;
  Timer? _resultTimer;
  int _seq = 0;
  int _sampleIndex = 0;
  double _phase = 0;
  double _hr = 72;
  double _sbp = 121;
  double _dbp = 78;
  double _batteryLevel = 87;
  bool _calibrated = false;
  final _start = DateTime.now();

  @override
  String get id => 'demo';
  @override
  String get name => 'Demo sensor';
  @override
  bool get isDemo => true;

  @override
  DeviceInfo? get info => DeviceInfo(
    sampleRateHz: sampleRate,
    fwMajor: 1,
    fwMinor: 0,
    modelVersion: 5,
    calibrated: _calibrated,
  );

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
    _link.add(LinkState.connecting);
    await Future.delayed(const Duration(milliseconds: 600));
    _startStreaming();
    _battery.add(_batteryLevel.round());
    _link.add(LinkState.connected);
  }

  void _startStreaming() {
    _sampleTimer?.cancel();
    _resultTimer?.cancel();
    _sampleTimer = Timer.periodic(
      const Duration(milliseconds: 1000 * _batch ~/ sampleRate),
      (_) => _emitSamples(),
    );
    _resultTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _emitResult(),
    );
  }

  void _stopStreaming() {
    _sampleTimer?.cancel();
    _resultTimer?.cancel();
  }

  void _emitSamples() {
    final samples = <int>[];
    for (var i = 0; i < _batch; i++) {
      final t = _sampleIndex / sampleRate;
      _phase += _hr / 60 / sampleRate;
      if (_phase >= 1) {
        _phase -= 1;
        _hr = (_hr + _rng.nextDouble() * 2 - 1).clamp(58, 96);
      }
      final p = _phase;
      // Fast systolic upstroke, slower decay, then the dicrotic wave.
      final width = p < 0.2 ? 0.07 : 0.14;
      final systolic = math.exp(-math.pow((p - 0.2) / width, 2));
      final dicrotic = 0.3 * math.exp(-math.pow((p - 0.48) / 0.08, 2));
      final respiration = 70 * math.sin(2 * math.pi * 0.25 * t);
      final noise = (_rng.nextDouble() - 0.5) * 16;
      samples.add(
        (2048 + 600 * (systolic + dicrotic) + respiration + noise).round(),
      );
      _sampleIndex++;
    }
    final seq = _seq;
    _seq = (_seq + 1) & 0xFFFF;
    // Occasionally drop a packet so the loss counter has something to show.
    if (_rng.nextDouble() < 0.003) return;
    _ppg.add(PpgPacket(seq, samples));
  }

  void _emitResult() {
    _sbp = (_sbp + (_rng.nextDouble() - 0.5) * 3).clamp(95, 165);
    _dbp = (_dbp + (_rng.nextDouble() - 0.5) * 2).clamp(55, 105);
    final jitter = _calibrated ? 1.5 : 5.0;
    // Mostly good contact, with an occasional poor window.
    final quality = _rng.nextDouble() < 0.08
        ? 45 + _rng.nextInt(20)
        : 82 + _rng.nextInt(17);
    var flags = _calibrated ? BpResult.flagCalibrated : 0;
    if (quality < 70) flags |= BpResult.flagLowQuality;
    _results.add(
      BpResult(
        deviceMs: DateTime.now().difference(_start).inMilliseconds,
        sbp: _sbp + (_rng.nextDouble() - 0.5) * jitter,
        dbp: _dbp + (_rng.nextDouble() - 0.5) * jitter * 0.6,
        hr: _hr.round(),
        quality: quality,
        flags: flags,
      ),
    );
    _batteryLevel = math.max(5, _batteryLevel - 0.05);
    _battery.add(_batteryLevel.round());
  }

  @override
  Future<void> sendProfile(UserProfile profile) async {}

  @override
  Future<void> sendCalibration(double sbp, double dbp) async {
    _sbp = sbp;
    _dbp = dbp;
    _calibrated = true;
  }

  @override
  Future<void> sendControl(int op) async {
    switch (op) {
      case ControlOp.startStream:
        _startStreaming();
      case ControlOp.stopStream:
        _stopStreaming();
      case ControlOp.clearCalibration:
        _calibrated = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _stopStreaming();
    _link.add(LinkState.disconnected);
  }

  @override
  void dispose() {
    _stopStreaming();
    _link.close();
    _ppg.close();
    _results.close();
    _battery.close();
  }
}
